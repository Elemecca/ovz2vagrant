#!/bin/bash

set -eox pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <boot_device>" >&2
    exit 1
fi

bootdev=$1

if [[ ! -b "$bootdev" ]]; then
    echo "boot device isn't a device: '$bootdev'" >&2
    exit 2
fi



echo "* configuring networking..."

cat >>/etc/network/interfaces <<END

auto eth0
iface eth0 inet dhcp
END



echo "* configuring users..."

# set root's password to 'vagrant'
passwd <<END
vagrant
vagrant

END

# create user 'vagrant' with password 'vagrant'
adduser --gecos=,,, vagrant <<END
vagrant
vagrant

END

# give vagrant passwordless sudo
cat >/etc/sudoers.d/vagrant <<END
vagrant ALL=(ALL) NOPASSWD: ALL
END

# authorize the Vagrant insecure SSH key
mkdir /home/vagrant/.ssh
cat >/home/vagrant/.ssh/authorized_keys <<END
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key
END
chown -R vagrant:vagrant /home/vagrant/.ssh
chmod 0700 /home/vagrant/.ssh



echo "* disabling broken init scripts..."
update-rc.d -f modules_dep.sh remove



echo "* preparing APT..."
export DEBIAN_FRONTEND=noninteractive
apt-get update



echo "* installing kernel ..."
apt-get install --assume-yes \
    linux-image-generic linux-headers-generic



echo "* installing guest additions..."
apt-get install --assume-yes --no-install-recommends \
    virtualbox-guest-utils virtualbox-guest-dkms



echo "* installing bootloader..."

cat >>/etc/default/grub <<'END'

# disable "predicatble interface names"
# unfortunately they make it so we can't predict the interface
# name for use in scripts without knowing about the hardware
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX net.ifnames=0 biosdevname=0"
END

# prevent discovery of OSes on the host computer
chmod -f -x /etc/grub.d/30_os-prober /etc/grub.d/30_uefi-firmware

update-grub
grub-install "$bootdev"
