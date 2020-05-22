#!/bin/bash

## Check if the script was executed as root
[[ "$EUID" -ne 0 ]] && echo "Please run as root" && exit 1

## Load the config file
source "${BASH_SOURCE%/*}/config"

## Check libvirtd
[[ $(systemctl status libvirtd | grep running) ]] || systemctl start libvirtd && sleep 1 && LIBVIRTD=STOPPED

## Memory lock limit
[[ $ULIMIT != $ULIMIT_TARGET ]] && ulimit -l $ULIMIT_TARGET

## Load hugepages (VM RAM in MB divided by 2+100)
sysctl -qw vm.drop_caches=1
sysctl -qw vm.compact_memory=1
echo "$HUGEPAGES" > /proc/sys/vm/nr_hugepages

## Kill the Display Manager
systemctl stop $DSPMGR
sleep 1

## Kill the console
echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

## Detach the GPU
virsh nodedev-detach $VIRSH_GPU > /dev/null 2>&1
virsh nodedev-detach $VIRSH_GPU_AUDIO > /dev/null 2>&1
virsh nodedev-detach $VIRSH_PCI_AUDIO > /dev/null 2>&1

## Load vfio
modprobe vfio-pci

## QEMU (VM) command
qemu-system-x86_64 -runas $VM_USER -enable-kvm -M q35 \
  -nographic -vga none -parallel none -serial none \
  -m $RAM -mem-path /dev/hugepages \
  -cpu host,hypervisor,topoext,kvm=off,hv_relaxed,hv_spinlocks=0x1fff,hv_time,hv_vapic,hv_vendor_id=0xDEADBEEFFF \
  -rtc clock=host,base=localtime \
  -smp $CORES,sockets=1,cores=$(( $CORES / 2 )),threads=2 \
  -device ioh3420,bus=pcie.0,addr=1c.0,multifunction=on,port=1,chassis=1,id=root.1 \
  -device vfio-pci,host=$IOMMU_GPU,bus=root.1,addr=00.0,multifunction=on,x-vga=on \
  -device vfio-pci,host=$IOMMU_GPU_AUDIO,bus=root.1,addr=00.1 \
  -device vfio-pci,host=$IOMMU_PCI_AUDIO \
  -drive if=pflash,format=raw,readonly,file=$OVMF \
  -device qemu-xhci,id=xhci,p2=4 \
  -device usb-host,bus=xhci.0,vendorid=$usb1_vendorid,productid=$usb1_productid,port=1 \
  -device usb-host,bus=xhci.0,vendorid=$usb2_vendorid,productid=$usb2_productid,port=2 \
  -device usb-host,bus=xhci.0,vendorid=$usb3_vendorid,productid=$usb3_productid,port=3 \
  -drive id=disk0,if=virtio,cache=off,aio=threads,format=qcow2,file=$WINDOWS_IMG \
  -drive file=$WINDOWS_ISO,index=1,media=cdrom >> $LOG 2>&1 &

## Wait for QEMU
wait

## Unload vfio
modprobe -r vfio-pci
modprobe -r vfio_iommu_type1
modprobe -r vfio

## Reattach the GPU
virsh nodedev-reattach $VIRSH_PCI_AUDIO > /dev/null 2>&1
virsh nodedev-reattach $VIRSH_GPU_AUDIO > /dev/null 2>&1
virsh nodedev-reattach $VIRSH_GPU > /dev/null 2>&1

## Reload the framebuffer and console
echo 1 > /sys/class/vtconsole/vtcon0/bind
#nvidia-xconfig --query-gpu-info > /dev/null 2>&1
echo "efi-framebuffer.0" > /sys/bus/platform/drivers/efi-framebuffer/bind

## Unload hugepages
echo 0 > /proc/sys/vm/nr_hugepages

## Reload the Display Manager
systemctl start $DSPMGR

## If libvirtd was stopped then stop it
[[ $LIBVIRTD == "STOPPED" ]] && systemctl stop libvirtd

## Restore ulimit
ulimit -l $ULIMIT
