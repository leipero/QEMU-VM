# Single GPU passthrough auto configuration script

## What this is
An attempt to make auto configuration script for single GPU passthrough scripts by Yuri Alek. Ideally, this script will attempt to get information about GPU, CPU, IOMMU groups, modules, paths etc. and configure it properly, attempting to make as littile assumptions as possible. Still, some assumptions are made.
Script attempts to be as modular as possible, it should be easy to edit, add or remove functionality.
Some functionality is not implemented, if you need such functionality, feel free to change and improve the script, or visit Yuri's page on gitlab (I would recommend that in any circumstance). 

## How to use
Script requires superuser.

 Get:
```
git clone https://github.com/leipero/vfio-autocfg.git && cd vfio-autocfg
```
 Run:
```
bash autoconfiguration.sh
```

## Wiki (Yuri Alek's page)
[Check the wiki for more information and guides on how to make everything work](https://gitlab.com/YuriAlek/vfio/wikis/Home).

## Known problems
- Users must extract, edit (in case of nvidia) VBIOS manually.
- Script relies on logged user and sudo command.
- Wayland session will not return display after passthrough VM is shut down.

## TODO
- VHD Control.
- Fix wayland display issue at VM shutdown.
- Better way to unbind/bind devices.

## Sources links
- Yuri scripts
https://gitlab.com/YuriAlek/vfio
- Nvidia VBIOS extraction (tools in main script above)
https://gitlab.com/YuriAlek/vfio/-/wikis/vbios
- MacOS scripts
https://github.com/foxlet/macOS-Simple-KVM.git
- MacOS nvidia
https://github.com/kholia/OSX-KVM/blob/master/notes.md
