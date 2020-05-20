#!/bin/bash

## Mount point location
VHD_MOUNT_POINT=/home/$(logname)/VHD_MACOS

sudo umount $VHD_MOUNT_POINT
sudo qemu-nbd --disconnect /dev/nbd0
sudo rmmod nbd
wait
rm -d $VHD_MOUNT_POINT
exit
