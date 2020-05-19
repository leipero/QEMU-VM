### System
```
                                                 [Author]
                                                 @leipero (GitHub)

                                                [Hardware]
                                                 CPU: AMD FX 4100
                                         Motherboard: MSI 970A-G43
                                    Motherboard BIOS: A.0
                                                 RAM: 8GB
                                                 GPU: R7 250
                                           GPU model: ASUS R7250-1GD5
                                            GPU BIOS: 015.044.000.002.000000
                                        GPU codename: Oland XT

                                                [Software]
                                        Linux Distro: Arch Linux x86_64
                                        Linux Kernel: 5.6.6-arch1-1
                                        Mesa version: 20.0.5-1
                                        QEMU version: 4.2.0-1
                                        OVMF version: 202002-1

                                                 [Guests]
                                          Windows 10 Pro 1909 x64
```

### How I did it

## vBIOS
There was no need to load VBIOS regardless of the use case.

## AMD drivers BSOD/CRASH on Windows 10 guest
While testing, as soon as Windows would install AMD drivers, it would freeze screen and make windows unbootable (always crashing).

The solution was to append ioh3420 device above GPU and GPU AUDIO in QEMU arguments and add 'bus=root.1' to GPU and GPU AUIDO devices, so it would look something like this (q35 chipset):
```
  -device ioh3420,bus=pcie.0,addr=1c.0,multifunction=on,port=1,chassis=1,id=root.1 \
  -device vfio-pci,host=$IOMMU_GPU,bus=root.1,addr=00.0,multifunction=on,x-vga=on \
  -device vfio-pci,host=$IOMMU_GPU_AUDIO,bus=root.1,addr=00.1 \
```
IMPORTANT NOTE: When using q35 chipset, use bus=pcie.0, for older QEMU chipsets (i440fx for example) it is either 'pci' or 'pci.0'.

## No audio I/O
Same issue as SSStormy, same solution (passing thru PCI audio device) with slightly different method (using virsh).

Config, 'IOMMU groups' under IOMMU_GPU_AUDIO:
```
IOMMU_PCI_AUDIO=00:14.2
```
For 'Virsh devices' under VIRSH_GPU_AUDIO:
```
VIRSH_PCI_AUDIO=pci_0000_00_14_2
```
PCI BUS ID:
```
pciaudioid="1002 4383"
pciaudiobusid="0000:00:14.2"
```

In windows-virsh.sh, during detachment, below the VIRSH_GPU_AUDIO:
```
virsh nodedev-detach $VIRSH_PCI_AUDIO > /dev/null 2>&1
```
In the QEMU arguments, below IOMMU_GPU:
```
-device vfio-pci,host=$IOMMU_PCI_AUDIO \
```
During reattachment, below VIRSH_GPU_AUDIO:
```
virsh nodedev-reattach $VIRSH_GPU > /dev/null 2>&1
```

## Cannot boot off of ANY drives with OVMF
During testing where I didn't passthrough any PCI devices, the VM failed to boot off of any drive/iso/CD I gave to it. This only occured when I booted QEMU with the OVMF UEFI.

The solution SSStormy presented works, however, if you really want to use OVMF UEFI, solution is to use these drive QEMU arguments instead of ones in script windows-virsh.sh
```
  -drive id=disk0,if=virtio,cache=off,aio=native,format=qcow2,file=$WINDOWS_IMG \
  -drive file=$WINDOWS_ISO,index=1,media=cdrom \
  -drive file=$VIRTIO,index=2,media=cdrom \
  -boot order=dc \
```

## Script will not work if run from within a DM/WM/X11 (GDM on Wayland backend, X11 or Wayland session)
It does work sometimes in GNOME using GDM (Wayland backend for GDM, X11 gnome session), but most of the time does not. Used the same method as @SSStormy (switching TTY), but automated it. Could be useful to someone.

The solution was to load TTY 3 and log in to it (and that's important for some reason). I've automated whole process by:
1. Automatic log in to the TTY3 with '/etc/systemd/system/getty@tty3.service.d/override.conf' file containing:
```
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin YOUR_USERNAME --noclear %I $TERM
```
2. Automatically switching to TTY3 and running VM by creating startup script 'name_of_VM.sh' in '/usr/local/bin/' containing:
```
sudo chvt 3
wait
cd /your_vfio_location/vfio/ && sudo nohup scripts/windows-virsh.sh > /tmp/nohup.log 2>&1
```
3. OPTIONAL: Creating .desktop shortcut so I could start it from Gnome Shell directly, containing:
```
[Desktop Entry]
Name=Windows 10
Exec=gnome-terminal -e windows10
Icon=/your_icon_location/win10.png
Type=Application
```
Also note that you should wait a bit on system boot for some reason, just a few minutes and it will work 100% of the time, while using GDM, when VM is off, it will start gdm and switch to TTY1, you can start VM again without reboot even tho. console framebuffer for TTY3 was not recovered. Also, GDM uses it's default Wayland backend, if it's set to X11, there is an issue running the script, did not investigate it further.

## Passing through USB devices (HID), especially gamepads/joysticks
While SSStormy solution with '-object input-linux' works for keyboard and mouse, there are multiple issues with it. Most common issue is with imput getting 'stuck' in games (reported by others), but my particular issue was that LED indicators for 'NumLock, CapsLock' etc. did not work properly. Also, it was next to impossible to pass through USB joystick device.

The solution is to use 'qemu-xchi' device to pass through devices.
In Config, add:
```
## USB DEVICE(s) ID(s)
usb1_vendorid=0x
usb1_productid=0x
usb2_vendorid=0x
usb2_productid=0x
usb3_vendorid=0x
usb3_productid=0x
usb4_vendorid=0x
usb4_productid=0x
```
See the 'productid' and 'vendorid' using 'lsusb' command. For example, in 'Bus 008 Device 003: ID 1345:1000 Sino Lite Technology Corp. Generic   USB  Joystick', where first number '1345' is 'vendorid' while second number '1000' is 'productid'. So our lines would be:
usb1_vendorid=0x1345
usb1_productid=0x1000
Configure for your own devices.

In windows-virsh.sh (or any script you use), add:
```
  -device qemu-xhci,id=xhci,p2=4 \
  -device usb-host,bus=xhci.0,vendorid=$usb1_vendorid,productid=$usb1_productid,port=1 \
  -device usb-host,bus=xhci.0,vendorid=$usb2_vendorid,productid=$usb2_productid,port=2 \
```
For device 'qemu-xhci', 'p2=4' represents type of the USB port and number of ports, 'p2' represents USB2, if you need USB3, you have to use 'p3' option instead, or combine the two (p3=8, for 8 USB3 ports). Device 'qemu-xhci' supports up to 16 ports.
Where '-device usb-host,bus=xhci.0,...' represents USB device you want to pass to the guest, 'port=1' (2,3,4) represents port USB device is attached to, you can add or subtract how much devices you need (up to 16 per 'qemu-xhci' controller).

## Incredibly slow drive speeds
## QCOW2 Drive does not show up during windows install
## No network
Same solutions as SSStormy.
