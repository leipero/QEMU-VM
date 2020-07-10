#!/bin/bash
export LC_ALL=C

## Check if script was executed with the root privileges.
[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"

function first_run() {
	if [ -f ${SCRIPT_DIR}/.frchk ] > /dev/null 2>&1; then
		vm_choice
	else
		dep_check
		welcomescript
	fi
}

function dep_check() {
	if command -v dialog > /dev/null 2>&1; then
		clear
	else
		dep_inst
	fi
}

function dep_inst() {
	if command -v apt > /dev/null 2>&1; then
		echo "Installing script dependencies..."
		apt-get install -y dialog
	elif command -v yum > /dev/null 2>&1; then
		echo "Installing script dependencies..."
		yum -y install dialog
	elif command -v zypper > /dev/null 2>&1; then
		echo "Installing script dependencies..."
		zypper -n install dialog
	elif command -v pacman > /dev/null 2>&1; then
		echo "Installing script dependencies..."
		pacman -S --noconfirm dialog
	else
		echo "Dialog not found and package manager is unknown, please install dialog package."
		exit 1
	fi
}

function welcomescript() {
	dialog  --backtitle "QEMU VM Setup Script" \
		--title     "Welcome." \
		--yesno "Welcome to the QEMU VM Setup Script. \n Note: This script requires recent version of QEMU, KVM, OVMF, optionally recent linux kernel version as well, with earlier  versions there is a chance that script may not work properly. Do you wish to continue? " 10 60
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
		addgroups) | dialog --backtitle "QEMU VM Setup Script" --progressbox "System configuration..." 12 60
		vm_choice
		chk_create
	elif command -v yum > /dev/null 2>&1; then
		(populate_base_config
		install_dep_yum
		populate_ovmf
		addgroups) | dialog --backtitle "QEMU VM Setup Script" --progressbox "System configuration..." 12 60
		vm_choice
		chk_create
	elif command -v zypper > /dev/null 2>&1; then
		(populate_base_config
		install_dep_zypper
		populate_ovmf
		addgroups) | dialog --backtitle "QEMU VM Setup Script" --progressbox "System configuration..." 12 60
		vm_choice
		chk_create
	elif command -v pacman > /dev/null 2>&1; then
		(populate_base_config
		install_dep_pacman
		populate_ovmf
		addgroups) | dialog --backtitle "QEMU VM Setup Script" --progressbox "System configuration..." 12 60
		vm_choice
		chk_create
	else
		continue_script
	fi
}

function continue_script() {
	dialog  --backtitle "QEMU VM Setup Script" \
		--title     "Continue Setup." \
		--defaultno --yesno "You must have packages equivalent to Arch \"qemu ovmf libvirt virt-manager virglrenderer curl\" packages installed in order to continue. \nDo you wish to Continue?" 8 60
	askconts=$?
	case $askconts in
	0)
	    	(populate_base_config
	    	addgroups) | dialog --backtitle "QEMU VM Setup Script" --programbox "System configuration..." 12 60
		check_iommu
		vm_choice
		chk_create
		remindernopkgm | dialog --backtitle "QEMU VM Setup Script" --programbox "Reminder." 13 60
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
	if dpkg -s curl git > /dev/null 2>&1; then
		echo "Curl is already installed."
	else
		echo "Installing curl, please wait..."
		apt-get install -y curl git > /dev/null 2>&1
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
	yum -yq install curl git
	echo "Dependencies are installed."
}

function install_dep_zypper() {
	OVMF_C="/usr/share/qemu/ovmf-x86_64-ms-code.bin"
	OVMF_V="/usr/share/qemu/ovmf-x86_64-ms-vars.bin"
	echo "Installing packages, please wait."
	zypper -n install patterns-openSUSE-kvm_server patterns-server-kvm_tools ovmf curl
	echo "Dependencies are installed."
}

function install_dep_pacman() {
	OVMF_C="/usr/share/edk2-ovmf/x64/OVMF_CODE.fd"
	OVMF_V="/usr/share/edk2-ovmf/x64/OVMF_VARS.fd"
	if pacman -Q qemu ovmf libvirt virt-manager virglrenderer edk2-ovmf curl git > /dev/null 2>&1; then
		echo "Dependencies are already installed."
	else
		echo "Installing dependencies, please wait..."
		pacman -S --noconfirm qemu edk2-ovmf libvirt virt-manager virglrenderer ovmf curl git > /dev/null 2>&1
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
	sudo -u $(logname) chmod +x ${SCRIPT_DIR}/vhd_control.sh
}

function populate_ovmf() {
	sudo -u $(logname) sed -i -e '/^OVMF_CODE=/c\OVMF_CODE='${OVMF_C}'' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^OVMF_VARS=/c\OVMF_VARS='${OVMF_V}'' ${CONFIG_LOC}
}

##***************************************************************************************************************************
## VM creation and configuration.

function vm_choice() {
	vmtypech=$(dialog  --backtitle "QEMU VM Setup Script" \
		--title     "Virtual Machine Selection." \
		--nocancel \
		--menu "Select VM Type:" 13 60 6 \
		"1. Custom OS"      "- Virtio/QXL/STD" \
		"2. macOS"          "- QXL" \
		"3. Remove existing VM" "" \
		"4. Exit VM Choice" "" 3>&1 1>&2 2>&3)
	case $vmtypech in
	"1. Custom OS")
		create_customvm
		custom_vgpu
		customvm_iso
		io_uring
		legacy_bios
		custom_smp
		custom_ram
		ICON_NAME="television.svg"
		sc_custom
		reminder | dialog --backtitle "QEMU VM Setup Script" --programbox "Reminder." 13 60
		another_os
		;;
	"2. macOS")
		create_customvm
		create_macosqxl
		macosvm_iso
		custom_smp
		custom_ram
		download_macos
		ICON_NAME="apple.svg"
		sc_custom
		reminder | dialog --backtitle "QEMU VM Setup Script" --programbox "Reminder." 13 60
		another_os
		;;
	"3. Remove existing VM")
		remove_vm_select
		another_os
		;;
	"4. Exit VM Choice")
		clear
		;;
	esac
}

function create_customvm() {
	customvmname
}

function customvmname() {
	cstvmname=$(dialog --backtitle "QEMU VM Setup Script" \
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
		dialog  --backtitle "QEMU VM Setup Script" \
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
	cstvhdsize=$(dialog  --backtitle "QEMU VM Setup Script" \
		--title     "VHD Size." \
		--nocancel --inputbox "Choose your \"${cstvmname}\" VHD size (in GB, numeric only):" 7 60 --output-fd 1)
	if [ -z "${cstvhdsize//[0-9]}" ] && [ -n "$cstvhdsize" ]; then
		sudo -u $(logname) qemu-img create -f qcow2 ${IMAGES_DIR}/${cstvmname}.qcow2 ${cstvhdsize}G | dialog --backtitle "QEMU VM Setup Script" --progressbox "VHD creation..." 6 60
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
	echo "directory before you press enter and continue.") | dialog --backtitle "QEMU VM Setup Script" --programbox "WARNING." 10 60
	isoname=$(dialog  --backtitle "QEMU VM Setup Script" \
		--title     "ISO selection." --stdout \
		--nocancel --title "Select installation .iso file:" --fselect ${IMAGES_DIR}/iso/ 20 60)
	if [ -f "$isoname" ] && [ -n "$isoname" ]; then
		ISOVMSET=''${cstvmname}'_ISO='${isoname}''
		sudo -u $(logname) sed -i -e '/^'${cstvmname}'_ISO=/c\' ${CONFIG_LOC}
		sudo -u $(logname) echo $ISOVMSET >> ${CONFIG_LOC}
	else
		echo "\"$isoname\" is not a file." | dialog --backtitle "QEMU VM Setup Script" --programbox "ISO selection." 7 60
		customvm_iso
	fi
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

function custom_smp() {
	sudo -u $(logname) sed -i -e '/^'${cstvmname}'_SMPS=/c\' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^'${cstvmname}'_CORES=/c\' ${CONFIG_LOC}
	cstmsmp=$(dialog  --backtitle "QEMU VM Setup Script" \
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
	smt_ht=$(dialog  --backtitle "QEMU VM Setup Script" \
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
	cstmram=$(dialog  --backtitle "QEMU VM Setup Script" \
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

function io_uring() {
	dialog  --backtitle "QEMU VM Setup Script" \
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
	dialog  --backtitle "QEMU VM Setup Script" \
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

function custom_vgpu() {
	vgpuchoice=$(dialog  --backtitle "QEMU VM Setup Script" \
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

##***************************************************************************************************************************
## MacOS Specific.

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
	macos_choice=$(dialog  --backtitle "QEMU VM Setup Script" \
		--title     "macOS-Simple-KVM script by Foxlet" \
		--nocancel \
		--menu "Choose macOS base:" 11 60 4 \
		"1. macOS 10.15"     "- Catalina" \
		"2. macOS 10.14"     "- Mojave" \
		"3. macOS 10.13"     "- High Sierra" \
		"4. Select IMG"      "- Base image already downloaded from options above" 3>&1 1>&2 2>&3)
	case $macos_choice in
	"1. macOS 10.15")
		(sudo -u $(logname) git clone https://github.com/foxlet/macOS-Simple-KVM.git && cd macOS-Simple-KVM && sudo -u $(logname) ./jumpstart.sh --catalina && cd ..) 2>&1 | dialog --backtitle "QEMU VM Setup Script" --progressbox "Downloading macOS, this may take a while, please wait..." 12 60
		sudo -u $(logname) mv -f macOS-Simple-KVM/BaseSystem.img ${IMAGES_DIR}/iso/${cstvmname}.img
		sudo -u $(logname) mv -f macOS-Simple-KVM/ESP.qcow2 ${IMAGES_DIR}/macos/
		sudo -u $(logname) mkdir -p ${IMAGES_DIR}/macos/firmware
		sudo -u $(logname) cp -rf macOS-Simple-KVM/firmware/* ${IMAGES_DIR}/macos/firmware/
		rm -rf macOS-Simple-KVM
		;;
	"2. macOS 10.14")
		(sudo -u $(logname) git clone https://github.com/foxlet/macOS-Simple-KVM.git && cd macOS-Simple-KVM && sudo -u $(logname) ./jumpstart.sh --mojave && cd ..) 2>&1 | dialog --backtitle "QEMU VM Setup Script" --progressbox "Downloading macOS, this may take a while, please wait..." 12 60
		sudo -u $(logname) mv -f macOS-Simple-KVM/BaseSystem.img ${IMAGES_DIR}/iso/${cstvmname}.img
		sudo -u $(logname) mv -f macOS-Simple-KVM/ESP.qcow2 ${IMAGES_DIR}/macos/
		sudo -u $(logname) mkdir -p ${IMAGES_DIR}/macos/firmware
		sudo -u $(logname) cp -rf macOS-Simple-KVM/firmware/* ${IMAGES_DIR}/macos/firmware/
		rm -rf macOS-Simple-KVM
		;;
	"3. macOS 10.13")
		(sudo -u $(logname) git clone https://github.com/foxlet/macOS-Simple-KVM.git && cd macOS-Simple-KVM && sudo -u $(logname) ./jumpstart.sh --high-sierra && cd ..) 2>&1 | dialog --backtitle "QEMU VM Setup Script" --progressbox "Downloading macOS, this may take a while, please wait..." 12 60
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
	echo "directory before you press enter and continue.") | dialog --backtitle "QEMU VM Setup Script" --programbox "WARNING." 10 60
	isoname=$(dialog  --backtitle "QEMU VM Setup Script" \
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
	dialog  --backtitle "QEMU VM Setup Script" \
		--title "Windows Virtio Drivers." \
		--defaultno --yesno "Download virtio drivers for Windows guests (usually required)?" 6 60
	askvirtio=$?
	case $askvirtio in
	0)
		(sudo -u $(logname) curl --retry 10 --retry-delay 1 --retry-max-time 60 https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.173-9/virtio-win-0.1.173.iso -o virtio-win.iso) 2>&1 | dialog --backtitle "QEMU VM Setup Script" --progressbox "Downloading Windows Virtio Drivers, please wait..." 12 60
		sudo -u $(logname) mv virtio-win.iso ${IMAGES_DIR}/iso/
		inject_virtio_windows
		;;
	1)
		unset askvirtio
		;;
	esac
}

function inject_virtio_windows() {
	dialog  --backtitle "QEMU VM Setup Script" \
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
## Shortcuts

function sc_custom() {
	dialog  --backtitle "QEMU VM Setup Script" \
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
	echo "Use SPACE to select and ARROW keys to navigate!" | dialog --backtitle "QEMU VM Setup Script" --programbox "Remove Virtual Machine." 7 60
	rmvmslct=$(dialog --title "Remove Virtual Machine." --stdout --title "Select VM to remove:" --fselect ${VMS_DIR}/ 20 60)
	filename=$(basename -- "$rmvmslct")
	rmvmname="${filename%.*}"
	if [ -z $rmvmname ]; then
		echo "No VM file selected." | dialog --backtitle "QEMU VM Setup Script" --programbox "Remove Virtual Machine." 7 60
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
		sudo -u $(logname) sed -i -e '/echo $'${rmvmname}'_RAM/c\' ${CONFIG_LOC} > /dev/null 2>&1
		sudo -u $(logname) sed -i -e 'N;/^\n$/D;P;D;' ${CONFIG_LOC} > /dev/null 2>&1
		echo "Virtual Machine \"${rmvmname}\" removed." | dialog --backtitle "QEMU VM Setup Script" --programbox "Remove Virtual Machine." 7 60
	else
		echo "\"${rmvmname}\" is not a file." | dialog --backtitle "QEMU VM Setup Script" --programbox "Remove Virtual Machine." 7 60
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

function another_os() {
	dialog  --backtitle "QEMU VM Setup Script" \
		--title "VM Creation." \
		--defaultno --yesno "Create VM for another OS?" 5 60
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
	echo -e "You can run your VM from the shortcut or script itself, \nno superuser required."
}

function remindernopkgm() {
	echo -e "Everything is Done."
	echo -e "WARNING: You must install packages equivalent to Arch\n\"qemu ovmf libvirt virt-manager virglrenderer curl dialog\" packages."
}

function chk_create() {
	sudo -u $(logname) touch ${SCRIPT_DIR}/.frchk
}

##***************************************************************************************************************************

welcomescript

unset LC_ALL

exit 0
