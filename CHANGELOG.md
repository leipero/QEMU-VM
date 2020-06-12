# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.7] - 2020-06-12
### Added
- VHD Control multi VHDs mount (still needs some work).
### Changed
- Directory structure for VBIOS extraction, iommu and VM scripts.
### Fixed
- VM remove option.
- Custom VM ISO selection.
- Display check logic (checks only if multi GPU configuration is detected).
- GPU method handling with custom names.
- VHD Control.

## [0.9.6] - 2020-06-11
### Added
- Multi-Display support.
- MacOS base image select (in case it was already downloaded by script).
### Changed
- Simplified and reorganized script.
### Fixed
- Cores and threads calculation.
- MacOS name.
### Removed
- Redundant code.

## [0.9.5] - 2020-06-09
### Added
- Passthrough multi GPU support per VM.
### Changed
- GPU detection.
- SMP, CPU cores and threads handling.
- Names for templates.
- RAM and CORES handling, now per VM.
- Hugepages hangling (now per VM).
- VHD control AIO (again, back to native).
### Fixed
- Memory lock limit per VM.
- Single GPU passthrough fix.
- GPU detection.
- Virtio injection.
### Removed
- Global HUGEPAGES, global RAM, global CORES.
- Old cli scripts (if needed, they are in previous versions).

## [0.9.3] - 2020-06-07
### Added
- Dialog based GUI for vhd_control script.
### Changed
- Script dealing with elevated privileges.
### Fixed
- VM names.
### Removed
- Autoconfiguration cli.

## [0.9.2] - 2020-06-06
### Added
- Dialog based GUI beta script (autocfg-dialog-beta.sh).
- Option for io_uring support.
### Changed
- To native AIO for vhd_control.
### Fixed
- Disconnecting nbd in vhd_control.
### Removed
- Redundant code.

## [0.9.1] - 2020-05-29
### Added
- Legacy BIOS support for custom VMs.
- Versioning system.
### Changed
- Passthrough VMs no longer depend on TTY3 login.
- RAM cache flush at VMs shutdown for passthrough.
### Fixed
- Wayland session for passthrough works now.
### Removed
- TTY3 autologin and it's supporting code (potential security risk and it's no longer needed).


## [0.9.0] - 2020-05-28
### Added
- Non-passthrough custom and macOS VMs RAM size and cores number option (useful for running multi VMs).
### Changed
- Custom non-passthrough VMs graphic cards options reorganization.
- Custom non-passthrough VMs now use SDL rather than GTK (for compatibility reasons).
- GPU option no longer defualts to anything, it requires user choice.
- RAM allocation is now based on MemAvailable, rather than MemFree.
- Set -2GB for global RAM detection, just in case.
- OVMF for Arch Linux (to be in line with new package name and location).
- Updated documentation.
### Fixed
- RAM allocation failed.
- Curl download.
- Paths for config file in blueprints (thanks ez).
- Fix QXL VMs creation (thanks to the ez again).
### Removed
- Redundant code.

## 2020-05-27
### Added
- USB devices (keyboard, mouse and joystick) are now in config file and ready for PT (manual).
- Documentation.
### Changed
- Create faster qcow2 images (add preallocation=metadata).
- VHD control cache handling.
### Fixed
- VHD control rush condition.
- VHD control, get semi-acceptable speeds in single HDD drive-to-drive conditions.
### Removed
- Hardware configurations.

## 2020-05-26
### Added
- Virtio drivers injection option for Windows guests.
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
- Gnome terminal dependency.
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
