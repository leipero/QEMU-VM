# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

## 2020-05-26
### Added
- Virtio drivers injection option for Windows PT VMs.
- VHD control script.
### Changed
- Some cleaning up.
- Grub update process.
### Fixed
- VMs configuration is now removed when VM is removed.
- Windows virtio drivers check.


## 2020-05-25
### Added
- GPU option for custom/macOS VM passthrough (GPU VBIOS append to script).
- VBIOS extraction scripts.
### Changed
- VM iso name handling.
- Custom VM scripts for new OVMF name.
- README file.
### Fixed
- OVMF per distribution entries.
- VM iso selection.
- MacOS passthrough.
- Mouse for passthrough VMs.
### Removed
- VHD name choice (to speed up creation process).

## 2020-05-24
### Added
- GPU option for custom VM passthrough (fix for AMD Windows drivers bug).
- Other distributions support.
- Ask before overwrite VM/VHD.
- Remove VM option.
- Git dependency.
### Changed
- Passthrough blueprints default GPU settings.
- Now script asks before overwriting VM and VHD.
- Minor semantics change.
- MacOS iso name is no longer hardcoded.
### Fixed
- Should work with all GPUs now.
- New VM entries in config are no longer repeated.
- MacOS images are now moved properly.
- No input entries.
### Removed
- MacOS Firmware.
- Redundant code.

## 2020-05-23
### Added
- MacOS blueprint (passthrough and qxl).
- MacOS download (via macOS-Simple-KVM script by Foxlet).
- Custom VM with QXL graphics.
- Custom VM with Virtio-vga option to disable VirGL.
### Changed
- Cleaning and reorganization of the config file.
- Cleaning and reorganization of the script.
- Moved firstrun check file handling to the script main directory.
- Moved blueprints to visible 'bps' directory.
### Fixed
- MacOS VM.
- VirGL/Virtio-vga shortcuts.
### Removed
- MacOS virsh script.

## 2020-05-22
### Added
- Hugepages support for passthrough VMs.
- Input devices (keyboard and mouse) autodetection.
- Apt package check to avoid unnecessary reinstallation.
- Xterm and OVMF dependency.
- Log file.
### Changed
- Script cleaning, simplification and reorganization.
- Moved Display Manager for all VMs to the config file, rendering VM scripts cleaner.
### Fixed
- Blueprint/passthrough VMs attempted to load hugepages that did not exist, hence, VM failed to load path for RAM and consequently failed to start.
- Grub and systemd-boot handling.
- Display manager and hugepages insertion.
- Mouse not moving.
- Passthrough shortcuts.
- Images path.
### Removed
- Gnome terminal.
- Windows virsh script.

## 2020-05-21
### Added
- Custom VM creation (custom vhd, iso selection etc.).
- Blueprint VMs for VM creation.
- RAM detection and auto population.
- Run check.
### Changed
- Re-write, simplification and reorganization.
- VM icons.
### Fixed
- Boot manager detection (now it's a bit more sane).
- Typos.
### Removed
- Avmic_tool (most of it's functionality is now in the script itself).
- Most of the VMs from the script folder (blueprints are enough for new VM creation, makes more sense).
- VHD mount scripts.
- Code supporting removed presets.

## 2020-05-20
### Added
- This CHANGELOG file to hopefully serve as an evolving example of a standardized open source project CHANGELOG.
- Arch linux multi kernel support.
- Display manager detection and configuration for virsh scripts.
- Separate script containing semi-automatic VM and image creation tool (images/avmic_tool.sh).
- Folder for ISO images (images/iso/) to be separated from VHD images to adhere avmic_tool.
- Dummy VM blueprint based on GNU/Linux VirGL script (scripts/.vm\_bp) to adhere avmic_tool.
### Changed
- Oraninizing and cleaning the mess in the sctipt (a bit).
- Minor semantics changes.
### Fixed
- Root user no longer deals with user files.
### Removed
- Old image creation script (images/create_image.sh).

## 2020/05/19
- First creation.
