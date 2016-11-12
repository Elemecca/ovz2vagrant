#!/bin/bash

set -eox pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: $0 <template> <output>" >&2
    exit 1
fi

template=$1
outfile=$2

if [[ ! -f "$template" ]]; then
    echo "template not found: '$template'" >&2
    exit 2
fi

if [[ -e "$outfile" ]]; then
    echo "output file exists: '$outfile'" >&2
    exit 2
fi


# become root if we're not already
if [[ $UID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi


echo "*** creating new disk image..."
truncate -s 50G "${outfile}"

echo "*** formatting disk image..."

# loop-mount the disk image
loopdev=$(losetup --find --show "${outfile}")

# create a single partition filling the disk
sfdisk -q -uS --no-reread $loopdev <<END
2048,,L,*
END

# re-create the loop mount with partitions
kpartx -a $loopdev
partdev=/dev/mapper/$(basename $loopdev)p1
echo $partdev

# the partitions can take a little while to show up; wait
timeout=60
while [[ ! -e $partdev && $timeout > 0 ]]; do
    sleep 1
    timeout=$(( $timeout - 1 ))
done


# create a filesystem on the partition
mkfs.ext4 -q $partdev


echo "*** mounting disk image..."
mkdir -p target
mount $partdev target



echo "*** extracting template..."
tar -xzpf "$template" -C target



echo "*** performing installation steps..."

# mount in preparation for chroot
mount -B /dev target/dev
mount -B /sys target/sys
mount -B /proc target/proc

# execute the setup script under chroot
cp -f /etc/resolv.conf target/etc/resolv.conf
cp install.sh target/tmp/

chroot target /bin/bash /tmp/install.sh "$loopdev"

rm target/tmp/install.sh
echo >target/etc/resolv.conf


echo "*** unmounting disk image..."
umount target/{dev,sys,proc} target
kpartx -d $loopdev
losetup -d $loopdev


echo "*** done."
