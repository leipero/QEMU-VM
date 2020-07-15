# QEMU VM setup script.

## What this is
Script to create QEMU VMs. Lot's of options, compact, no superuser required for running non-passthrough VMs, adds shortcuts (in other category) for every VM created etc.

## How to use

 Get:
```
git clone https://github.com/leipero/QEMU-VM.git && cd QEMU-VM
```
 Run:
```
bash autoconfiguration.sh
```

## Known problems
- Users must extract, edit (in case of nvidia) VBIOS manually.
- VHD control might not remove nbd device properly.
- Single GPU Passthrough VMs may not return display on wayland.

## Wiki (Yuri Alek's page)
[Check the wiki for more information and guides on how to make everything work](https://gitlab.com/YuriAlek/vfio/wikis/Home).

## Sources links
- Yuri scripts
https://gitlab.com/YuriAlek/vfio
- Nvidia VBIOS extraction (tools in main script above)
https://gitlab.com/YuriAlek/vfio/-/wikis/vbios
- MacOS scripts
https://github.com/foxlet/macOS-Simple-KVM.git
- MacOS nvidia
https://github.com/kholia/OSX-KVM/blob/master/notes.md
