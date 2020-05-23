# Single GPU passthrough auto configuration script

## What this is
An attempt to make auto configuration script for single GPU passthrough scripts by Yuri Alek. Ideally, this script will attempt to get information about GPU, CPU, IOMMU groups, modules, paths etc. and configure it properly, attempting to make as littile assumptions as possible. Still, some assumptions are made, and most important one, it assumes that system have single GPU.
Script attempts to be as modular as possible, it should be easy to edit, add or remove functionality.
Some functionality is not implemented or it is removed, if you need such functionality, feel free to change and improve the script, or visit Yuri's page on gitlab (I would recommend that in any circumstance). 

## What it is not
Anything other than me having fun, included but not limited to the actual functional and useful tool.

## How to use
Script requires superuser.
 Get:
```
git clone https://github.com/leipero/vfio-autocfg.git && cd vfio-autocfg
```
 Run:
```
sudo bash autoconfiguration.sh
```

## Wiki (Yuri Alek's page)
[Check the wiki for more information and guides on how to make everything work](https://gitlab.com/YuriAlek/vfio/wikis/Home).

## Known problems
- Installing dependencies, enabling early KMS and IOMMU works only for Arch and Ubuntu/Debian base.
- Script relies on logged user and sudo or su commands in some parts.
- Wayland session was not tested at all and will likely not work.

## TODO
- Add support for more distributions.
- Simplify script and make less assumptions.
- Add wayland support.
- Automatic vBIOS extraction etc..

## Actual passthrough and VMs scripts author
https://gitlab.com/YuriAlek/vfio
