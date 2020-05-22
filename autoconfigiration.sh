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
}

function checkos_install() {
	if command -v apt > /dev/null 2>&1; then
		populate_base_config
		install_dep_apt
		addgroups_apt
		enable_earlykms_apt
		setup_bootloader
	elif command -v yum > /dev/null 2>&1; then
		echo "yum"
	elif command -v dnf > /dev/null 2>&1; then
		echo "dnf"
	elif command -v zypper > /dev/null 2>&1; then
		echo "zypper"
	elif command -v pacman > /dev/null 2>&1; then
		populate_base_config
		install_dep_pacman
		addgroups_pacman
		enable_earlykms_pacman
		setup_bootloader
	else
		echo "No compatible package manager found."
		continue_script
	fi
}

function first_run() {
	if [ -f ${SCRIPTS_DIR}/.frchk ] > /dev/null 2>&1; then
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
}

function continue_script() {
	echo -e "\033[1;31mYou must have packages equivalent to Arch \"qemu ovmf libvirt virt-manager virglrenderer curl\" packages installed in order to continue.\033[0m"
	read -r -p " Do you want to continue with script? [Y/n] " askconts
	case $askconts in
	    	[yY][eE][sS]|[yY])
	    	populate_base_config
		check_iommu
		remindernopkgm
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
}

##***************************************************************************************************************************
## Install dependencies.

function install_dep_apt() {
	if dpkg -s qemu-kvm > /dev/null 2>&1; then
		echo "Qemu-kvm is already installed."
	else
		echo "Installing qemu-kvm, please wait..."
		apt-get install -y qemu-kvm > /dev/null 2>&1
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
	if dpkg -s curl bridge-utils > /dev/null 2>&1; then
		echo "Bridge-utils are already installed."
	else
		echo "Installing bridge-utils, please wait..."
		apt-get install -y curl bridge-utils > /dev/null 2>&1
	fi
	echo -e "\033[1;36mDependencies are installed.\033[0m"
}

function install_dep_pacman() {
	if pacman -Q qemu ovmf libvirt virt-manager virglrenderer curl > /dev/null 2>&1; then
		echo -e "\033[1;36mDependencies are already installed.\033[0m"
	else
		echo "Installing dependencies, please wait..."
		pacman -S --noconfirm qemu ovmf libvirt virt-manager virglrenderer curl > /dev/null
		echo -e "\033[1;36mDependencies are installed.\033[0m"
	fi
}

##***************************************************************************************************************************
## Add user to groups.

function addgroups_apt() {
	if groups $(logname) | grep kvm | grep libvirt > /dev/null 2>&1; then
		echo -e "\033[1;36mUser is already in groups.\033[0m"
	else
		adduser $(logname) libvirt
		adduser $(logname) kvm
		echo "User is now a member of the required groups."
	fi
}

function addgroups_pacman() {
	if groups $(logname) | grep kvm | grep libvirt > /dev/null 2>&1; then
		echo -e "\033[1;36mUser is already in groups.\033[0m"
	else
		gpasswd -a $(logname) libvirt
		gpasswd -a $(logname) kvm
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
	bootmgrfound
	reminder
}

function check_iommu() {
	if compgen -G "/sys/kernel/iommu_groups/*/devices/*" > /dev/null 2>&1; then
		echo -e "\033[1;36mAMD's IOMMU / Intel's VT-D is enabled in the BIOS/UEFI.\033[0m"
		vm_choice
		populate_iommu
		mkscripts_exec
		autologintty3
	else
		echo -e "\033[1;31mAMD's IOMMU / Intel's VT-D is not enabled in the BIOS/UEFI. Reboot and enable it.\033[0m"
		echo -e "\033[1;36mNOTE: You can still use VMs with VirGL paravirtualization offering excellent performance.\033[0m"
		sleep 1
		vm_choice
		remindergl
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

function bootmgrfound() {
	if [[ -n "$GPAPT" || -n "$SDBP" ]]; then
		echo "IOMMU enabled in Boot Manager."
	else
		echo -e "\033[1;31mBoot Manager not found, please enable IOMMU manually in your boot manager.\033[0m"
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
		echo "No compatible display manager found. Change Display Manager related parts in the *virsh.sh scripts manually."
	fi
	echo "Virsh scripts populated with \"${DMNGR}\" display manager."
}

##***************************************************************************************************************************
## Populate config file and scripts.

function populate_base_config() {
	# Populate config paths
	sudo -u $(logname) sed -i '/^LOG=/c\LOG='${SCRIPT_DIR}'/qemu_log.txt' ${CONFIG_LOC}
	sudo -u $(logname) sed -i '/^IMAGES=/c\IMAGES='${SCRIPT_DIR}'/images' ${CONFIG_LOC}
	# Set number of cores in the config file
	sudo -u $(logname) sed -i '/^CORES=/c\CORES='${CORES_NUM_GET}'' ${CONFIG_LOC}
	sudo -u $(logname) sed -i '/^MACOS_CORES=/c\MACOS_CORES='${CORES_NUM_GET}'' ${CONFIG_LOC}
	# Set VM RAM size based on free memory
	sudo -u $(logname) sed -i '/^RAM=/c\RAM='${RAMFF}'G' ${CONFIG_LOC}
	# Set VM hugepages size based on VM RAM
	sudo -u $(logname) sed -i -e "s/^HUGEPAGES=/HUGEPAGES=${HPG}/g" ${CONFIG_LOC}
	check_dm
	sudo -u $(logname) sed -i -e "s/^DSPMGR=/DSPMGR=${DMNGR}/g" ${CONFIG_LOC}
}

function populate_iommu() {
	echo "Populating config file for IOMMU, please wait..."
	sleep 1
	# Get IOMMU groups
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
	sleep 1
}

function mkscripts_exec() {
	sudo -u $(logname) chmod +x ${SCRIPTS_DIR}/windows_virsh.sh
	sudo -u $(logname) chmod +x ${SCRIPTS_DIR}/macos_virsh.sh
}

##***************************************************************************************************************************
## Configuration and image creation.

function vm_choice() {
	echo " Choose VM Type:"
	echo "	1) Custom OS (VGA passthrough)"
	echo "	2) Custom OS (VirGL - no passthrough)"
	echo "	3) MacOS (VGA passthrough)"
	echo "	4) Exit VM Choice"
	until [[ $VM_CHOICE =~ ^[1-4]$ ]]; do
		read -r -p " VM type choice [1-4]: " VM_CHOICE
	done
	case $VM_CHOICE in
	1)
		unset VM_CHOICE
		create_customvm
		create_virsh
		startupsc_custom
		download_virtio
		unset IMGVMSET ISOVMSET cstname cstvhdname cstvhdsize isoname
		echo "Virtual Machine Created."
		;;
	2)
		unset VM_CHOICE
		create_customvm
		create_virgl
		shortcut_virgl
		unset IMGVMSET ISOVMSET cstname cstvhdname cstvhdsize isoname
		echo "Virtual Machine Created."
		;;
	3)
		unset VM_CHOICE
		create_macos
		startupsc_macos
		echo "Virtual Machine Created."
		;;
	4)
		unset VM_CHOICE
		;;
	esac
}

function create_customvm() {
	echo "Custom Passthrough VM creation:"
	echo "Before you continue please copy your .iso image into ${IMAGES_DIR}/iso/ directory."
	read -r -p " Choose name for your VM: " cstname
	if [[ "$cstname" =~ ^[a-zA-Z0-9]*$ ]]; then
		read -r -p " Choose name for your VHD (e.g. vhd1): " cstvhdname
		if [[ "$cstvhdname" =~ ^[a-zA-Z0-9]*$ ]]; then
			read -r -p " Choose your VHD size (in GB, numeric only): " cstvhdsize
			if [[ "$cstvhdsize" =~ ^[0-9]*$ ]]; then
				ls -R -1 ${IMAGES_DIR}/iso/
				read -r -p "Type/copy the name of desired iso including extension (.iso): " isoname
				IMGVMSET=''${cstname}'_IMG=$IMAGES/'${cstvhdname}'.qcow2'
				ISOVMSET=''${cstname}'_ISO=$IMAGES/iso/'${isoname}''
				sudo -u $(logname) qemu-img create -f qcow2 ${IMAGES_DIR}/${cstvhdname}.qcow2 ${cstvhdsize}G
				echo "Image created."
				sudo -u $(logname) echo $IMGVMSET >> ${CONFIG_LOC}
				sudo -u $(logname) echo $ISOVMSET >> ${CONFIG_LOC}
			else
				echo "Invalid input, use only numerics."
				create_customvm
			fi
		else
			echo "Ivalid input. No special characters allowed."
			create_customvm
			fi
	else
		echo "Ivalid input. No special characters allowed."
		create_customvm
	fi
	another_os
}

function create_virsh() {
	sudo -u $(logname) cp ${SCRIPTS_DIR}/.vm_bp_pt ${SCRIPTS_DIR}/"${cstname}".sh
	sudo -u $(logname) sed -i -e "s/DUMMY_IMG/${cstname}_IMG/g" ${SCRIPTS_DIR}/"${cstname}".sh
	sudo -u $(logname) sed -i -e "s/DUMMY_ISO/${cstname}_ISO/g" ${SCRIPTS_DIR}/"${cstname}".sh
	sudo -u $(logname) chmod +x ${SCRIPTS_DIR}/${cstname}.sh
}

function create_virgl() {
	sudo -u $(logname) cp ${SCRIPTS_DIR}/.vm_bp_gl ${SCRIPTS_DIR}/${cstname}.sh
	sudo -u $(logname) sed -i -e "s/DUMMY_IMG/${cstname}_IMG/g" ${SCRIPTS_DIR}/"${cstname}".sh
	sudo -u $(logname) sed -i -e "s/DUMMY_ISO/${cstname}_ISO/g" ${SCRIPTS_DIR}/"${cstname}".sh
	sudo -u $(logname) chmod +x ${SCRIPTS_DIR}/${cstname}.sh
}

function create_macos() {
	echo "MacOS VM creation:"
	read -r -p " Choose name for your VHD (e.g. macosX): " macvhdname
	if [[ "$macvhdname" =~ ^[a-zA-Z0-9]*$ ]]; then
		read -r -p " Choose your VHD size (in GB, numeric only): " macvhdsize
		if [[ "$macvhdsize" =~ ^[0-9]*$ ]]; then
			sudo -u $(logname) qemu-img create -f qcow2 ${IMAGES_DIR}/${macvhdname}.qcow2 ${macvhdsize}G
			echo "Image created."
			sudo -u $(logname) sed -i '/^MACOS_IMG=$IMAGES/c\MACOS_IMG=$IMAGES/'${macvhdname}'.qcow2' ${CONFIG_LOC}
		else
			echo "Invalid input, use only numerics."
			create_macos
		fi
	else
		echo "Ivalid input. No special characters allowed."
		create_macos
	fi
	another_os
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

##***************************************************************************************************************************
## Startup Scripts and Shortcuts

function startupsc_custom() {
		echo "Creating script and shortcut..."
		sleep 1
		echo "sudo chvt 3
wait
cd ${SCRIPTS_DIR} && sudo nohup ./${cstname}.sh > /tmp/nohup.log 2>&1" > /usr/local/bin/${cstname}-vm
		chmod +x /usr/local/bin/${cstname}-vm
		sudo -u $(logname) mkdir -p /home/$(logname)/.local/share/applications/
		sudo -u $(logname) echo "[Desktop Entry]
Name=${cstname} VM
Exec=/usr/local/bin/${cstname}-vm
Icon=${ICONS_DIR}/television.svg
Type=Application" > /home/$(logname)/.local/share/applications/${cstname}.desktop
	echo -e "\033[1;36mCreated ${cstname} VM Shortcut, you can run the vm by typing ${cstname}-vm in terminal or choosing from applications menu.\033[0m"
}

function startupsc_macos() {
		echo "Creating script and shortcut..."
		sleep 1
		echo "sudo chvt 3
wait
cd ${SCRIPTS_DIR} && sudo nohup ./macos_virsh.sh > /tmp/nohup.log 2>&1" > /usr/local/bin/macos-vm
		chmod +x /usr/local/bin/macos-vm
		sudo -u $(logname) mkdir -p /home/$(logname)/.local/share/applications/
		sudo -u $(logname) echo "[Desktop Entry]
Name=MacOS VM
Exec=/usr/local/bin/macos-vm
Icon=${ICONS_DIR}/154870.svg
Type=Application" > /home/$(logname)/.local/share/applications/MacOS-VM.desktop
}

## VirGL

function shortcut_virgl() {
	read -r -p " Do you want to create GNU/Linux VirGL shortcut? [Y/n] (default: Yes) " -e -i y askvrglshort
	case $askvrglshort in
	    	[yY][eE][sS]|[yY])
	    	sudo -u $(logname) mkdir -p /home/$(logname)/.local/share/applications/
		sudo -u $(logname) echo "[Desktop Entry]
Name=Linux VirGL VM
Exec=${SCRIPTS_DIR}/${cstname}.sh
Icon=${ICONS_DIR}/television.svg
Type=Application" > /home/$(logname)/.local/share/applications/${cstname}.desktop
		unset askvrglshort
		;;
	[nN][oO]|[nN])
		unset askvrglshort
		;;
	*)
		echo "Invalid input..."
		unset askvrglshort
		shortcut_virgl
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
HPG="$((RAMFF / 2 * 1050))"
## Get GPU kernel module information.
GPU="$(lspci -nnk | grep -i vga -A3 | grep 'in use' | cut -d ':' -f2 | cut -d ' ' -f2)"

function autologintty3() {
	if [ -f /etc/systemd/system/getty@tty3.service.d/override.conf ] > /dev/null 2>&1; then
		echo "TTY3 autologin already enabled."
	else
		echo -e "\033[1;36mNOTE: Setting up autologin for tty3, otherwise VMs will NOT work when SIngle GPU Passthrough is used.\033[0m"
		sleep 1
		mkdir -p /etc/systemd/system/getty@tty3.service.d/
		echo "[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin" $(logname) '--noclear %I $TERM' > /etc/systemd/system/getty@tty3.service.d/override.conf
	fi
}

function reminder() {
	echo "Everything is Done."
	echo -e "\033[1;31mIMPORTANT NOTE: You have to set up ISO image paths manually in config file (scripts folder), otherwise VMs will NOT work.\033[0m"
	echo -e "\033[1;31mIMPORTANT NOTE: You have to set up keyboard and mouse manually for optimal performance for passthrough, otherwise they will NOT work.\033[0m"
	echo -e "\033[1;36mRead relevant information on YuriAlek's page at https://gitlab.com/YuriAlek/vfio , or in Hardware configurations directory.\033[0m"
}

function remindergl() {
	echo "Everything is Done."
	echo -e "\033[1;31mIMPORTANT NOTE: You have to set up OS ISO image paths manually in config file (scripts folder), otherwise VMs will NOT work.\033[0m"
}

function remindernopkgm() {
	echo "Everything is Done."
	echo -e "\033[1;31mWARNING: You must install packages equivalent to Arch \"qemu ovmf libvirt virt-manager virglrenderer curl\" packages.\033[0m"
	echo -e "\033[1;31mWARNING: You must add your user to kvm and libvirt groups on your distribution.\033[0m"
	echo -e "\033[1;31mWARNING: You must enable eraly KMS and iommu for your GPU/system in distribution boot manager.\033[0m"
	echo -e "\033[1;31mIMPORTANT NOTE: You have to set up ISO image paths manually in config file (scripts folder), otherwise VMs will NOT work.\033[0m"
	echo -e "\033[1;31mIMPORTANT NOTE: You have to set up keyboard and mouse manually for optimal performance for passthrough, otherwise they will NOT work.\033[0m"
	echo -e "\033[1;36mRead relevant information on YuriAlek's page at https://gitlab.com/YuriAlek/vfio , or in Hardware configurations directory.\033[0m"
}

function chk_create() {
	touch ${SCRIPTS_DIR}/.frchk
}

##***************************************************************************************************************************

first_run
chk_create

unset LC_ALL

exit 0
