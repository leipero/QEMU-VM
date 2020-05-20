#!/bin/bash

export LC_ALL=C

## Check if script was executed with the root privileges.
[[ "$EUID" -ne 0 ]] && echo "Please run with root privileges." && sleep 5 && exit 1

function welcomescript() {
	clear
	echo "----------------------------------------------------------------"
	echo "- Welcome to the Single GPU Passthrought configuration script. -"
	echo "-  Note: This script attempts to do as little assumptions as   -"
	echo "-  possible, but some assumptions were made, introducig small  -"
	echo "-  chance that script may not work properly. Be advised.       -"
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
		apt_install_dep
		apt_addgroups
		earlykms_enable_apt
		bootloader_setup
	elif command -v yum > /dev/null 2>&1; then
		echo "yum"
	elif command -v dnf > /dev/null 2>&1; then
		echo "dnf"
	elif command -v zypper > /dev/null 2>&1; then
		echo "zypper"
	elif command -v pacman > /dev/null 2>&1; then
		populate_base_config
		pacman_install_dep
		pacman_addgroups
		earlykms_enable_pacman
		bootloader_setup
	else
		echo "No compatible package manager found. Exiting..."
		exit 1
	fi
}

##***************************************************************************************************************************
## Install dependencies.

function apt_install_dep() {
	echo "Installing dependencies, please wait..."
	apt-get install -y curl > /dev/null
	apt-get install -y qemu-kvm > /dev/null
	echo "QEMU/KVM Installed"
	apt-get install -y libvirt-daemon-system > /dev/null
	apt-get install -y libvirt-clients > /dev/null
	echo "libvirt Installed"
	apt-get install -y bridge-utils > /dev/null
	echo "bridge-utils Installed"
	apt-get install -y libvirglrenderer0 > /dev/null 2>&1
	apt-get install -y libvirglrenderer1 > /dev/null 2>&1
	echo "libvirglrenderer Installed"
	apt-get install -y gnome-terminal > /dev/null
	echo -e "\033[1;36mDependencies are installed.\033[0m"
}

function pacman_install_dep() {
	if pacman -Q qemu ovmf libvirt virt-manager virglrenderer curl gnome-terminal > /dev/null 2>&1; then
		echo -e "\033[1;36mDependencies are already installed.\033[0m"
	else
		echo "Installing dependencies, please wait..."
		pacman -S --noconfirm qemu ovmf libvirt virt-manager virglrenderer curl gnome-terminal > /dev/null
		echo "Dependencies are installed."
	fi
}

##***************************************************************************************************************************
## Add user to groups.

function apt_addgroups() {
	if groups $(logname) | grep kvm | grep libvirt > /dev/null 2>&1; then
		echo -e "\033[1;36mUser is already in groups.\033[0m"
	else
		adduser $(logname) libvirt
		adduser $(logname) kvm
		echo "User is now a member of the required groups."
	fi
}

function pacman_addgroups() {
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

function earlykms_enable_apt() {
	if grep -wq "${GPU1}" /etc/initramfs-tools/modules > /dev/null 2>&1; then
		echo -e "\033[1;36mEarly KMS is already enabled.\033[0m"
	else
		echo "Enabling early KMS..."
		echo "${GPU1}" >> /etc/initramfs-tools/modules
		update-initramfs -u
	fi
}

function earlykms_enable_pacman() {
	if grep -wq "MODULES=(${GPU1}.*" /etc/mkinitcpio.conf > /dev/null 2>&1; then
		echo -e "\033[1;36mEarly KMS is already enabled.\033[0m"
	else
		echo "Enabling early KMS..."
		sed -i -e "s/^MODULES=(/MODULES=(${GPU1} /g" /etc/mkinitcpio.conf
		for lnxkrnl in /etc/mkinitcpio.d/*.preset; do mkinitcpio -p "$lnxkrnl";  done
	fi
}

##***************************************************************************************************************************
## Enable IOMMU.

function bootloader_setup() {
	iommu_check
	cpu_iommu_set
	grub_find
	bootmgrfound
	iommu_populate
	ask_settings
	checkdm_pacman_apt
	mkscripts_exec
	autologintty3
	passthroughshortcuts
	reminder
}

function iommu_check() {
	if compgen -G "/sys/kernel/iommu_groups/*/devices/*" > /dev/null 2>&1; then
		echo "\033[1;36mAMD's IOMMU / Intel's VT-D is enabled in the BIOS/UEFI."
	else
		echo -e "\033[1;31mAMD's IOMMU / Intel's VT-D is not enabled in the BIOS/UEFI. Reboot and enable it.\033[0m"
		echo -e "\033[1;36mNOTE: You can still use VMs with VirGL paravirtualization offering excellent performance.\033[0m"
		sleep 1
		ask_settings
		mkscripts_exec
		remindergl
		exit 1
	fi
}

function cpu_iommu_set() {
	if lscpu | grep -i "model name" | grep -iq amd ; then
		IOMMU_CPU=amd
	else
		IOMMU_CPU=intel
	fi
}

function grub_find() {
	echo "Searching for GRUB..."
	GPAPT=$(find / -path  \*/etc/default/grub > /dev/null 2>&1)
	if [[ -n $GPAPT ]]; then
		grub_enable_iommu
	else
		echo "GRUB not found."
		systemdb_find
	fi
}

function systemdb_find() {
	echo "Searching for Systemd-boot"
	SDBP=$(find / -path  \*/loader/entries/*.conf > /dev/null 2>&1)
	if [[ -n $SDBP ]]; then
		systemdb_enable_iommu
	else
		echo "Systemd-boot not found."
	fi
}

function grub_enable_iommu() {
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

function systemdb_enable_iommu() {
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

function checkdm_pacman_apt() {
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
	sudo -u $(logname) sed -i '/^IMAGES=/c\IMAGES='${SCRIPTS_DIR}'/images' ${CONFIG_LOC}
	# Set number of cores in the config file
	sudo -u $(logname) sed -i '/^CORES=/c\CORES='${CORES_NUM_GET}'' ${CONFIG_LOC}
	sudo -u $(logname) sed -i '/^MACOS_CORES=/c\MACOS_CORES='${CORES_NUM_GET}'' ${CONFIG_LOC}
}

function iommu_populate() {
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

function populatedm_virshscripts() {
	sudo -u $(logname) sed -i '/^systemctl stop/c\systemctl stop '${DMNGR}'' ${SCRIPTS_DIR}/windows_virsh.sh
	sudo -u $(logname) sed -i '/^systemctl start/c\systemctl start '${DMNGR}'' ${SCRIPTS_DIR}/windows_virsh.sh
	sudo -u $(logname) sed -i '/^systemctl stop/c\systemctl stop '${DMNGR}'' ${SCRIPTS_DIR}/linux_virsh.sh
	sudo -u $(logname) sed -i '/^systemctl start/c\systemctl start '${DMNGR}'' ${SCRIPTS_DIR}/linux_virsh.sh
	sudo -u $(logname) sed -i '/^systemctl stop/c\systemctl stop '${DMNGR}'' ${SCRIPTS_DIR}/macos_virsh.sh
	sudo -u $(logname) sed -i '/^systemctl start/c\systemctl start '${DMNGR}'' ${SCRIPTS_DIR}/macos_virsh.sh
	sudo -u $(logname) sed -i '/^systemctl stop/c\systemctl stop '${DMNGR}'' ${SCRIPTS_DIR}/vandroidx86_virsh.sh
	sudo -u $(logname) sed -i '/^systemctl start/c\systemctl start '${DMNGR}'' ${SCRIPTS_DIR}/vandroidx86_virsh.sh
}

function mkscripts_exec() {
	sudo -u $(logname) chmod +x ${SCRIPTS_DIR}/linux_virgl.sh
	sudo -u $(logname) chmod +x ${SCRIPTS_DIR}/vandroidx86_virgl.sh
	sudo -u $(logname) chmod +x ${SCRIPTS_DIR}/linux_virsh.sh
	sudo -u $(logname) chmod +x ${SCRIPTS_DIR}/vandroidx86_virsh.sh > /dev/null 2>&1
	sudo -u $(logname) chmod +x ${SCRIPTS_DIR}/windows_virsh.sh
	sudo -u $(logname) chmod +x ${SCRIPTS_DIR}/macos_virsh.sh
	sudo -u $(logname) chmod +x ${IMAGES_DIR}/avmic_tool.sh
	sudo -u $(logname) chmod +x ${MNTSCR_DIR}/linux_mnt.sh
	sudo -u $(logname) chmod +x ${MNTSCR_DIR}/linux_unmnt.sh
	sudo -u $(logname) chmod +x ${MNTSCR_DIR}/windows_mnt.sh
	sudo -u $(logname) chmod +x ${MNTSCR_DIR}/windows_unmnt.sh
}

##***************************************************************************************************************************
## Automatic configuration and image creation.

function ask_settings() {
	echo "Auto Configuration for VMs."
	echo "  This creates qcow2 virtual image and populates paths,"
	echo "  you can choose name and other options."
	read -r -p " Do you want to start auto configuration? [Y/n] (default: Yes) " -e -i y asksettings
	case $asksettings in
	    	[yY][eE][sS]|[yY])
	    	unset asksettings
		vm_choice
		;;
	[nN][oO]|[nN])
		unset asksettings
		;;
	*)
		echo "Invalid input..."
		unset asksettings
		ask_settings
		;;
	esac
}

function vm_choice() {
	echo " Choose VM Type:"
	echo "	1) Windows"
	echo "	2) GNU/Linux"
	echo "	3) Android x86"
	echo "	4) MacOS"
	echo "	5) Exit VM Choice"
	until [[ $VM_CHOICE =~ ^[1-5]$ ]]; do
		read -r -p " VM type choice [1-5]: " VM_CHOICE
	done
	case $VM_CHOICE in
	1)
		unset VM_CHOICE
		windows_create
		;;
	2)
		unset VM_CHOICE
		linux_create
		startupvrglshortcut_linux
		;;
	3)
		unset VM_CHOICE
		androidx86_create
		startupvrglshortcut_androidx86
		;;
	4)
		unset VM_CHOICE
		macos_create
		;;
	5)
		unset VM_CHOICE
		ask_settings
		;;
	esac
}

function windows_create() {
	echo "Windows VM creation:"
	read -r -p " Choose name for your VHD (e.g. windows10): " winvhdname
	if [[ "$winvhdname" =~ ^[a-zA-Z0-9]*$ ]]; then
		read -r -p "Choose your VHD size (in GB, numeric only): " winvhdsize
		if [[ "$winvhdsize" =~ ^[0-9]*$ ]]; then
			sudo -u $(logname) qemu-img create -f qcow2 ${IMAGES_DIR}/${winvhdname}.qcow2 ${winvhdsize}G
			echo "Image created."
			sudo -u $(logname) sed -i '/^WINDOWS_IMG=$IMAGES/c\WINDOWS_IMG=$IMAGES/'${winvhdname}'.qcow2' ${CONFIG_LOC}
		else
			echo "Invalid input, use only numerics."
			windows_create
		fi
	else
		echo "Ivalid input. No special characters allowed."
		windows_create
	fi
	download_virtio
	another_os
}

function linux_create() {
	echo "GNU/Linux VM creation:"
	read -r -p " Choose name for your VHD (e.g. rhe8): " linvhdname
	if [[ "$linvhdname" =~ ^[a-zA-Z0-9]*$ ]]; then
		read -r -p " Choose your VHD size (in GB, numeric only): " linvhdsize
		if [[ "$linvhdsize" =~ ^[0-9]*$ ]]; then
			sudo -u $(logname) qemu-img create -f qcow2 ${IMAGES_DIR}/${linvhdname}.qcow2 ${linvhdsize}G
			echo "Image created."
			sudo -u $(logname) sed -i '/^LINUX_IMG=$IMAGES/c\LINUX_IMG=$IMAGES/'${linvhdname}'.qcow2' ${CONFIG_LOC}
		else
			echo "Invalid input, use only numerics."
			linux_create
		fi
	else
		echo "Ivalid input. No special characters allowed."
		linux_create
	fi
	another_os
}

function androidx86_create() {
	echo "Android x86 VM creation:"
	read -r -p " Choose name for your VHD (e.g. androidx86): " andvhdname
	if [[ "$andvhdname" =~ ^[a-zA-Z0-9]*$ ]]; then
		read -r -p " Choose your VHD size (in GB, numeric only): " andvhdsize
		if [[ "$andvhdsize" =~ ^[0-9]*$ ]]; then
			sudo -u $(logname) qemu-img create -f qcow2 ${IMAGES_DIR}/${andvhdname}.qcow2 ${andvhdsize}G
			echo "Image created."
			sudo -u $(logname) sed -i '/^ANDROID_IMG=$IMAGES/c\ANDROID_IMG=$IMAGES/'${andvhdname}'.qcow2' ${CONFIG_LOC}
		else
			echo "Invalid input, use only numerics."
			androidx86_create
		fi
	else
		echo "Ivalid input. No special characters allowed."
		androidx86_create
	fi
	another_os
}

function macos_create() {
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
			macos_create
		fi
	else
		echo "Ivalid input. No special characters allowed."
		macos_create
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
		sudo -u $(logname) curl https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.173-9/virtio-win-0.1.173.iso -o virtio-win.iso
		sudo -u $(logname) mv virtio-win.iso ${IMAGES_DIR}/
		unset askvirtio
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

function passthroughshortcuts() {
	echo " This option is necessary for successful Single GPU Passthrough, create shortcuts for OSs you have created VMs for."
	echo " Create startup scripts and shortcuts for:"
	echo "	1) Windows"
	echo "	2) GNU/Linux"
	echo "	3) Android x86 (not applicable yet)"
	echo "	4) MacOS (untested passthrough)"
	echo "	5) Exit selection."
	until [[ $VM_CHOICE =~ ^[1-5]$ ]]; do
		read -r -p " Create startup script and shortcut for [1-5]: " VM_SHS_CHOICE
	done
	case $VM_CHOICE in
	1)
		unset VM_SHS_CHOICE
		startupscriptcreate_windows
		;;
	2)
		unset VM_SHS_CHOICE
		startupscriptcreate_linux
		;;
	3)
		unset VM_SHS_CHOICE
		startupscriptcreate_androidx86
		;;
	4)
		unset VM_SHS_CHOICE
		startupscriptcreate_macos
		;;
	5)
		unset VM_SHS_CHOICE
		passthroughshortcuts
		;;
	esac
}

function startupscriptcreate_windows() {
		echo "Creating script and shortcut..."
		sleep 1
		echo "sudo chvt 3
wait
cd ${SCRIPTS_DIR} && sudo nohup ./windows_virsh.sh > /tmp/nohup.log 2>&1" > /usr/local/bin/windows-vm
		chmod +x /usr/local/bin/windows-vm
		sudo -u $(logname) echo "[Desktop Entry]
Name=Windows VM
Exec=/usr/local/bin/windows-vm
Icon=${ICONS_DIR}/154872.svg
Type=Application" > /home/$(logname)/.local/share/applications/Windows-VM.desktop
}

function startupscriptcreate_linux() {
		echo "Creating script and shortcut..."
		sleep 1
		echo "sudo chvt 3
wait
cd ${SCRIPTS_DIR} && sudo nohup ./linux_virsh.sh > /tmp/nohup.log 2>&1" > /usr/local/bin/linux-vm
		chmod +x /usr/local/bin/linux-vm
		sudo -u $(logname) echo "[Desktop Entry]
Name=Linux VM
Exec=/usr/local/bin/linux-vm
Icon=${ICONS_DIR}/154873.svg
Type=Application" > /home/$(logname)/.local/share/applications/Linux-VM.desktop
}

function startupscriptcreate_androidx86() {
		echo "Creating script and shortcut..."
		sleep 1
		echo "sudo chvt 3
wait
cd ${SCRIPTS_DIR} && sudo nohup ./vandroidx86_virsh.sh > /tmp/nohup.log 2>&1" > /usr/local/bin/androidx86-vm
		chmod +x /usr/local/bin/androidx86-vm
		sudo -u $(logname) echo "[Desktop Entry]
Name=Android x86 VM
Exec=/usr/local/bin/androidx86-vm
Icon=${ICONS_DIR}/154871.svg
Type=Application" > /home/$(logname)/.local/share/applications/Androidx86-VM.desktop
}

function startupscriptcreate_macos() {
		echo "Creating script and shortcut..."
		sleep 1
		echo "sudo chvt 3
wait
cd ${SCRIPTS_DIR} && sudo nohup ./macos_virsh.sh > /tmp/nohup.log 2>&1" > /usr/local/bin/macos-vm
		chmod +x /usr/local/bin/macos-vm
		sudo -u $(logname) echo "[Desktop Entry]
Name=MacOS VM
Exec=/usr/local/bin/macos-vm
Icon=${ICONS_DIR}/154870.svg
Type=Application" > /home/$(logname)/.local/share/applications/MacOS-VM.desktop
}

## VirGL

function startupvrglshortcut_linux() {
	read -r -p " Do you want to create GNU/Linux VirGL shortcut? [Y/n] " askvrglshortl
	case $askvrglshortl in
	    	[yY][eE][sS]|[yY])
		sudo -u $(logname) echo "[Desktop Entry]
Name=Linux VirGL VM
Exec=${SCRIPTS_DIR}/linux_virgl.sh
Icon=${ICONS_DIR}/154873.svg
Type=Application" > /home/$(logname)/.local/share/applications/linux_virgl_vm.desktop
		unset askvrglshortl
		;;
	[nN][oO]|[nN])
		unset askvrglshortl
		;;
	*)
		echo "Invalid input..."
		unset askvrglshortl
		startupvrglshortcut_linux
		;;
	esac	
}

function startupvrglshortcut_androidx86() {
	read -r -p " Do you want to create Android x86 VirGL shortcut? [Y/n] " askvrglshorta
	case $askvrglshorta in
	    	[yY][eE][sS]|[yY])
		sudo -u $(logname) echo "[Desktop Entry]
Name=Android x86 VirGL VM
Exec=${SCRIPTS_DIR}/vandroidx86_virgl.sh
Icon=${ICONS_DIR}/154871.svg
Type=Application" > /home/$(logname)/.local/share/applications/androidx86_virgl_vm.desktop
		unset askvrglshorta
		;;
	[nN][oO]|[nN])
		unset askvrglshorta
		;;
	*)
		echo "Invalid input..."
		unset askvrglshorta
		startupvrglshortcut_androidx86
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
MNTSCR_DIR="${SCRIPT_DIR}/vhd_mnt"
CONFIG_LOC="${SCRIPTS_DIR}/config"
## Get CPU information.
CORES_NUM_GET="$(nproc)"
## Get GPU kernel module information.
GPU1=$(lspci -nnk | grep -i vga -A3 | grep 'in use' | cut -d ':' -f2 | cut -d ' ' -f2)

function autologintty3() {
	echo -e "\033[1;31mNOTE: Setting up autologin for tty3, otherwise VMs will NOT work when SIngle GPU Passthrough is used.\033[0m"
	sleep 1
	mkdir -p /etc/systemd/system/getty@tty3.service.d/
	echo "[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin" $(logname) '--noclear %I $TERM' > /etc/systemd/system/getty@tty3.service.d/override.conf
}

function reminder() {
	echo "Everything is Done."
	echo -e "\033[1;31mIMPORTANT NOTE: You have to set up RAM size and OS ISO image paths manually in config file (scripts folder), otherwise VMs will NOT work.\033[0m"
	echo -e "\033[1;31mIMPORTANT NOTE: You have to set up keyboard and mouse manually for optimal performance for passthrough, otherwise they will NOT work.\033[0m"
	echo "Read relevant information on YuriAlek's page at https://gitlab.com/YuriAlek/vfio , or in Hardware configurations directory."
}

function remindergl() {
	echo "Everything is Done."
	echo -e "\033[1;31mIMPORTANT NOTE: You have to set up RAM size and OS ISO image paths manually in config file (scripts folder), otherwise VMs will NOT work.\033[0m"
}

welcomescript

unset LC_ALL

exit 0
