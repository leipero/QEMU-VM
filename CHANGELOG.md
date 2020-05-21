# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

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
