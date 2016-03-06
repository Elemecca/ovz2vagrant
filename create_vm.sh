#!/bin/bash

set -eox pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: $0 <raw_disk> <vm_basename>" >&2
    exit 1
fi

rawdisk=$1
vmname=$2

if [[ ! -f "$rawdisk" ]]; then
    echo "raw disk is not a file: '$rawdisk'" >&2
    exit 2
fi

if [[ -e "${vmname}.vdi" ]]; then
    echo "cooked disk exists: '${vmname}.vdi'" >&2
    exit 2
fi


echo "*** converting disk image..."
VBoxManage convertfromraw \
    "$rawdisk" "${vmname}.vdi" \
    --format VDI --variant Standard



echo "*** creating VM..."
VBoxManage createvm \
    --name "$vmname" --register \
    --basefolder "$(dirname "$(readlink -f "$vmname")")" \
    --ostype Ubuntu_64

VBoxManage modifyvm "$vmname" \
    --memory 512 \
    --cpus 1 \
    --nic1 nat --nictype1 virtio \
    --mouse ps2 --keyboard ps2 \
    --audio none --usb off

VBoxManage storagectl "$vmname" \
    --name sata --add sata --bootable on

VBoxManage storageattach "$vmname" \
    --storagectl sata --port 0 \
    --type hdd --medium "${vmname}.vdi"

echo "*** exporting box..."
vagrant package --base "$vmname" --output "${vmname}.box"
