#!/bin/bash

export LC_ALL=C

## Check if script was executed with the root privileges.
[[ "$EUID" -ne 0 ]] && echo "Please run with root privileges." && sleep 1 && exit 1

function welcomescript() {
	clear
	echo "----------------------------------------------------------------"
	echo "- Welcome to the Single GPU Passthrought configuration script. -"
	echo "-  Note: This script attempts to do as little assumptions as   -"
	echo "-  possible, but some assumptions were made, introducig a      -"
	echo "-   chance that script may not work properly. Be advised.      -"
	echo "----------------------------------------------------------------"
	echo ""
	echo " Do you wish to continue?"
	while true; do
	read -r -p " I understand and wish to continue [Y/n] (default: Yes) " -e -i y startchoice
	case $startchoice in
	[yY][eE][sS]|[yY])
		checkos_install
		;;
	[nN][oO]|[nN])
		exit 0
		;;
	*)
		echo "Invalid input, please answer with Yes or No."
		unset startchoice
		welcomescript
		;;
	esac
	done
}

function checkos_install() {
	if command -v apt > /dev/null 2>&1; then
		populate_base_config
		install_dep_apt
		addgroups
		enable_earlykms_apt
		setup_bootloader
		vm_choice
		chk_create
		reminder
	elif command -v yum > /dev/null 2>&1; then
		populate_base_config
		install_dep_yum
		addgroups
		setup_bootloader
		vm_choice
		chk_create
		reminder
	elif command -v zypper > /dev/null 2>&1; then
		populate_base_config
		install_dep_zypper
		addgroups
		setup_bootloader
		vm_choice
		chk_create
		reminder
		echo "zypper"
	elif command -v pacman > /dev/null 2>&1; then
		populate_base_config
		install_dep_pacman
		addgroups
		enable_earlykms_pacman
		setup_bootloader
		vm_choice
		chk_create
		reminder
	else
		echo "No compatible package manager found."
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
	echo " It seems that this is not the first run of the configuration script, if your system is already configured you may"
	echo "  wish to skip to the VM creation part. This will save some time if IOMMU groups, loaders and paths are already"
	echo "  properly configured. If you however made some changes to the hardware, software or changed script location"
	echo "  you may wish to run checks again and you should answer NO."
	echo ""
	while true; do
	read -r -p " Do you wish to skip to the VM creation part? [Y/n] (default: Yes) " -e -i y nfrinput
	case $nfrinput in
	[yY][eE][sS]|[yY])
		unset nfrinput
		vm_choice
		;;
	[nN][oO]|[nN])
		unset nfrinput
		welcomescript
		;;
	*)
		echo "Invalid input, please answer with Yes or No."
		unset nfrinput
		notfirstrun
		;;
	esac
	done
}

function continue_script() {
	echo -e "\033[1;31mYou must have packages equivalent to Arch \"qemu ovmf libvirt virt-manager virglrenderer curl\" packages installed in order to continue.\033[0m"
	while true; do
	read -r -p " Do you want to continue with script? [Y/n] " askconts
	case $askconts in
	    	[yY][eE][sS]|[yY])
	    	populate_base_config
		check_iommu
		vm_choice
		chk_create
		remindernopkgm
		exit 1
		;;
	[nN][oO]|[nN])
		unset askconts
		exit 1
		;;
	*)
		echo "Invalid input..."
		unset askconts
		continue_script
		;;
	esac
	done
}

##***************************************************************************************************************************
## Install dependencies.

function install_dep_apt() {
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
	echo -e "\033[1;36mDependencies are installed.\033[0m"
}

function install_dep_yum() {
	echo "Installing packages, please wait."
	yum -yq groups install "virtualization"
	uym -yq install curl xterm git
	echo -e "\033[1;36mDependencies are installed.\033[0m"
}

function install_dep_zypper() {
	echo "Installing packages, please wait."
	zypper -n install patterns-openSUSE-kvm_server patterns-server-kvm_tools ovmf xterm curl
	echo -e "\033[1;36mDependencies are installed.\033[0m"
}

function install_dep_pacman() {
	if pacman -Q qemu ovmf libvirt virt-manager virglrenderer ovmf curl xterm git > /dev/null 2>&1; then
		echo -e "\033[1;36mDependencies are already installed.\033[0m"
	else
		echo "Installing dependencies, please wait..."
		pacman -S --noconfirm qemu ovmf libvirt virt-manager virglrenderer ovmf curl xterm git > /dev/null
		echo -e "\033[1;36mDependencies are installed.\033[0m"
	fi
}

##***************************************************************************************************************************
## Add user to groups.

function addgroups() {
	if groups $(logname) | grep kvm | grep libvirt > /dev/null 2>&1; then
		echo -e "\033[1;36mUser is already in groups.\033[0m"
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
		echo -e "\033[1;36mEarly KMS is already enabled.\033[0m"
	else
		echo "Enabling early KMS..."
		echo "${GPU}" >> /etc/initramfs-tools/modules
		update-initramfs -u
	fi
}

function enable_earlykms_pacman() {
	if grep -wq "MODULES=(${GPU}.*" /etc/mkinitcpio.conf > /dev/null 2>&1; then
		echo -e "\033[1;36mEarly KMS is already enabled.\033[0m"
	else
		echo "Enabling early KMS..."
		sed -i -e "s/^MODULES=(/MODULES=(${GPU} /g" /etc/mkinitcpio.conf
		for lnxkrnl in /etc/mkinitcpio.d/*.preset; do mkinitcpio -p "$lnxkrnl";  done
	fi
}

##***************************************************************************************************************************
## Enable IOMMU.

function setup_bootloader() {
	check_iommu
	set_cpu_iommu
	find_grub
}

function check_iommu() {
	if compgen -G "/sys/kernel/iommu_groups/*/devices/*" > /dev/null 2>&1; then
		echo -e "\033[1;36mAMD's IOMMU / Intel's VT-D is enabled in the BIOS/UEFI.\033[0m"
		populate_iommu
		autologintty3
	else
		echo -e "\033[1;31mAMD's IOMMU / Intel's VT-D is not enabled in the BIOS/UEFI. Reboot and enable it.\033[0m"
		echo -e "\033[1;36mNOTE: You can still use VMs with VirGL paravirtualization offering excellent performance.\033[0m"
		vm_choice
		remindergl
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
	echo "Searching for GRUB..."
	if [ -f /etc/default/grub ] > /dev/null 2>&1; then
		enable_iommu_grub
	else
		echo "GRUB not found."
		find_systemdb
	fi
}

function find_systemdb() {
	echo "Searching for Systemd-boot"
	if bootctl | grep -i "systemd-boot" > /dev/null ; then
		SDBP="$(bootctl | grep -i "source" | awk '{print $2}')"
		enable_iommu_systemdb
	else
		echo "Systemd-boot not found."
		echo -e "\033[1;31mBoot Manager not found, please enable IOMMU manually in your boot manager.\033[0m"
	fi
}

function enable_iommu_grub() {
	if grep -q "${IOMMU_CPU}_iommu=on" /etc/default/grub ; then
		echo -e "\033[1;36mIOMMU is already enabled.\033[0m"
	else
		sed -i -e "s/iommu=pt//g" /etc/default/grub
		sed -i -e "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"${IOMMU_CPU}_iommu=on iommu=pt /g" /etc/default/grub
		echo "IOMMU line added to the GRUB configuration file(s)."
		echo "Generating GRUB configuration file, please wait..."
		update-grub > /dev/null 2>&1
		grub-mkconfig -o /boot/grub/grub.cfg > /dev/null 2>&1
		echo "GRUB configuration file generated."
	fi
}

function enable_iommu_systemdb() {
	if grep -q "${IOMMU_CPU}_iommu=on" ${SDBP} ; then
		echo -e "\033[1;36mIOMMU is already enabled.\033[0m"
	else
		sed -i -e "s/iommu=pt//g" ${SDBP}
		sed -i -e "/options/s/$/ ${IOMMU_CPU}_iommu=on iommu=pt/" ${SDBP}
		echo "IOMMU line added to the Systemd-boot configuration file(s)."
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
		echo "No compatible display manager found. Change Display Manager related parts in the VM.sh scripts manually."
	fi
}

##***************************************************************************************************************************
## Populate config file and scripts.

function populate_base_config() {
	## Populate config paths
	sudo -u $(logname) sed -i '/^LOG=/c\LOG='${SCRIPT_DIR}'/qemu_log.txt' ${CONFIG_LOC}
	sudo -u $(logname) sed -i '/^FIRMWARE=/c\FIRMWARE='${IMAGES_DIR}'/macos/firmware' ${CONFIG_LOC}
	sudo -u $(logname) sed -i '/^IMAGES=/c\IMAGES='${SCRIPT_DIR}'/images' ${CONFIG_LOC}
	## Set number of cores in the config file
	sudo -u $(logname) sed -i '/^CORES=/c\CORES='${CORES_NUM_GET}'' ${CONFIG_LOC}
	sudo -u $(logname) sed -i '/^MACOS_CORES=/c\MACOS_CORES='${CORES_NUM_GET}'' ${CONFIG_LOC}
	## Set VM RAM size based on free memory
	sudo -u $(logname) sed -i '/^RAM=/c\RAM='${RAMFF}'G' ${CONFIG_LOC}
	## Set VM hugepages size based on VM RAM
	sudo -u $(logname) sed -i -e '/^HUGEPAGES=/c\HUGEPAGES='${HPG}'' ${CONFIG_LOC}
	check_dm
	sudo -u $(logname) sed -i -e '/^DSPMGR=/c\DSPMGR='${DMNGR}'' ${CONFIG_LOC}
	## Set input devices settings in config file
	sudo -u $(logname) sed -i -e '/^EVENTIF01=/c\EVENTIF01='${EIF01}'' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^EVENTKBD=/c\EVENTKBD='${EKBD}'' ${CONFIG_LOC}
	sudo -u $(logname) sed -i -e '/^EVENTMOUSE=/c\EVENTMOUSE='${EMOUSE}'' ${CONFIG_LOC}
}

function populate_iommu() {
	echo "Populating config file for IOMMU, please wait..."
	## Get IOMMU groups
	sudo -u $(logname) chmod +x "${SCRIPTS_DIR}"/iommu.sh
	IOMMU_GPU_GET="$(${SCRIPTS_DIR}/iommu.sh | grep "VGA" | sed -e 's/^[ \t]*//' | head -c 7)"
	IOMMU_GPU_AUDIO_GET="$(${SCRIPTS_DIR}/iommu.sh | grep "HDMI" | sed -e 's/^[ \t]*//' | head -c 7)"
	IOMMU_PCI_AUDIO_GET="$(${SCRIPTS_DIR}/iommu.sh | grep "HDA" | sed -e 's/^[ \t]*//' | head -c 7)"
	## Get PCI BUS IDs
	videoid_GET="$(${SCRIPTS_DIR}/iommu.sh | grep "VGA" | sed -e 's/\( (rev\)....//g' | tail -c 11 | sed 's/]//g')"
	audioid_GET="$(${SCRIPTS_DIR}/iommu.sh | grep "HDMI" | sed -e 's/\( (rev\)....//g' | tail -c 11 | sed 's/]//g')"
	pciaudioid_GET="$(${SCRIPTS_DIR}/iommu.sh | grep "HDA" | sed -e 's/\( (rev\)....//g' | tail -c 11 | sed 's/]//g')"
	## Get Virsh devices names
	VIRSH_GPU_GET="${IOMMU_GPU_GET//:/_}"
	VIRSH_GPU_NAME="pci_0000_${VIRSH_GPU_GET//./_}"
	VIRSH_GPU_AUDIO_GET="${IOMMU_GPU_AUDIO_GET//:/_}"
	VIRSH_GPU_AUDIO_NAME="pci_0000_${VIRSH_GPU_AUDIO_GET//./_}"
	VIRSH_PCI_AUDIO_GET="${IOMMU_PCI_AUDIO_GET//:/_}"
	VIRSH_PCI_AUDIO_NAME="pci_0000_${VIRSH_PCI_AUDIO_GET//./_}"
	## Populate config IOMMU groups
	sudo -u $(logname) sed -i '/^IOMMU_GPU=/c\IOMMU_GPU="'${IOMMU_GPU_GET}'"' ${CONFIG_LOC}
	sudo -u $(logname) sed -i '/^IOMMU_GPU_AUDIO=/c\IOMMU_GPU_AUDIO="'${IOMMU_GPU_AUDIO_GET}'"' ${CONFIG_LOC}
	sudo -u $(logname) sed -i '/^IOMMU_PCI_AUDIO=/c\IOMMU_PCI_AUDIO="'${IOMMU_PCI_AUDIO_GET}'"' ${CONFIG_LOC}
	## Populate config PCI BUS IDs
	sudo -u $(logname) sed -i '/^videoid=/c\videoid="'${videoid_GET}'"' ${CONFIG_LOC}
	sudo -u $(logname) sed -i '/^audioid=/c\audioid="'${audioid_GET}'"' ${CONFIG_LOC}
	sudo -u $(logname) sed -i '/^pciaudioid=/c\pciaudioid="'${pciaudioid_GET}'"' ${CONFIG_LOC}
	## Populate config Virsh devices
	sudo -u $(logname) sed -i '/^VIRSH_GPU=/c\VIRSH_GPU='${VIRSH_GPU_NAME}'' ${CONFIG_LOC}
	sudo -u $(logname) sed -i '/^VIRSH_GPU_AUDIO=/c\VIRSH_GPU_AUDIO='${VIRSH_GPU_AUDIO_NAME}'' ${CONFIG_LOC}
	sudo -u $(logname) sed -i '/^VIRSH_PCI_AUDIO=/c\VIRSH_PCI_AUDIO='${VIRSH_PCI_AUDIO_NAME}'' ${CONFIG_LOC}
	echo "Config file populated with IOMMU settings."
}

##***************************************************************************************************************************
## VM creation and configuration.

function vm_choice() {
	echo " Choose VM Type:"
	echo "	1) Custom OS (VGA passthrough)"
	echo "	2) Custom OS (QXL - no passthrough)"
	echo "	3) Custom OS (Virtio - no passthrough)"
	echo "	4) macOS (VGA passthrough)"
	echo "	5) macOS (QXL - no passthrough)"
	echo "	6) Exit VM Choice"
	until [[ $VM_CHOICE =~ ^[1-6]$ ]]; do
		read -r -p " VM type choice [1-6]: " VM_CHOICE
	done
	case $VM_CHOICE in
	1)
		unset VM_CHOICE
		create_customvm
		create_pt
		askgpu_custom_pt
		download_virtio
		startupsc_custom
		unset IMGVMSET ISOVMSET cstvmname cstvhdname cstvhdsize isoname
		echo "Virtual Machine Created."
		another_os
		;;
	2)
		unset VM_CHOICE
		create_customvm
		create_qxl
		download_virtio
		scnopt_custom
		unset IMGVMSET ISOVMSET cstvmname cstvhdname cstvhdsize isoname
		echo "Virtual Machine Created."
		another_os
		;;
	3)
		unset VM_CHOICE
		create_customvm
		create_virtio
		download_virtio
		scnopt_custom
		unset IMGVMSET ISOVMSET cstvmname cstvhdname cstvhdsize isoname
		echo "Virtual Machine Created."
		;;
	4)
		unset VM_CHOICE
		create_macos
		download_macos
		create_macospt
		startupsc_macos
		unset IMGVMSET macosname macvhdname macvhdsize
		echo "Virtual Machine Created."
		another_os
		;;
	5)
		unset VM_CHOICE
		create_macos
		download_macos
		create_macosqxl
		shortcut_macosqxl
		unset IMGVMSET macosname macvhdname macvhdsize
		echo "Virtual Machine Created."
		another_os
		;;
	6)
		unset VM_CHOICE
		;;
	esac
}

function create_customvm() {
	echo "Custom VM creation:"
	echo "Before you continue please copy your .iso image into ${IMAGES_DIR}/iso/ directory."
	customvmname
}

function customvmname() {
	read -r -p " Choose name for your VM: " cstvmname
	if [[ "$cstvmname" =~ ^[a-zA-Z0-9]*$ ]]; then
		if grep -wq "$cstvmname" ${CONFIG_LOC} ; then
			read -r -p "$cstvmname VM already exist. Overwrite it? [Y/n] " askovrwrtvm
			case $askovrwrtvm in
			[yY][eE][sS]|[yY])
				unset askovrwrtvm
				customvhdname
				;;
			[nN][oO]|[nN]|*)
				unset askovrwrtvm cstvmname
				customvmname
				;;
			esac
		else
			customvhdname
		fi
	else
		echo "Ivalid input. No special characters allowed."
		unset cstvmname
		customvmname
	fi
}

function customvhdname() {
	read -r -p " Choose name for your VHD (e.g. vhd1): " cstvhdname
	if [[ "$cstvhdname" =~ ^[a-zA-Z0-9]*$ ]]; then
		if [ -f ${CONFIG_LOC}/${cstvhdname}.qcow ] ; then
			read -r -p "$cstvhdname VHD already exist. Overwrite it? [Y/n] " askovrwrtvhd
			case $askovrwrtvhd in
			[yY][eE][sS]|[yY])
				unset askovrwrtvhd
				customvhdsize
				;;
			[nN][oO]|[nN]|*)
				unset askovrwrtvhd cstvhdname
				customvhdname
				;;
			esac
		else
			customvhdsize
		fi
	else
		echo "Ivalid input. No special characters allowed."
		customvhdname
	fi
}

function customvhdsize() {
	read -r -p " Choose your VHD size (in GB, numeric only): " cstvhdsize
	if [[ "$cstvhdsize" =~ ^[0-9]*$ ]]; then
		sudo -u $(logname) qemu-img create -f qcow2 ${IMAGES_DIR}/${cstvhdname}.qcow2 ${cstvhdsize}G
		ls -R -1 ${IMAGES_DIR}/iso/
		read -r -p "Type/copy the name of desired iso including extension (.iso): " isoname
		IMGVMSET=''${cstvmname}'_IMG=$IMAGES/'${cstvhdname}'.qcow2'
		ISOVMSET=''${cstvmname}'_ISO=$IMAGES/iso/'${isoname}''
		sudo -u $(logname) echo -e "\n## ${cstvmname}" >> ${CONFIG_LOC}
		sudo -u $(logname) echo $IMGVMSET >> ${CONFIG_LOC}
		sudo -u $(logname) echo $ISOVMSET >> ${CONFIG_LOC}
	else
		echo "Invalid input, use only numerics."
		unset cstvhdsize
		customvhdsize
	fi
}

function create_pt() {
	sudo -u $(logname) cp ${SCRIPTS_DIR}/bps/vm_bp_pt ${SCRIPTS_DIR}/"${cstvmname}".sh
	sudo -u $(logname) sed -i -e "s/DUMMY_IMG/${cstvmname}_IMG/g" ${SCRIPTS_DIR}/"${cstvmname}".sh
	sudo -u $(logname) sed -i -e "s/DUMMY_ISO/${cstvmname}_ISO/g" ${SCRIPTS_DIR}/"${cstvmname}".sh
	sudo -u $(logname) chmod +x ${SCRIPTS_DIR}/${cstvmname}.sh
}

function askgpu_custom_pt() {
	echo "GPU Passthrough choice."
	echo "	1) Default (should work with most GPUs)"
	echo "	2) AMD (workaround for Windows driver bug)"
	until [[ $askgpupt =~ ^[1-2]$ ]]; do
		read -r -p "Choose device to pass [1-2]: " -e -i 1 askgpupt
	done
	case $askgpupt in
	1)
		unset askgpupt
		;;
	2)
		sudo -u $(logname) sed -i -e 's/pcie-root-port,bus=pcie.0,multifunction=on,port=1,chassis=1,id=port.1/ioh3420,bus=pcie.0,addr=1c.0,multifunction=on,port=1,chassis=1,id=root.1/g' ${SCRIPTS_DIR}/"${cstvmname}".sh
		sudo -u $(logname) sed -i -e 's/host=$IOMMU_GPU,bus=port.1,multifunction=on/host=$IOMMU_GPU,bus=root.1,addr=00.0,multifunction=on,x-vga=on/g' ${SCRIPTS_DIR}/"${cstvmname}".sh
		sudo -u $(logname) sed -i -e 's/host=$IOMMU_GPU_AUDIO,bus=port.1/host=$IOMMU_GPU_AUDIO,bus=root.1,addr=00.1/g' ${SCRIPTS_DIR}/"${cstvmname}".sh
		unset askgpupt
		;;
	esac
}

function create_virtio() {
	sudo -u $(logname) cp ${SCRIPTS_DIR}/bps/vm_bp_vio ${SCRIPTS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e "s/DUMMY_IMG/${cstvmname}_IMG/g" ${SCRIPTS_DIR}/"${cstvmname}".sh
	sudo -u $(logname) sed -i -e "s/DUMMY_ISO/${cstvmname}_ISO/g" ${SCRIPTS_DIR}/"${cstvmname}".sh
	sudo -u $(logname) chmod +x ${SCRIPTS_DIR}/${cstvmname}.sh
	echo "By default, VirGL is enabled, it needs special drivers for OS other than GNU/Linux, it offers freat performance but can be buggy."
	echo "VirGL requires kernel >=4.4 and mesa >=11.2 compiled with 'gallium-drivers=virgl' option."
	read -r -p "Disable VirGL? (default: enabled) [Y/n] " askvirgl
		case $askvirgl in
	[yY][eE][sS]|[yY])
		sudo -u $(logname) sed -i -e "s/-vga virtio -display gtk,gl=on/-vga virtio -display gtk,gl=off/g" ${SCRIPTS_DIR}/"${cstvmname}".sh
		;;
	[nN][oO]|[nN])
		unset askvirgl
		;;
	*)
		echo "Invalid input..."
		unset askvirgl
		create_virtio
		;;
	esac
}

function create_qxl() {
	sudo -u $(logname) cp ${SCRIPTS_DIR}/bps/vm_bp_vio ${SCRIPTS_DIR}/${cstvmname}.sh
	sudo -u $(logname) sed -i -e "s/DUMMY_IMG/${cstvmname}_IMG/g" ${SCRIPTS_DIR}/"${cstvmname}".sh
	sudo -u $(logname) sed -i -e "s/DUMMY_ISO/${cstvmname}_ISO/g" ${SCRIPTS_DIR}/"${cstvmname}".sh
	sudo -u $(logname) sed -i -e "s/-vga virtio -display gtk,gl=on/-vga qxl/g" ${SCRIPTS_DIR}/"${cstvmname}".sh
	sudo -u $(logname) chmod +x ${SCRIPTS_DIR}/${cstvmname}.sh
}

function create_macos() {
	echo "MacOS VM creation:"
	macosvmname
}
function macosvmname() {
	read -r -p " Choose name for your MacOS VM: " macosname
	if [[ "$macosname" =~ ^[a-zA-Z0-9]*$ ]]; then
		if grep -wq "$macosname" ${CONFIG_LOC} ; then
			read -r -p "$macosname VM already exist. Overwrite it? [Y/n] " askovrwrtmos
			case $askovrwrtmos in
			[yY][eE][sS]|[yY])
				unset askovrwrtmos
				macosvhdname
				;;
			[nN][oO]|[nN]|*)
				unset askovrwrtmos macosname
				macosvmname
				;;
			esac
		else
			macosvhdname
		fi
	else
		echo "Ivalid input. No special characters allowed."
		unset macosname
		macosvmname
	fi
}

function macosvhdname() {
	read -r -p " Choose name for your VHD (e.g. macosX): " macvhdname
	if [[ "$macvhdname" =~ ^[a-zA-Z0-9]*$ ]]; then
		if [ -f ${CONFIG_LOC}/${macvhdname}.qcow ] ; then
		read -r -p "$macvhdname VHD already exist. Overwrite it? [Y/n] " askovrwrtmvhd
			case $askovrwrtmvhd in
			[yY][eE][sS]|[yY])
				unset askovrwrtmvhd
				macosvhdsize
				;;
			[nN][oO]|[nN]|*)
				unset askovrwrtmvhd macvhdname
				macosvhdname
				;;
			esac
		else
			macosvhdsize
		fi
	else
		echo "Ivalid input. No special characters allowed."
		unset macvhdname
		macosvhdname
	fi
}

function macosvhdsize() {
	read -r -p " Choose your VHD size (in GB, numeric only): " macvhdsize
	if [[ "$macvhdsize" =~ ^[0-9]*$ ]]; then
		sudo -u $(logname) qemu-img create -f qcow2 ${IMAGES_DIR}/${macvhdname}.qcow2 ${macvhdsize}G
		IMGVMSET=''${macosname}'_IMG=$IMAGES/'${macvhdname}'.qcow2'
		sudo -u $(logname) echo -e "\n## ${macosname}" >> ${CONFIG_LOC}
		sudo -u $(logname) echo $IMGVMSET >> ${CONFIG_LOC}
	else
		echo "Invalid input, use only numerics."
		unset macvhdsize
		macosvhdsize
	fi
}

function create_macospt() {
	sudo -u $(logname) cp ${SCRIPTS_DIR}/bps/mos_bp_pt ${SCRIPTS_DIR}/"${macosname}".sh
	sudo -u $(logname) sed -i -e "s/DUMMY_IMG/${macosname}_IMG/g" ${SCRIPTS_DIR}/"${macosname}".sh
	sudo -u $(logname) chmod +x ${SCRIPTS_DIR}/${macosname}.sh
}

function create_macosqxl() {
	sudo -u $(logname) cp ${SCRIPTS_DIR}/bps/mos_bp_qxl ${SCRIPTS_DIR}/"${macosname}".sh
	sudo -u $(logname) sed -i -e "s/DUMMY_IMG/${macosname}_IMG/g" ${SCRIPTS_DIR}/"${macosname}".sh
	sudo -u $(logname) chmod +x ${SCRIPTS_DIR}/${macosname}.sh
}

function download_macos() {
	echo "This will download MacOS using macOS-Simple-KVM script by Foxlet"
	echo " Choose macOS base:"
	echo "	1) 10.14 Mojave"
	echo "	2) 10.15 Catalina"
	echo "	3) 10.13 High Sierra"
	echo "	4) Base image already downloaded (from one of the options above)"
	until [[ $macos_choice =~ ^[1-4]$ ]]; do
		read -r -p " VM type choice [1-4]: " macos_choice
	done
	case $macos_choice in
	1)
		sudo -u $(logname) git clone https://github.com/foxlet/macOS-Simple-KVM.git && cd macOS-Simple-KVM && sudo -u $(logname) ./jumpstart.sh --mojave && cd ..
		sudo -u $(logname) mv macOS-Simple-KVM/BaseSystem.img ${IMAGES_DIR}/iso/
		sudo -u $(logname) mv macOS-Simple-KVM/ESP.qcow2 ${IMAGES_DIR}/macos/
		sudo -u $(logname) mv -r macOS-Simple-KVM/firmware ${IMAGES_DIR}/macos/
		rm -rf macOS-Simple-KVM
		;;
	2)
		sudo -u $(logname) git clone https://github.com/foxlet/macOS-Simple-KVM.git && cd macOS-Simple-KVM && sudo -u $(logname) ./jumpstart.sh --catalina && cd ..
		sudo -u $(logname) mv macOS-Simple-KVM/BaseSystem.img ${IMAGES_DIR}/iso/
		sudo -u $(logname) mv macOS-Simple-KVM/ESP.qcow2 ${IMAGES_DIR}/macos/
		sudo -u $(logname) mv -r macOS-Simple-KVM/firmware ${IMAGES_DIR}/macos/
		rm -rf macOS-Simple-KVM
		;;
	3)
		sudo -u $(logname) git clone https://github.com/foxlet/macOS-Simple-KVM.git && cd macOS-Simple-KVM && sudo -u $(logname) ./jumpstart.sh --high-sierra && cd ..
		sudo -u $(logname) mv macOS-Simple-KVM/BaseSystem.img ${IMAGES_DIR}/iso/
		sudo -u $(logname) mv macOS-Simple-KVM/ESP.qcow2 ${IMAGES_DIR}/macos/
		sudo -u $(logname) mv -r macOS-Simple-KVM/firmware ${IMAGES_DIR}/macos/
		rm -rf macOS-Simple-KVM
		;;
	4)
		unset macos_choice
		;;
	esac
}

function download_virtio() {
	read -r -p " Do you want to download virtio drivers for Windows guests (usually required)? [Y/n] (default: Yes) " -e -i y askvirtio
	case $askvirtio in
	    	[yY][eE][sS]|[yY])
	    	if [ -f ${IMAGES_DIR}/iso/virtio-win.iso ] > /dev/null 2>&1; then
			echo "Virto Windows drivers are already downloaded."
			unset askvirtio
		else
			sudo -u $(logname) curl https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.173-9/virtio-win-0.1.173.iso -o virtio-win.iso
			sudo -u $(logname) mv virtio-win.iso ${IMAGES_DIR}/iso/
		fi
		;;
	[nN][oO]|[nN])
		unset askvirtio
		;;
	*)
		echo "Invalid input..."
		unset askvirtio
		download_virtio
		;;
	esac	
}

function another_os() {
	read -r -p " Do you want to start auto configuration for another OS? [Y/n] (default: No) " -e -i n askanotheros
	case $askanotheros in
	    	[yY][eE][sS]|[yY])
		vm_choice
		;;
	[nN][oO]|[nN])
		unset askanotheros
		;;
	*)
		echo "Invalid input..."
		unset askanotheros
		another_os
		;;
	esac
}

##***************************************************************************************************************************
## Startup Scripts and Shortcuts

function startupsc_custom() {
		echo "sudo chvt 3
wait
cd ${SCRIPTS_DIR} && sudo nohup ./${cstvmname}.sh > /tmp/nohup.log 2>&1" > /usr/local/bin/${cstvmname}-vm
		chmod +x /usr/local/bin/${cstvmname}-vm
		sudo -u $(logname) mkdir -p /home/$(logname)/.local/share/applications/
		sudo -u $(logname) echo "[Desktop Entry]
Name=${cstvmname} VM
Exec=xterm -e ${cstvmname}-vm
Icon=${ICONS_DIR}/television.svg
Type=Application" > /home/$(logname)/.local/share/applications/${cstvmname}.desktop
	echo -e "\033[1;36mCreated ${cstvmname} VM startup script, you can run the vm by typing \"${cstvmname}-vm\" in terminal or choosing from applications menu.\033[0m"
}

function startupsc_macos() {
		echo "sudo chvt 3
wait
cd ${SCRIPTS_DIR} && sudo nohup ./${macosname}.sh > /tmp/nohup.log 2>&1" > /usr/local/bin/${macosname}-vm
		chmod +x /usr/local/bin/${macosname}-vm
		sudo -u $(logname) mkdir -p /home/$(logname)/.local/share/applications/
		sudo -u $(logname) echo "[Desktop Entry]
Name=${macosname} VM
Exec=xterm -e ${macosname}-vm
Icon=${ICONS_DIR}/apple.svg
Type=Application" > /home/$(logname)/.local/share/applications/${macosname}.desktop
}

function shortcut_macosqxl() {
		sudo -u $(logname) mkdir -p /home/$(logname)/.local/share/applications/
		sudo -u $(logname) echo "[Desktop Entry]
Name=${macosname} VM
Exec=${SCRIPTS_DIR}/${macosname}.sh
Icon=${ICONS_DIR}/apple.svg
Type=Application" > /home/$(logname)/.local/share/applications/${macosname}.desktop
}

function scnopt_custom() {
	read -r -p " Do you want to create GNU/Linux VirGL shortcut? [Y/n] (default: Yes) " -e -i y asknoptshort
	case $asknoptshort in
	    	[yY][eE][sS]|[yY])
	    	sudo -u $(logname) mkdir -p /home/$(logname)/.local/share/applications/
		sudo -u $(logname) echo "[Desktop Entry]
Name=${cstvmname} VM
Exec=${SCRIPTS_DIR}/${cstvmname}.sh
Icon=${ICONS_DIR}/television.svg
Type=Application" > /home/$(logname)/.local/share/applications/${cstvmname}.desktop
		unset asknoptshort
		echo "Shortcut created."
		;;
	[nN][oO]|[nN])
		unset asknoptshort
		;;
	*)
		echo "Invalid input..."
		unset asknoptshort
		scnopt_custom
		;;
	esac	
}

##***************************************************************************************************************************
## Various

## Directory structure.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd )"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
IMAGES_DIR="${SCRIPT_DIR}/images"
ICONS_DIR="${SCRIPT_DIR}/icons"
CONFIG_LOC="${SCRIPTS_DIR}/config"
## Get CPU and Memory information.
CORES_NUM_GET="$(nproc)"
RAMFF="$(grep MemFree /proc/meminfo | awk '{print int ($2/1024/1024-1)}')"
HPG="$(( (RAMFF * 1050) / 2))"
## Get GPU kernel module information.
GPU="$(lspci -nnk | grep -i vga -A3 | grep 'in use' | cut -d ':' -f2 | cut -d ' ' -f2)"
## Get input devices information
EIF01=$(ls /dev/input/by-id/ | grep -i "event-if01")
EKBD=$(ls /dev/input/by-id/ | grep -i "event-kbd")
EMOUSE=$(ls /dev/input/by-id/ | grep -i "event-mouse")

function autologintty3() {
	if [ -f /etc/systemd/system/getty@tty3.service.d/override.conf ] > /dev/null 2>&1; then
		echo "TTY3 autologin already enabled."
	else
		echo -e "\033[1;36mNOTE: Setting up autologin for tty3, otherwise VMs will NOT work when SIngle GPU Passthrough is used.\033[0m"
		mkdir -p /etc/systemd/system/getty@tty3.service.d/
		echo "[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin" $(logname) '--noclear %I $TERM' > /etc/systemd/system/getty@tty3.service.d/override.conf
	fi
}

function reminder() {
	echo "Everything is Done."
	echo -e "\033[1;31mIMPORTANT NOTE: If not done in the script, ISO image paths must be set in the config file, otherwise VMs will NOT work.\033[0m"
	echo -e "\033[1;36mRead relevant information on YuriAlek's page at https://gitlab.com/YuriAlek/vfio , or in Hardware configurations directory.\033[0m"
}

function remindergl() {
	echo "Everything is Done."
	echo -e "\033[1;31mIMPORTANT NOTE: If not done in the script, ISO image paths must be set in the config file, otherwise VMs will NOT work.\033[0m"
}

function remindernopkgm() {
	echo "Everything is Done."
	echo -e "\033[1;31mWARNING: You must install packages equivalent to Arch \"qemu ovmf libvirt virt-manager virglrenderer curl xterm\" packages.\033[0m"
	echo -e "\033[1;31mWARNING: You must add your user to kvm and libvirt groups on your distribution.\033[0m"
	echo -e "\033[1;31mWARNING: You must enable eraly KMS and iommu for your GPU/system in distribution boot manager.\033[0m"
	echo -e "\033[1;31mIMPORTANT NOTE: If not done in the script, ISO image paths must be set in the config file, otherwise VMs will NOT work.\033[0m"
	echo -e "\033[1;36mRead relevant information on YuriAlek's page at https://gitlab.com/YuriAlek/vfio , or in Hardware configurations directory.\033[0m"
}

function chk_create() {
	sudo -u $(logname) touch ${SCRIPT_DIR}/.frchk
}

##***************************************************************************************************************************

first_run

unset LC_ALL

exit 0
