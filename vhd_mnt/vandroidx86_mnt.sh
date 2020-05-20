#!/bin/bash

CFDIRG=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "$CFDIRG/../scripts/config"

## Virtual drive and mount point locations
VHD_MOUNT_POINT=/home/$(logname)/VHD_ANDROID

mkdir -p $VHD_MOUNT_POINT
sudo modprobe nbd max_part=8
sudo qemu-nbd --connect=/dev/nbd0 $ANDROID_IMG
#sudo fdisk /dev/nbd0 -l
wait
sudo mount /dev/nbd0p2 $VHD_MOUNT_POINT
exit
