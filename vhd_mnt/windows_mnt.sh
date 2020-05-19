#!/bin/bash

CFDIRG=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "$CFDIRG/../scripts/config"

## Mount point locations
VHD_MOUNT_POINT=/home/$(logname)/VHD_WIN10

mkdir -p $VHD_MOUNT_POINT
sudo modprobe nbd max_part=8
sudo qemu-nbd --connect=/dev/nbd0 $WINDOWS_IMG
#sudo fdisk /dev/nbd0 -l
wait
sudo mount /dev/nbd0p2 $VHD_MOUNT_POINT
exit
