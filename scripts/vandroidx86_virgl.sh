#!/bin/bash

## Load the config file
source "${BASH_SOURCE%/*}/config"

## QEMU (VM) command
qemu-system-x86_64 -enable-kvm -M q35 -vga virtio -display gtk,gl=on \
  -m $RAM -cpu host,hypervisor,topoext -rtc clock=host,base=localtime \
  -smp $CORES,sockets=1,cores=$(( $CORES / 2 )),threads=2 \
  -usb -device usb-tablet \
  -soundhw all \
  -drive if=virtio,file=$ANDROID_IMG,format=qcow2,cache=none,aio=threads \
  -drive file=$ANDROID_ISO,index=1,media=cdrom >> $LOG 2>&1 &

## Virgl:
# If virglrenderer version (now at 0.8.2) have black glitches/boxes etc., downgrade to 0.7.0 version and sumlink (Arch):
# ln -sf /usr/lib/libvirglrenderer.so.0 /usr/lib/libvirglrenderer.so.1

## Wait for QEMU
wait
