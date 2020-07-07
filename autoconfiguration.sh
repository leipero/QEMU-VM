#!/bin/bash
export LC_ALL=C

## Check if script was executed with the root privileges.
[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"

function welcomescript() {
	dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title     "Welcome." \
		--yesno "Welcome to the Single GPU Passthrought configuration script. \n Note: This script attempts to do as little assumptions as possible, but some assumptions were made, introducig a chance that script may not work properly. Be advised. Do you wish to continue? " 10 60
	wlcmcontinue=$?
	case $wlcmcontinue in
	0)
		checkos_install
		;;
	1)
		clear
		exit 0
		;;
	esac
}

function checkos_install() {
	if command -v apt > /dev/null 2>&1; then
		(populate_base_config
		install_dep_apt
		populate_ovmf
		addgroups
		enable_earlykms_apt) | dialog --backtitle "Single GPU Passthrought Configuration Script" --progressbox "System configuration..." 12 60
		setup_bootloader
		vm_choice
		chk_create
	elif command -v yum > /dev/null 2>&1; then
		(populate_base_config
		install_dep_yum
		populate_ovmf
		addgroups) | dialog --backtitle "Single GPU Passthrought Configuration Script" --progressbox "System configuration..." 12 60
		setup_bootloader
		vm_choice
		chk_create
	elif command -v zypper > /dev/null 2>&1; then
		(populate_base_config
		install_dep_zypper
		populate_ovmf
		addgroups) | dialog --backtitle "Single GPU Passthrought Configuration Script" --progressbox "System configuration..." 12 60
		setup_bootloader
		vm_choice
		chk_create
	elif command -v pacman > /dev/null 2>&1; then
		(populate_base_config
		install_dep_pacman
		populate_ovmf
		addgroups
		enable_earlykms_pacman) | dialog --backtitle "Single GPU Passthrought Configuration Script" --progressbox "System configuration..." 12 60
		setup_bootloader
		vm_choice
		chk_create
	else
		continue_script
	fi
}

function first_run() {
	if [ -f ${SCRIPT_DIR}/.frchk ] > /dev/null 2>&1; then
		notfirstrun
	else
		welcomescript
	fi
}

function notfirstrun() {
	dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title     "First Run Check." \
		--yesno "It seems that this is not the first run of the configuration script, if your system is already configured you may wish to skip to the VM creation part.\n This will save some time if IOMMU groups, loaders and paths are already properly configured. If you however made some changes to the hardware, software or changed script location, you may wish to run checks again and you should answer NO." 12 60
	nfrinput=$?
	case $nfrinput in
	0)
		vm_choice
		;;
	1)
		welcomescript
		;;
	esac
}

function continue_script() {
	dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title     "Continue Setup." \
		--defaultno --yesno "You must have packages equivalent to Arch \"qemu ovmf libvirt virt-manager virglrenderer curl\" packages installed in order to continue. \nDo you wish to Continue?" 8 60
	askconts=$?
	case $askconts in
	0)
	    	(populate_base_config
	    	addgroups) | dialog --backtitle "Single GPU Passthrought Configuration Script" --programbox "System configuration..." 12 60
		check_iommu
		vm_choice
		chk_create
		remindernopkgm | dialog --backtitle "Single GPU Passthrought Configuration Script" --programbox "Reminder." 14 60
		exit 1
		;;
	1)
		clear
		exit 1
		;;
	esac
}

##***************************************************************************************************************************
## Install dependencies.

function install_dep_apt() {
	OVMF_C="/usr/share/OVMF/OVMF_CODE.fd"
	OVMF_V="/usr/share/OVMF/OVMF_VARS.fd"
	if dpkg -s curl git xterm > /dev/null 2>&1; then
		echo "XTERM is already installed."
	else
		echo "Installing XTERM, please wait..."
		apt-get install -y curl git xterm > /dev/null 2>&1
	fi
	if dpkg -s qemu-kvm ovmf > /dev/null 2>&1; then
		echo "Qemu-kvm is already installed."
	else
		echo "Installing qemu-kvm, please wait..."
		apt-get install -y qemu-kvm ovmf > /dev/null 2>&1
	fi
	if dpkg -s libvirt-daemon-system libvirt-clients > /dev/null 2>&1; then
		echo "Libvirt is already installed."
	else
		echo "Installing libvirt, please wait..."
		apt-get install -y libvirt-daemon-system libvirt-clients > /dev/null 2>&1
	fi
	if dpkg -s libvirglrenderer0 libvirglrenderer1 > /dev/null 2>&1; then
		echo "Libvirglrenderer is already installed."
	else
		echo "Installing libvirglrenderer, please wait..."
		apt-get install -y libvirglrenderer0 libvirglrenderer1 > /dev/null 2>&1
	fi
	echo "Dependencies are installed."
}

function install_dep_yum() {
	OVMF_C="/usr/share/edk2/ovmf/OVMF_CODE.fd"
	OVMF_V="/usr/share/edk2/ovmf/OVMF_VARS.fd"
	echo "Installing packages, please wait."
	yum -yq groups install "virtualization"
	uym -yq install curl xterm git
	echo "Dependencies are installed."
}

function install_dep_zypper() {
	OVMF_C="/usr/share/qemu/ovmf-x86_64-ms-code.bin"
	OVMF_V="/usr/share/qemu/ovmf-x86_64-ms-vars.bin"
	echo "Installing packages, please wait."
	zypper -n install patterns-openSUSE-kvm_server patterns-server-kvm_tools ovmf xterm curl
	echo "Dependencies are installed."
}

function install_dep_pacman() {
	OVMF_C="/usr/share/edk2-ovmf/x64/OVMF_CODE.fd"
	OVMF_V="/usr/share/edk2-ovmf/x64/OVMF_VARS.fd"
	if pacman -Q qemu ovmf libvirt virt-manager virglrenderer edk2-ovmf curl xterm git > /dev/null 2>&1; then
		echo "Dependencies are already installed."
	else
		echo "Installing dependencies, please wait..."
		pacman -S --noconfirm qemu edk2-ovmf libvirt virt-manager virglrenderer ovmf curl xterm git > /dev/null 2>&1
		echo "Dependencies are installed."
	fi
}

##***************************************************************************************************************************
## Add user to groups.

function addgroups() {
	if groups $(logname) | grep kvm | grep libvirt > /dev/null 2>&1; then
		echo "User is already in groups."
	else
		usermod -a -G libvirt $(logname)
		usermod -a -G kvm $(logname)
		echo "User is now a member of the required groups."
	fi
}

##***************************************************************************************************************************
## Enable early KMS.

function enable_earlykms_apt() {
	if grep -wq "${GPU}" /etc/initramfs-tools/modules > /dev/null 2>&1; then
		echo "Early KMS is already enabled."
	else
		echo "${GPU}" >> /etc/initramfs-tools/modules
		update-initramfs -u
	fi
}

function enable_earlykms_pacman() {
	if grep -wq "MODULES=(${GPU}.*" /etc/mkinitcpio.conf > /dev/null 2>&1; then
		echo "Early KMS is already enabled."
	else
		sed -i -e "s/^MODULES=(/MODULES=(${GPU} /g" /etc/mkinitcpio.conf
		for lnxkrnl in /etc/mkinitcpio.d/*.preset; do mkinitcpio -p "$lnxkrnl";  done
	fi
}

##***************************************************************************************************************************
## Enable IOMMU.

function setup_bootloader() {
	check_iommu
	(set_cpu_iommu
	find_grub) | dialog --backtitle "Single GPU Passthrought Configuration Script" --programbox "System configuration..." 12 60
}

function check_iommu() {
	if compgen -G "/sys/kernel/iommu_groups/*/devices/*" > /dev/null 2>&1; then
		populate_iommu
	else
		(echo -e "AMD's IOMMU/Intel's VT-D is not enabled in the BIOS/UEFI. \nReboot and enable it."
	echo -e "NOTE: You can still use VMs with Virtio (VirtGL on/off) \noffering excellent performance.") | dialog --backtitle "Single GPU Passthrought Configuration Script" --programbox "System configuration..." 10 60
		vm_choice
		chk_create
		exit 1
	fi
}

function set_cpu_iommu() {
	if lscpu | grep -i "model name" | grep -iq amd ; then
		IOMMU_CPU=amd
	else
		IOMMU_CPU=intel
	fi
}

function find_grub() {
	if [ -f /etc/default/grub ] > /dev/null 2>&1; then
		enable_iommu_grub
	else
		find_systemdb
	fi
}

function find_systemdb() {
	if bootctl | grep -i "systemd-boot" > /dev/null ; then
		SDBP="$(bootctl | grep -i "source" | awk '{print $2}')"
		enable_iommu_systemdb
	else
		echo "Boot Manager not found, please enable IOMMU manually in your boot manager."
	fi
}

function enable_iommu_grub() {
	if grep -q "${IOMMU_CPU}_iommu=on" /etc/default/grub ; then
		echo "IOMMU is already enabled."
	else
		sed -i -e "s/iommu=pt//g" /etc/default/grub
		sed -i -e "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"${IOMMU_CPU}_iommu=on iommu=pt /g" /etc/default/grub
		grub-mkconfig -o /boot/grub/grub.cfg > /dev/null 2>&1
		echo "IOMMU enabled GRUB configuration file generated. Reboot your PC before you run VM."
	fi
}

function enable_iommu_systemdb() {
	if grep -q "${IOMMU_CPU}_iommu=on" ${SDBP} ; then
		echo "IOMMU is already enabled."
	else
		sed -i -e "s/iommu=pt//g" ${SDBP}
		sed -i -e "/options/s/$/ ${IOMMU_CPU}_iommu=on iommu=pt/" ${SDBP}
		echo "IOMMU line added to the Systemd-boot configuration file(s). Reboot your PC before you run VM."
	fi
}

##***************************************************************************************************************************
## Display Manager detecttion.

function check_dm() {
	if [ -f /usr/lib/systemd/system/gdm.service ] > /dev/null 2>&1; then
		DMNGR="gdm"
	elif [ -f /usr/lib/systemd/system/lightdm.service ] > /dev/null 2>&1; then
		DMNGR="lightdm"
	elif [ -f /usr/lib/systemd/system/lxdm.service ] > /dev/null 2>&1; then
		DMNGR="lightdm"
	elif [ -f /usr/lib/systemd/system/sddm.service ] > /dev/null 2>&1; then
		DMNGR="sddm"
	elif [ -f /usr/lib/systemd/system/xdm.service ] > /dev/null 2>&1; then
		DMNGR="xdm"
	else
		echo "No compatible display manager found. Change Display Manager related parts in the config manually."
	fi
}

##***************************************************************************************************************************
## Populate config file and scripts.

function populate_base_config() {
	## Create directory structure and log file
	sudo -u $(logname) mkdir -p ${IMAGES_DIR}/iso
	sudo -u $(logname) mkdir -p ${IMAGES_DIR}/macos
	sudo -u $(logname) mkdir -p ${VMS_DIR}
	sudo -u $(logname) touch ${SCRIPT_DIR}/qemu_log.txt
	## Populate config paths
	sudo -u $(logname) sed -i -e '/^LOG=/c\LOG='${SCRIPT_DIR}'/qemu_log.txt' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^IMAGES=/c\IMAGES='${SCRIPT_DIR}'/images' ${CONFIG_LOC}
	check_dm
	sudo -u $(logname) sed -i -e '/^DSPMGR=/c\DSPMGR='${DMNGR}'' ${CONFIG_LOC}
	## Set input devices settings in config file
	sudo -u $(logname) sed -i -e '/^EVENTIF01=/c\EVENTIF01='${EIF01}'' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^EVENTKBD=/c\EVENTKBD='${EKBD}'' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^EVENTMOUSE=/c\EVENTMOUSE='${EMOUSE}'' ${CONFIG_LOC}
	## USB devices settings (keyboard, mouse, joystick = exact order, add, change etc.)
	sudo -u $(logname) sed -i -e '/^usb1_vendorid=0x/c\usb1_vendorid=0x'${USB1VID}'' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^usb1_productid=0x/c\usb1_productid=0x'${USB1PID}'' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^usb2_vendorid=0x/c\usb2_vendorid=0x'${USB2VID}'' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^usb2_productid=0x/c\usb2_productid=0x'${USB2PID}'' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^usb3_vendorid=0x/c\usb3_vendorid=0x'${USB3VID}'' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^usb3_productid=0x/c\usb3_productid=0x'${USB3PID}'' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^usb4_vendorid=0x/c\usb4_vendorid=0x'${USB4VID}'' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^usb4_productid=0x/c\usb4_productid=0x'${USB4PID}'' ${CONFIG_LOC}
	sudo -u $(logname) chmod +x ${SCRIPT_DIR}/vhd_control.sh
}

function populate_ovmf() {
	sudo -u $(logname) sed -i -e '/^OVMF_CODE=/c\OVMF_CODE='${OVMF_C}'' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^OVMF_VARS=/c\OVMF_VARS='${OVMF_V}'' ${CONFIG_LOC}
}

function populate_iommu() {
	sudo -u $(logname) chmod +x "${SCRIPTS_DIR}"/tools/iommu.sh
	## Get PCI_AUDIO
	IOMMU_PCI_AUDIO="$(${SCRIPTS_DIR}/tools/iommu.sh | grep "HDA" | sed -e 's/^[ \t]*//' | head -c 7)"
	PCI_AUDIO_ID="$(${SCRIPTS_DIR}/tools/iommu.sh | grep "HDA" | sed -e 's/\( (rev\)....//g' | tail -c 11 | sed 's/]//g')"
	VIRSH_PCI_AUDIO_GET="${IOMMU_PCI_AUDIO//:/_}"
	VIRSH_PCI_AUDIO_NAME="pci_0000_${VIRSH_PCI_AUDIO_GET//./_}"
	## GPU COUNT CHECK
	gpucount_check
	## Populate config IOMMU groups
	sudo -u $(logname) sed -i -e '/^IOMMU_GPU=/c\IOMMU_GPU="'${IOMMU_GPU}'"' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^IOMMU_GPU_AUDIO=/c\IOMMU_GPU_AUDIO="'${IOMMU_GPU_AUDIO}'"' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^IOMMU_PCI_AUDIO=/c\IOMMU_PCI_AUDIO="'${IOMMU_PCI_AUDIO}'"' ${CONFIG_LOC}
	## Populate config PCI BUS IDs
	sudo -u $(logname) sed -i -e '/^videoid=/c\videoid="'${GPU_VIDEO_ID}'"' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^audioid=/c\audioid="'${GPU_AUDIO_ID}'"' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^pciaudioid=/c\pciaudioid="'${PCI_AUDIO_ID}'"' ${CONFIG_LOC}
	## Populate config Virsh devices
	sudo -u $(logname) sed -i -e '/^VIRSH_GPU=/c\VIRSH_GPU='${VIRSH_GPU_NAME}'' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^VIRSH_GPU_AUDIO=/c\VIRSH_GPU_AUDIO='${VIRSH_GPU_AUDIO_NAME}'' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^VIRSH_PCI_AUDIO=/c\VIRSH_PCI_AUDIO='${VIRSH_PCI_AUDIO_NAME}'' ${CONFIG_LOC}
}

function iommu_gpu_popget() {
	#GPU NAMES
	GPU1NM=$(${SCRIPTS_DIR}/tools/iommu.sh | grep -i "vga" | sed -n 1p | cut -d ':' -f3 | sed 's/.\{5\}$//')
	GPU2NM=$(${SCRIPTS_DIR}/tools/iommu.sh | grep -i "vga" | sed -n 2p | cut -d ':' -f3 | sed 's/.\{5\}$//')
	GPU3NM=$(${SCRIPTS_DIR}/tools/iommu.sh | grep -i "vga" | sed -n 3p | cut -d ':' -f3 | sed 's/.\{5\}$//')
	GPU4NM=$(${SCRIPTS_DIR}/tools/iommu.sh | grep -i "vga" | sed -n 4p | cut -d ':' -f3 | sed 's/.\{5\}$//')
	#IOMMU_GPU_GET
	IOMMU_GPU1="$(${SCRIPTS_DIR}/tools/iommu.sh | grep -i "vga" | sed -n 1p | sed -e 's/^[ \t]*//' | head -c 6)"
	IOMMU_GPU2="$(${SCRIPTS_DIR}/tools/iommu.sh | grep -i "vga" | sed -n 2p | sed -e 's/^[ \t]*//' | head -c 6)"
	IOMMU_GPU3="$(${SCRIPTS_DIR}/tools/iommu.sh | grep -i "vga" | sed -n 3p | sed -e 's/^[ \t]*//' | head -c 6)"
	IOMMU_GPU4="$(${SCRIPTS_DIR}/tools/iommu.sh | grep -i "vga" | sed -n 4p | sed -e 's/^[ \t]*//' | head -c 6)"
	#IOMMU_GPU_AUDIO_GET
	IOMMU_A_GPU1="$([ -z "$IOMMU_GPU1" ] && echo "" || echo "${IOMMU_GPU1}1")"
	IOMMU_A_GPU2="$([ -z "$IOMMU_GPU2" ] && echo "" || echo "${IOMMU_GPU2}1")"
	IOMMU_A_GPU3="$([ -z "$IOMMU_GPU3" ] && echo "" || echo "${IOMMU_GPU3}1")"
	IOMMU_A_GPU4="$([ -z "$IOMMU_GPU4" ] && echo "" || echo "${IOMMU_GPU4}1")"
	#GPU_VIDEO_ID_GET
	VID_GPU1="$(${SCRIPTS_DIR}/tools/iommu.sh | grep -i "vga" | sed -n 1p | sed -e 's/\( (rev\)....//g' | tail -c 11 | sed 's/]//g')"
	VID_GPU2="$(${SCRIPTS_DIR}/tools/iommu.sh | grep -i "vga" | sed -n 2p | sed -e 's/\( (rev\)....//g' | tail -c 11 | sed 's/]//g')"
	VID_GPU3="$(${SCRIPTS_DIR}/tools/iommu.sh | grep -i "vga" | sed -n 3p | sed -e 's/\( (rev\)....//g' | tail -c 11 | sed 's/]//g')"
	VID_GPU4="$(${SCRIPTS_DIR}/tools/iommu.sh | grep -i "vga" | sed -n 4p | sed -e 's/\( (rev\)....//g' | tail -c 11 | sed 's/]//g')"
	#GPU_AUDIO_ID_GET
	AID_GPU1="$([ -z "${IOMMU_A_GPU1}" ] && echo "" || ${SCRIPTS_DIR}/tools/iommu.sh | grep "${IOMMU_A_GPU1}" | sed -e 's/\( (rev\)....//g' | tail -c 11 | sed 's/]//g')"
	AID_GPU2="$([ -z "${IOMMU_A_GPU2}" ] && echo "" || ${SCRIPTS_DIR}/tools/iommu.sh | grep "${IOMMU_A_GPU2}" | sed -e 's/\( (rev\)....//g' | tail -c 11 | sed 's/]//g')"
	AID_GPU3="$([ -z "${IOMMU_A_GPU3}" ] && echo "" || ${SCRIPTS_DIR}/tools/iommu.sh | grep "${IOMMU_A_GPU3}" | sed -e 's/\( (rev\)....//g' | tail -c 11 | sed 's/]//g')"
	AID_GPU4="$([ -z "${IOMMU_A_GPU4}" ] && echo "" || ${SCRIPTS_DIR}/tools/iommu.sh | grep "${IOMMU_A_GPU4}" | sed -e 's/\( (rev\)....//g' | tail -c 11 | sed 's/]//g')"
}

function gpucount_check() {
	iommu_gpu_popget
	[ -z "$IOMMU_GPU2" ] && single_gpu || multi_gpu
}

function single_gpu() {
	IOMMU_GPU="${IOMMU_GPU1}0"
	IOMMU_GPU_AUDIO="${IOMMU_A_GPU1}"
	GPU_VIDEO_ID="${VID_GPU1}"
	GPU_AUDIO_ID="${AID_GPU1}"
	VIRSH_GPU_GET="${IOMMU_GPU//:/_}"
	VIRSH_GPU_NAME="pci_0000_${VIRSH_GPU_GET//./_}"
	VIRSH_GPU_AUDIO_GET="${IOMMU_GPU_AUDIO//:/_}"
	VIRSH_GPU_AUDIO_NAME="pci_0000_${VIRSH_GPU_AUDIO_GET//./_}"
}

function multi_gpu() {
	gpupt_choice=$(dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title     "GPU Passthrough choice." \
		--nocancel \
		--menu "Choose GPU to pass to the config:" 11 80 4 \
		"1." "${GPU1NM}" \
		"2." "${GPU2NM}" \
		"3." "${GPU3NM}" \
		"4." "${GPU4NM}" 3>&1 1>&2 2>&3)
	case $gpupt_choice in
	"1.")
		IOMMU_GPU="${IOMMU_GPU1}0"
		IOMMU_GPU_AUDIO="${IOMMU_A_GPU1}"
		GPU_VIDEO_ID="${VID_GPU1}"
		GPU_AUDIO_ID="${AID_GPU1}"
		VIRSH_GPU_GET="${IOMMU_GPU//:/_}"
		VIRSH_GPU_NAME="pci_0000_${VIRSH_GPU_GET//./_}"
		VIRSH_GPU_AUDIO_GET="${IOMMU_GPU_AUDIO//:/_}"
		VIRSH_GPU_AUDIO_NAME="pci_0000_${VIRSH_GPU_AUDIO_GET//./_}"
		;;
	"2.")
		IOMMU_GPU="${IOMMU_GPU2}0"
		IOMMU_GPU_AUDIO="${IOMMU_A_GPU2}"
		GPU_VIDEO_ID="${VID_GPU2}"
		GPU_AUDIO_ID="${AID_GPU2}"
		VIRSH_GPU_GET="${IOMMU_GPU//:/_}"
		VIRSH_GPU_NAME="pci_0000_${VIRSH_GPU_GET//./_}"
		VIRSH_GPU_AUDIO_GET="${IOMMU_GPU_AUDIO//:/_}"
		VIRSH_GPU_AUDIO_NAME="pci_0000_${VIRSH_GPU_AUDIO_GET//./_}"
		;;
	"3.")
		IOMMU_GPU="${IOMMU_GPU3}0"
		IOMMU_GPU_AUDIO="${IOMMU_A_GPU3}"
		GPU_VIDEO_ID="${VID_GPU3}"
		GPU_AUDIO_ID="${AID_GPU3}"
		VIRSH_GPU_GET="${IOMMU_GPU//:/_}"
		VIRSH_GPU_NAME="pci_0000_${VIRSH_GPU_GET//./_}"
		VIRSH_GPU_AUDIO_GET="${IOMMU_GPU_AUDIO//:/_}"
		VIRSH_GPU_AUDIO_NAME="pci_0000_${VIRSH_GPU_AUDIO_GET//./_}"
		;;
	"4.")
		IOMMU_GPU="${IOMMU_GPU4}0"
		IOMMU_GPU_AUDIO="${IOMMU_A_GPU4}"
		GPU_VIDEO_ID="${VID_GPU4}"
		GPU_AUDIO_ID="${AID_GPU4}"
		VIRSH_GPU_GET="${IOMMU_GPU//:/_}"
		VIRSH_GPU_NAME="pci_0000_${VIRSH_GPU_GET//./_}"
		VIRSH_GPU_AUDIO_GET="${IOMMU_GPU_AUDIO//:/_}"
		VIRSH_GPU_AUDIO_NAME="pci_0000_${VIRSH_GPU_AUDIO_GET//./_}"
		;;
	esac
}

##***************************************************************************************************************************
## VM creation and configuration.

function vm_choice() {
	vmtypech=$(dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title     "Virtual Machine Selection." \
		--nocancel \
		--menu "Select VM Type:" 13 60 6 \
		"1. Custom OS PT"   "- VGA passthrough" \
		"2. Custom OS"      "- Virtio/QXL/STD (no pt)" \
		"3. macOS PT"       "- VGA passthrough" \
		"4. macOS"          "- QXL (no passthrough)" \
		"5. Remove existing VM" "" \
		"6. Exit VM Choice" "" 3>&1 1>&2 2>&3)
	case $vmtypech in
	"1. Custom OS PT")
		create_customvm
		create_pt
		customvm_iso
		io_uring
		legacy_bios
		gpu_method
		gpucount_check_pt
		custom_optset_pt
		ICON_NAME="television.svg"
		startupsc_custom
		reminder | dialog --backtitle "Single GPU Passthrought Configuration Script" --programbox "Reminder." 13 60
		another_os
		;;
	"2. Custom OS")
		create_customvm
		custom_vgpu
		customvm_iso
		io_uring
		legacy_bios
		custom_optset
		ICON_NAME="television.svg"
		sc_custom
		remindernpt | dialog --backtitle "Single GPU Passthrought Configuration Script" --programbox "Reminder." 10 60
		another_os
		;;
	"3. macOS PT")
		create_customvm
		create_macospt
		macosvm_iso
		gpu_method
		gpucount_check_pt
		custom_optset_pt
		download_macos
		ICON_NAME="apple.svg"
		startupsc_custom
		reminder | dialog --backtitle "Single GPU Passthrought Configuration Script" --programbox "Reminder." 13 60
		another_os
		;;
	"4. macOS")
		create_customvm
		create_macosqxl
		macosvm_iso
		custom_optset
		download_macos
		ICON_NAME="apple.svg"
		sc_custom
		remindernpt | dialog --backtitle "Single GPU Passthrought Configuration Script" --programbox "Reminder." 10 60
		another_os
		;;
	"5. Remove existing VM")
		remove_vm_select
		another_os
		;;
	"6. Exit VM Choice")
		clear
		;;
	esac
}

function create_customvm() {
	customvmname
}

function customvmname() {
	cstvmname=$(dialog --backtitle "Single GPU Passthrought Configuration Script" \
		--title     "VM Name." \
		--nocancel --inputbox "Choose name for your VM (no special characters):" 7 60 --output-fd 1)
	if [ -z "${cstvmname//[a-zA-Z0-9_]}" ] && [ -n "$cstvmname" ] && [ -n  "${cstvmname//[0-9]}" ]; then
		customvmoverwrite_check
	else
		unset cstvmname
		customvmname
	fi
}

function customvmoverwrite_check() {
	if [ -f ${VMS_DIR}/${cstvmname}.sh ] > /dev/null 2>&1; then
		dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title     "VM Overwrite." \
		--defaultno --yesno "VM named \"${cstvmname}\" already exist.\n Overwrite \"${cstvmname}\" VM (this will delete VHD with the same name as well)?" 7 60
		askcstovrw=$?
		case $askcstovrw in
		0)
			customvhdsize
			;;
		1)
			customvmname
			;;
		esac
	else
		customvhdsize
	fi
}

function customvhdsize() {
	cstvhdsize=$(dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title     "VHD Size." \
		--nocancel --inputbox "Choose your \"${cstvmname}\" VHD size (in GB, numeric only):" 7 60 --output-fd 1)
	if [ -z "${cstvhdsize//[0-9]}" ] && [ -n "$cstvhdsize" ]; then
		sudo -u $(logname) qemu-img create -f qcow2 -o preallocation=metadata,compat=1.1,lazy_refcounts=on ${IMAGES_DIR}/${cstvmname}.qcow2 ${cstvhdsize}G | dialog --backtitle "Single GPU Passthrought Configuration Script" --progressbox "VHD creation..." 6 60
		IMGVMSET=''${cstvmname}'_IMG=$IMAGES/'${cstvmname}'.qcow2'
		sudo -u $(logname) sed -i -e '/^## '${cstvmname}'_VM/c\' ${CONFIG_LOC}
		sudo -u $(logname) sed -i -e '/^'${cstvmname}'_IMG=/c\' ${CONFIG_LOC}
		sudo -u $(logname) echo -e "\n## ${cstvmname}_VM" >> ${CONFIG_LOC}
		sudo -u $(logname) echo ${IMGVMSET} >> ${CONFIG_LOC}
	else
		unset cstvhdsize
		customvhdsize
	fi
}

function customvm_iso() {
	(echo "Use SPACE to select and ARROW keys to navigate!"
	echo "Copy your iso to:"
	echo "${IMAGES_DIR}/iso/"
	echo "directory before you press enter and continue.") | dialog --backtitle "Single GPU Passthrought Configuration Script" --programbox "WARNING." 10 60
	isoname=$(dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title     "ISO selection." --stdout \
		--nocancel --title "Select installation .iso file:" --fselect ${IMAGES_DIR}/iso/ 20 60)
	if [ -f "$isoname" ] && [ -n "$isoname" ]; then
		ISOVMSET=''${cstvmname}'_ISO='${isoname}''
		sudo -u $(logname) sed -i -e '/^'${cstvmname}'_ISO=/c\' ${CONFIG_LOC}
		sudo -u $(logname) echo $ISOVMSET >> ${CONFIG_LOC}
	else
		echo "\"$isoname\" is not a file." | dialog --backtitle "Single GPU Passthrought Configuration Script" --programbox "ISO selection." 7 60
		customvm_iso
	fi
}

function create_pt() {
	sudo -u $(logname) cp ${SCRIPTS_DIR}/templates/vm_tp_pt ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e 's/${DUMMY_IMG}/${'${cstvmname}'_IMG}/g' ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e 's/${DUMMY_ISO}/${'${cstvmname}'_ISO}/g' ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) chmod +x ${VMS_DIR}/${cstvmname}.sh
}

function create_qxl() {
	sudo -u $(logname) cp ${SCRIPTS_DIR}/templates/vm_tp_vio ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e 's/${DUMMY_IMG}/${'${cstvmname}'_IMG}/g' ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e 's/${DUMMY_ISO}/${'${cstvmname}'_ISO}/g' ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e "s/-vga virtio -display sdl,gl=on/-vga qxl -display sdl/g" ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) chmod +x ${VMS_DIR}/${cstvmname}.sh
}

function create_virtio() {
	sudo -u $(logname) cp ${SCRIPTS_DIR}/templates/vm_tp_vio ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e 's/${DUMMY_IMG}/${'${cstvmname}'_IMG}/g' ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e 's/${DUMMY_ISO}/${'${cstvmname}'_ISO}/g' ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e "s/-vga virtio -display sdl,gl=on/-vga virtio -display sdl,gl=off/g" ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) chmod +x ${VMS_DIR}/${cstvmname}.sh
}

function create_virgl() {
	sudo -u $(logname) cp ${SCRIPTS_DIR}/templates/vm_tp_vio ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e 's/${DUMMY_IMG}/${'${cstvmname}'_IMG}/g' ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e 's/${DUMMY_ISO}/${'${cstvmname}'_ISO}/g' ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) chmod +x ${VMS_DIR}/${cstvmname}.sh
}

function create_std() {
	sudo -u $(logname) cp ${SCRIPTS_DIR}/templates/vm_tp_vio ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e 's/${DUMMY_IMG}/${'${cstvmname}'_IMG}/g' ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e 's/${DUMMY_ISO}/${'${cstvmname}'_ISO}/g' ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e "s/-vga virtio -display sdl,gl=on/-vga std/g" ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) chmod +x ${VMS_DIR}/${cstvmname}.sh
}

##***************************************************************************************************************************
## System Configuration.

function custom_optset() {
	custom_smp
	custom_ram
}

function custom_optset_pt() {
	custom_smp
	custom_ram
	hugepages_set
	echo -e 'ULIMIT_TARGET=$(( $(echo $'${cstvmname}'_RAM)*1048576+100000 ))' >> ${CONFIG_LOC}
}

function custom_smp() {
	sudo -u $(logname) sed -i -e '/^'${cstvmname}'_SMPS=/c\' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^'${cstvmname}'_CORES=/c\' ${CONFIG_LOC}
	cstmsmp=$(dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title     "Set VM Cores." \
		--nocancel --inputbox "Set number of SMPs (cores+threads, numeric only):" 7 60 --output-fd 1)
	if [ -z "${cstmsmp//[0-9]}" ] && [ -n "$cstmsmp" ] && [ $cstmsmp -gt 0 ]; then
		if [[ $((cstmsmp % 2)) -eq 0 ]]; then
			
			custom_cores
		else
			sudo -u $(logname) echo "${cstvmname}_SMPS=${cstmsmp}" >> ${CONFIG_LOC}
			sudo -u $(logname) echo "${cstvmname}_CORES=${cstmsmp}" >> ${CONFIG_LOC}
			sudo -u $(logname) sed -i -e 's/${SMPS}/${'${cstvmname}'_SMPS}/g' ${VMS_DIR}/${cstvmname}.sh
			sudo -u $(logname) sed -i -e 's/${CORES}/${'${cstvmname}'_CORES}/g' ${VMS_DIR}/${cstvmname}.sh
			sudo -u $(logname) sed -i -e 's/threads=2/threads=1/g' ${VMS_DIR}/${cstvmname}.sh
		fi
	else
		unset cstmsmp
		custom_smp
	fi
}

function custom_cores() {
	cstmcores="$(( cstmsmp / 2 ))"
	smt_ht=$(dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title     "Set VM Cores." \
		--nocancel \
		--menu "Choose VM Cores Configuration:" 9 60 4 \
		"1. HT/SMT Enabled" "${cstmcores} core(s), ${cstmsmp} thread(s)" \
		"2. HT/SMT Disabled" "${cstmsmp} core(s), ${cstmsmp} thread(s)" 3>&1 1>&2 2>&3)
	case $smt_ht in
	"1. HT/SMT Enabled")
		sudo -u $(logname) echo "${cstvmname}_SMPS=${cstmsmp}" >> ${CONFIG_LOC}
		sudo -u $(logname) echo "${cstvmname}_CORES=${cstmcores}" >> ${CONFIG_LOC}
		sudo -u $(logname) sed -i -e 's/${SMPS}/${'${cstvmname}'_SMPS}/g' ${VMS_DIR}/${cstvmname}.sh
		sudo -u $(logname) sed -i -e 's/${CORES}/${'${cstvmname}'_CORES}/g' ${VMS_DIR}/${cstvmname}.sh
		;;
	"2. HT/SMT Disabled")
		sudo -u $(logname) echo "${cstvmname}_SMPS=${cstmsmp}" >> ${CONFIG_LOC}
		sudo -u $(logname) echo "${cstvmname}_CORES=${cstmsmp}" >> ${CONFIG_LOC}
		sudo -u $(logname) sed -i -e 's/${SMPS}/${'${cstvmname}'_SMPS}/g' ${VMS_DIR}/${cstvmname}.sh
		sudo -u $(logname) sed -i -e 's/${CORES}/${'${cstvmname}'_CORES}/g' ${VMS_DIR}/${cstvmname}.sh
		sudo -u $(logname) sed -i -e 's/threads=2/threads=1/g' ${VMS_DIR}/${cstvmname}.sh
		;;
	esac
}

function custom_ram() {
	cstmram=$(dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title     "Set VM RAM." \
		--nocancel --inputbox "Set VM RAM amount (numeric only):" 7 60 --output-fd 1)
	if [ -z "${cstmram//[0-9]}" ] && [ -n "$cstmram" ]; then
		sudo -u $(logname) sed -i -e '/^'${cstvmname}'_RAM=/c\' ${CONFIG_LOC}
		sudo -u $(logname) echo "${cstvmname}_RAM=${cstmram}" >> ${CONFIG_LOC}
		sudo -u $(logname) sed -i -e 's/-m ${RAM}/-m ${'${cstvmname}'_RAM}G/g' ${VMS_DIR}/${cstvmname}.sh
	else
		unset cstmram
		custom_ram
	fi
}

function hugepages_set() {
	dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title "HUGEPAGES Settings." \
		--yesno "Enable HUGEPAGES?" 6 60
	hpgenable=$?
	case $hpgenable in
	0)
		HPGC="$(( (cstmram * 1050) / 2))"
		sudo -u $(logname) sed -i -e '/^'${cstvmname}'_HUGEPAGES=/c\' ${CONFIG_LOC}
		sudo -u $(logname) echo "${cstvmname}_HUGEPAGES=${HPGC}" >> ${CONFIG_LOC}
		sudo -u $(logname) sed -i -e 's/${HUGEPAGES}/${'${cstvmname}'_HUGEPAGES}/g' ${VMS_DIR}/${cstvmname}.sh
		;;
	1)
		sudo -u $(logname) sed -i -e 's: -mem-path /dev/hugepages::g' ${VMS_DIR}/${cstvmname}.sh
		sudo -u $(logname) sed -i -e '/sysctl -qw/d' ${VMS_DIR}/${cstvmname}.sh
		sudo -u $(logname) sed -i -e '/nr_hugepages/d' ${VMS_DIR}/${cstvmname}.sh
		sudo -u $(logname) sed -i -e '/oad hugepages/d' ${VMS_DIR}/${cstvmname}.sh
		sudo -u $(logname) sed -i -e 'N;/^\n$/D;P;D;' ${VMS_DIR}/${cstvmname}.sh
		;;
	esac
}

function io_uring() {
	dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title "AIO Settings." \
		--yesno "Enable io_uring AIO (QEMU>=5.0, linux>=5.1)? " 5 60
	iouringin=$?
	case $iouringin in
	0)
		sudo -u $(logname) sed -i -e 's/-drive if=virtio,aio=native,cache=none,format=qcow2,file=${'${cstvmname}'_IMG}/-drive aio=io_uring,cache=none,format=qcow2,file=${'${cstvmname}'_IMG}/g' ${VMS_DIR}/${cstvmname}.sh
		;;
	1)
		check_virtio_win
		;;
	esac
}

function legacy_bios() {
	dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title "BIOS/UEFI VM Settings." \
		--defaultno --yesno "Enable legacy BIOS?" 5 60
	lgbios=$?
	case $lgbios in
	0)
		sudo -u $(logname) sed -i -e 's/-drive if=pflash,format=raw,readonly,file=${OVMF_CODE}/-boot menu=on,splash-time=5000/g' ${VMS_DIR}/${cstvmname}.sh
		;;
	1)
		unset lgbios
		;;
	esac	
}

##***************************************************************************************************************************
## Graphics Configuration.

function gpu_method() {
	gpumchoice=$(dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title     "GPU Passthrough method choice." \
		--nocancel \
		--menu "Choose method to pass your device:" 11 60 4 \
		"1. Standard"        "- no VBIOS, no workarounds" \
		"2. AMD"             "- workaround for Windows driver bug" \
		"3. GPU VBIOS"       "- needs manual extraction and editing in case of nvidia" \
		"4. GPU VBIOS AMD"   "- for AMD GPUs that need Windows bug workaround, needs manual extraction" 3>&1 1>&2 2>&3)
	case $gpumchoice in
	"1. Standard")
		unset gpumchoice
		;;
	"2. AMD")
		sudo -u $(logname) sed -i -e 's/pcie-root-port,bus=pcie.0,multifunction=on,port=1,chassis=1,id=port.1/ioh3420,bus=pcie.0,addr=1c.0,multifunction=on,port=1,chassis=1,id=root.1/g' ${VMS_DIR}/${cstvmname}.sh
		sudo -u $(logname) sed -i -e 's/host=${IOMMU_GPU},bus=port.1,multifunction=on/host=${IOMMU_GPU},bus=root.1,addr=00.0,multifunction=on,x-vga=on/g' ${VMS_DIR}/${cstvmname}.sh
		sudo -u $(logname) sed -i -e 's/host=${IOMMU_GPU_AUDIO},bus=port.1/host=${IOMMU_GPU_AUDIO},bus=root.1,addr=00.1/g' ${VMS_DIR}/${cstvmname}.sh
		;;
	"3. GPU VBIOS")
		sudo -u $(logname) sed -i -e 's/host=${IOMMU_GPU},bus=port.1,multifunction=on/host=${IOMMU_GPU},bus=port.1,multifunction=on,romfile=$VBIOS/g' ${VMS_DIR}/${cstvmname}.sh
		;;
	"4. GPU VBIOS AMD")
		sudo -u $(logname) sed -i -e 's/pcie-root-port,bus=pcie.0,multifunction=on,port=1,chassis=1,id=port.1/ioh3420,bus=pcie.0,addr=1c.0,multifunction=on,port=1,chassis=1,id=root.1/g' ${VMS_DIR}/${cstvmname}.sh
		sudo -u $(logname) sed -i -e 's/host=${IOMMU_GPU},bus=port.1,multifunction=on/host=${IOMMU_GPU},bus=root.1,addr=00.0,multifunction=on,x-vga=on,romfile=$VBIOS/g' ${VMS_DIR}/${cstvmname}.sh
		sudo -u $(logname) sed -i -e 's/host=${IOMMU_GPU_AUDIO},bus=port.1/host=${IOMMU_GPU_AUDIO},bus=root.1,addr=00.1/g' ${VMS_DIR}/${cstvmname}.sh
		;;
	esac
}

function custom_vgpu() {
	vgpuchoice=$(dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title     "Virtual GPU Selection." \
		--nocancel \
		--menu "Choose Virtual Graphic Card:" 11 60 4 \
		"1. Virtio"   "- 2D, very fast, no OpenGL accleration" \
		"2. VirtGL"   "- 3D, kernel >= 4.4 and mesa >=11.2" \
		"3. QXL"      "- compatible and relatively fast 2D" \
		"4. STD"      "- default QEMU graphics, compatible" 3>&1 1>&2 2>&3)
	case $vgpuchoice in
	"1. Virtio")
		create_virtio
		;;
	"2. VirtGL")
		create_virgl
		;;
	"3. QXL")
		create_qxl
		;;
	"4. STD")
		create_std
		;;
	esac
}

function gpucount_check_pt() {
	iommu_gpu_popget
	if [ -z "$IOMMU_GPU2" ];
	then
		unset IOMMU_GPU4
	else
		multi_gpu
		custom_gpu
		display_check
	fi
}

function custom_gpu() {
	## Remove previous VM config (if any)
	sudo -u $(logname) sed -i -e '/^## IOMMU_'${cstvmname}'_VM/c\' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^IOMMU_GPU_'${cstvmname}'/c\' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^VIRSH_GPU_'${cstvmname}'/c\' ${CONFIG_LOC}
	## Populate VM config IOMMU groups
	sudo -u $(logname) echo -e "## IOMMU_${cstvmname}_VM" >> ${CONFIG_LOC}
	sudo -u $(logname) echo -e 'IOMMU_GPU_'${cstvmname}'="'${IOMMU_GPU}'"' >> ${CONFIG_LOC}
	sudo -u $(logname) echo -e 'IOMMU_GPU_'${cstvmname}'_AUDIO="'${IOMMU_GPU_AUDIO}'"' >> ${CONFIG_LOC}
	## Populate VM config Virsh devices
	sudo -u $(logname) echo -e 'VIRSH_GPU_'${cstvmname}'="'${VIRSH_GPU_NAME}'"' >> ${CONFIG_LOC}
	sudo -u $(logname) echo -e 'VIRSH_GPU_'${cstvmname}'_AUDIO="'${VIRSH_GPU_AUDIO_NAME}'"' >> ${CONFIG_LOC}
	## Change VM script IOMMU/VIRSH settings
	sudo -u $(logname) sed -i -e 's/${VIRSH_GPU}/${VIRSH_GPU_'${cstvmname}'}/g' ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e 's/${VIRSH_GPU_AUDIO}/${VIRSH_GPU_'${cstvmname}'_AUDIO}/g' ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e 's/${IOMMU_GPU}/${IOMMU_GPU_'${cstvmname}'}/g' ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e 's/${IOMMU_GPU_AUDIO}/${IOMMU_GPU_'${cstvmname}'_AUDIO}/g' ${VMS_DIR}/${cstvmname}.sh
}

function display_check() {
	DSPL2="$(ps e | grep -Po " DISPLAY=[\.0-9A-Za-z:]* " | sort -u | sed -n 2p)"
	if [ -z "$DSPL2" ]; then
		unset DSPL2
	else
		multi_display
	fi
}

function multi_display() {
	(echo -e " Multiple display devices detected. Killing display \nmanager, user session etc. can be removed from the VM."
	echo -e " You can add it back later from templates if needed, but \nusually you do not need to kill DM, user session etc."
	echo -e "when using multiple displays, unless for testing.") | dialog --backtitle "Single GPU Passthrought Configuration Script" --programbox "Display configuration..." 11 60
	dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title "Multi display VM script settings." \
		--yesno "Remove killing user session from the VM script?" 5 60
	rmkilldmus=$?
	case $rmkilldmus in
	0)
		sed -i -e '/Display Manager/d' ${VMS_DIR}/${cstvmname}.sh
		sed -i -e '/user sessions services/d' ${VMS_DIR}/${cstvmname}.sh
		sed -i -e '/EFI framebuffer and console/d' ${VMS_DIR}/${cstvmname}.sh
		sed -i -e '/nvidia/d' ${VMS_DIR}/${cstvmname}.sh
		sed -i -e '/^systemctl stop/d' ${VMS_DIR}/${cstvmname}.sh
		sed -i -e '/^systemctl start/d' ${VMS_DIR}/${cstvmname}.sh
		sed -i -e '\:/sys/class/vtconsole/vtcon:d' ${VMS_DIR}/${cstvmname}.sh
		sed -i -e '\:efi-framebuffer.0:d' ${VMS_DIR}/${cstvmname}.sh
		sed -i -e 'N;/^\n$/D;P;D;' ${VMS_DIR}/${cstvmname}.sh
		;;
	1)
		unset rmkilldmus
		;;
	esac	
}

##***************************************************************************************************************************
## MacOS Specific.

function create_macospt() {
	sudo -u $(logname) cp ${SCRIPTS_DIR}/templates/mos_tp_pt ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e 's/${DUMMY_IMG}/${'${cstvmname}'_IMG}/g' ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e 's/${DUMMY_ISO}/${'${cstvmname}'_ISO}/g' ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) chmod +x ${VMS_DIR}/${cstvmname}.sh
}

function create_macosqxl() {
	sudo -u $(logname) cp ${SCRIPTS_DIR}/templates/mos_tp_qxl ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e 's/${DUMMY_IMG}/${'${cstvmname}'_IMG}/g' ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e 's/${DUMMY_ISO}/${'${cstvmname}'_ISO}/g' ${VMS_DIR}/${cstvmname}.sh
	sudo -u $(logname) chmod +x ${VMS_DIR}/${cstvmname}.sh
}

function macosvm_iso() {
	ISOVMSET=''${cstvmname}'_ISO=$IMAGES/iso/'${cstvmname}'.img'
	sudo -u $(logname) sed -i -e '/^'${cstvmname}'_ISO=/c\' ${CONFIG_LOC}
	sudo -u $(logname) echo $ISOVMSET >> ${CONFIG_LOC}
}

function download_macos() {
	macos_choice=$(dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title     "macOS-Simple-KVM script by Foxlet" \
		--nocancel \
		--menu "Choose macOS base:" 11 60 4 \
		"1. macOS 10.15"     "- Catalina" \
		"2. macOS 10.14"     "- Mojave" \
		"3. macOS 10.13"     "- High Sierra" \
		"4. Select IMG"      "- Base image already downloaded from options above" 3>&1 1>&2 2>&3)
	case $macos_choice in
	"1. macOS 10.15")
		(sudo -u $(logname) git clone https://github.com/foxlet/macOS-Simple-KVM.git && cd macOS-Simple-KVM && sudo -u $(logname) ./jumpstart.sh --catalina && cd ..) 2>&1 | dialog --backtitle "Single GPU Passthrought Configuration Script" --progressbox "Downloading macOS, this may take a while, please wait..." 12 60
		sudo -u $(logname) mv -f macOS-Simple-KVM/BaseSystem.img ${IMAGES_DIR}/iso/${cstvmname}.img
		sudo -u $(logname) mv -f macOS-Simple-KVM/ESP.qcow2 ${IMAGES_DIR}/macos/
		sudo -u $(logname) mkdir -p ${IMAGES_DIR}/macos/firmware
		sudo -u $(logname) cp -rf macOS-Simple-KVM/firmware/* ${IMAGES_DIR}/macos/firmware/
		rm -rf macOS-Simple-KVM
		;;
	"2. macOS 10.14")
		(sudo -u $(logname) git clone https://github.com/foxlet/macOS-Simple-KVM.git && cd macOS-Simple-KVM && sudo -u $(logname) ./jumpstart.sh --mojave && cd ..) 2>&1 | dialog --backtitle "Single GPU Passthrought Configuration Script" --progressbox "Downloading macOS, this may take a while, please wait..." 12 60
		sudo -u $(logname) mv -f macOS-Simple-KVM/BaseSystem.img ${IMAGES_DIR}/iso/${cstvmname}.img
		sudo -u $(logname) mv -f macOS-Simple-KVM/ESP.qcow2 ${IMAGES_DIR}/macos/
		sudo -u $(logname) mkdir -p ${IMAGES_DIR}/macos/firmware
		sudo -u $(logname) cp -rf macOS-Simple-KVM/firmware/* ${IMAGES_DIR}/macos/firmware/
		rm -rf macOS-Simple-KVM
		;;
	"3. macOS 10.13")
		(sudo -u $(logname) git clone https://github.com/foxlet/macOS-Simple-KVM.git && cd macOS-Simple-KVM && sudo -u $(logname) ./jumpstart.sh --high-sierra && cd ..) 2>&1 | dialog --backtitle "Single GPU Passthrought Configuration Script" --progressbox "Downloading macOS, this may take a while, please wait..." 12 60
		sudo -u $(logname) mv -f macOS-Simple-KVM/BaseSystem.img ${IMAGES_DIR}/iso/${cstvmname}.img
		sudo -u $(logname) mv -f macOS-Simple-KVM/ESP.qcow2 ${IMAGES_DIR}/macos/
		sudo -u $(logname) mkdir -p ${IMAGES_DIR}/macos/firmware
		sudo -u $(logname) cp -rf macOS-Simple-KVM/firmware/* ${IMAGES_DIR}/macos/firmware/
		rm -rf macOS-Simple-KVM
		;;
	"4. Select IMG")
		unset macos_choice
		macosimg_select
		;;
	esac
}

function macosimg_select() {
	(echo "Use SPACE to select and ARROW keys to navigate!"
	echo "Select downloaded macOS IMG file from:"
	echo "${IMAGES_DIR}/iso/"
	echo "directory before you press enter and continue.") | dialog --backtitle "Single GPU Passthrought Configuration Script" --programbox "WARNING." 10 60
	isoname=$(dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title     "Select IMG." --stdout \
		--nocancel --title "Select macOS base IMG file:" --fselect ${IMAGES_DIR}/iso/ 20 60)
	if [ -f "$isoname" ]; then
		ISOVMSET=''${cstvmname}'_ISO='${isoname}''
		sudo -u $(logname) sed -i -e '/^'${cstvmname}'_ISO=/c\' ${CONFIG_LOC}
		sudo -u $(logname) echo $ISOVMSET >> ${CONFIG_LOC}
	else
		customvm_iso
	fi
}

##***************************************************************************************************************************
## Virtio Configuration.

function check_virtio_win() {
	if [ -f ${IMAGES_DIR}/iso/virtio-win.iso ] > /dev/null 2>&1; then
		inject_virtio_windows
	else
		download_virtio
	fi
}

function download_virtio() {
	dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title "Windows Virtio Drivers." \
		--defaultno --yesno "Download virtio drivers for Windows guests (usually required)?" 6 60
	askvirtio=$?
	case $askvirtio in
	0)
		(sudo -u $(logname) curl --retry 10 --retry-delay 1 --retry-max-time 60 https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.173-9/virtio-win-0.1.173.iso -o virtio-win.iso) 2>&1 | dialog --backtitle "Single GPU Passthrought Configuration Script" --progressbox "Downloading Windows Virtio Drivers, please wait..." 12 60
		sudo -u $(logname) mv virtio-win.iso ${IMAGES_DIR}/iso/
		inject_virtio_windows
		;;
	1)
		unset askvirtio
		;;
	esac
}

function inject_virtio_windows() {
	dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title "Windows Virtio Drivers." \
		--yesno "Add virtio Windows drivers .iso to the VM (needed for Windows guests)?" 6 60
	injectvirtio=$?
	case $injectvirtio in
	0)
		sudo -u $(logname) sed -i -e 's/-drive file=$'${cstvmname}'_ISO,index=1,media=cdrom/-drive file=$'${cstvmname}'_ISO,index=1,media=cdrom -drive file=$VIRTIO,index=2,media=cdrom/g' ${VMS_DIR}/"${cstvmname}".sh
		;;
	1)
		unset injectvirtio
		;;
	esac
}

##***************************************************************************************************************************
## Startup Scripts and Shortcuts

function startupsc_custom() {
		echo "cd ${VMS_DIR} && sudo nohup ./${cstvmname}.sh > /tmp/nohup.log 2>&1" > /usr/local/bin/${cstvmname}-vm
		chmod +x /usr/local/bin/${cstvmname}-vm
		sudo -u $(logname) mkdir -p /home/$(logname)/.local/share/applications/
		sudo -u $(logname) echo "[Desktop Entry]
Name=${cstvmname} VM
Exec=xterm -e ${cstvmname}-vm
Icon=${ICONS_DIR}/${ICON_NAME}
Type=Application" > /home/$(logname)/.local/share/applications/${cstvmname}.desktop
	echo -e "Created \"${cstvmname}\" VM startup script, you can run the vm by typing \"${cstvmname}-vm\" in terminal or choosing from applications menu."
}

function sc_custom() {
	dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title "Shortcut Creation." \
		--yesno "Do you want to create \"${cstvmname}\" shortcut?" 5 60
	asknoptshort=$?
	case $asknoptshort in
	0)
	    	sudo -u $(logname) mkdir -p /home/$(logname)/.local/share/applications/
		sudo -u $(logname) echo "[Desktop Entry]
Name=${cstvmname} VM
Exec=${VMS_DIR}/${cstvmname}.sh
Icon=${ICONS_DIR}/${ICON_NAME}
Type=Application" > /home/$(logname)/.local/share/applications/${cstvmname}.desktop
		;;
	1)
		unset asknoptshort
		;;
	esac	
}

##***************************************************************************************************************************
## Remove VM

function remove_vm_select() {
	echo "Use SPACE to select and ARROW keys to navigate!" | dialog --backtitle "Single GPU Passthrought Configuration Script" --programbox "Remove Virtual Machine." 7 60
	rmvmslct=$(dialog --title "Remove Virtual Machine." --stdout --title "Select VM to remove:" --fselect ${VMS_DIR}/ 20 60)
	filename=$(basename -- "$rmvmslct")
	rmvmname="${filename%.*}"
	if [ -z $rmvmname ]; then
		echo "No VM file selected." | dialog --backtitle "Single GPU Passthrought Configuration Script" --programbox "Remove Virtual Machine." 7 60
	else 
		remove_vm $rmvmname
	fi
}

function remove_vm(){
	if [ -f $rmvmslct ] 
	then
		rm ${VMS_DIR}/${rmvmname}.sh > /dev/null 2>&1
		rm ${IMAGES_DIR}/${rmvmname}.qcow2 > /dev/null 2>&1
		rm /usr/local/bin/${rmvmname}-vm > /dev/null 2>&1
		rm /home/$(logname)/.local/share/applications/${rmvmname}.desktop > /dev/null 2>&1
		## Remove previous VM config
		sudo -u $(logname) sed -i -e '/^## '${rmvmname}'_VM/c\' ${CONFIG_LOC} > /dev/null 2>&1
		sudo -u $(logname) sed -i -e '/^'${rmvmname}'_IMG=/c\' ${CONFIG_LOC} > /dev/null 2>&1
		sudo -u $(logname) sed -i -e '/^'${rmvmname}'_ISO=/c\' ${CONFIG_LOC} > /dev/null 2>&1
		sudo -u $(logname) sed -i -e '/^'${rmvmname}'_SMPS=/c\' ${CONFIG_LOC} > /dev/null 2>&1
		sudo -u $(logname) sed -i -e '/^'${rmvmname}'_CORES=/c\' ${CONFIG_LOC} > /dev/null 2>&1
		sudo -u $(logname) sed -i -e '/^'${rmvmname}'_RAM=/c\' ${CONFIG_LOC} > /dev/null 2>&1
		sudo -u $(logname) sed -i -e '/^'${rmvmname}'_HUGEPAGES=/c\' ${CONFIG_LOC} > /dev/null 2>&1
		sudo -u $(logname) sed -i -e '/^## IOMMU_'${rmvmname}'_VM/c\' ${CONFIG_LOC} > /dev/null 2>&1
		sudo -u $(logname) sed -i -e '/^IOMMU_GPU_'${rmvmname}'/c\' ${CONFIG_LOC} > /dev/null 2>&1
		sudo -u $(logname) sed -i -e '/^VIRSH_GPU_'${rmvmname}'/c\' ${CONFIG_LOC} > /dev/null 2>&1
		sudo -u $(logname) sed -i -e '/echo $'${rmvmname}'_RAM/c\' ${CONFIG_LOC} > /dev/null 2>&1
		sudo -u $(logname) sed -i -e 'N;/^\n$/D;P;D;' ${CONFIG_LOC} > /dev/null 2>&1
		echo "Virtual Machine \"${rmvmname}\" removed." | dialog --backtitle "Single GPU Passthrought Configuration Script" --programbox "Remove Virtual Machine." 7 60
	else
		echo "\"${rmvmname}\" is not a file." | dialog --backtitle "Single GPU Passthrought Configuration Script" --programbox "Remove Virtual Machine." 7 60
		remove_vm_select
	fi
}

##***************************************************************************************************************************
## Various

## Directory structure.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd )"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
IMAGES_DIR="${SCRIPT_DIR}/images"
VMS_DIR="${SCRIPTS_DIR}/VMS"
ICONS_DIR="${SCRIPT_DIR}/icons"
CONFIG_LOC="${SCRIPTS_DIR}/config"
## Get GPU kernel module information.
GPU="$(lspci -nnk | grep -i vga -A3 | grep 'in use' | cut -d ':' -f2 | cut -d ' ' -f2)"
## Get input devices information
EIF01="$(ls /dev/input/by-id/ | grep -i "event-if01")"
EKBD="$(ls /dev/input/by-id/ | grep -i "event-kbd")"
EMOUSE="$(ls /dev/input/by-id/ | grep -i "event-mouse")"
## Get USB information.
USB1VID="$(lsusb | grep -i "keyboard" | head -c 33 | cut -d ':' -f2 | tail -c5)"
USB1PID="$(lsusb | grep -i "keyboard" | head -c 33 | tail -c5 | sed -e 's/ //g')"
USB2VID="$(lsusb | grep -i "mouse" | head -c 33 | cut -d ':' -f2 | tail -c5)"
USB2PID="$(lsusb | grep -i "mouse" | head -c 33 | tail -c5 | sed -e 's/ //g')"
USB3VID="$(lsusb | grep -i "joystick" | head -c 33 | cut -d ':' -f2 | tail -c5)"
USB3PID="$(lsusb | grep -i "joystick" | head -c 33 | tail -c5 | sed -e 's/ //g')"
USB4VID=""
USB4PID=""

function another_os() {
	dialog  --backtitle "Single GPU Passthrought Configuration Script" \
		--title "VM Creation." \
		--defaultno --yesno "Start auto configuration for another OS?" 5 60
	askanotheros=$?
	case $askanotheros in
	0)
		vm_choice
		;;
	1)
		unset askanotheros
		clear
		;;
	esac
}

function reminder() {
	echo -e "Everything is Done."
	echo -e "VBIOS: You must extract, edit and load VBIOS for VM. \nInfo at:\n https://gitlab.com/YuriAlek/vfio/-/wikis/vbios ."
	echo -e "Read relevant information on YuriAlek's page at:\n https://gitlab.com/YuriAlek/vfio \nor in \"docs\" directory."
}

function remindernpt() {
	echo -e "Everything is Done."
	echo -e "Read relevant information on YuriAlek's page at:\n https://gitlab.com/YuriAlek/vfio \nor in \"docs\" directory."
}

function remindernopkgm() {
	echo -e "Everything is Done."
	echo -e "VBIOS: You must extract, edit and load VBIOS for VM. \nInfo at:\nhttps://gitlab.com/YuriAlek/vfio/-/wikis/vbios ."
	echo -e "WARNING: You must install packages equivalent to Arch\n\"qemu ovmf libvirt virt-manager virglrenderer curl xterm\" packages."
	echo -e "WARNING: You must enable IOMMU for your CPU in distribution boot manager."
	echo -e "Read relevant information on YuriAlek's page at:\n https://gitlab.com/YuriAlek/vfio \nor in \"docs\" directory."
}

function chk_create() {
	sudo -u $(logname) touch ${SCRIPT_DIR}/.frchk
}

##***************************************************************************************************************************

first_run

unset LC_ALL

exit 0
