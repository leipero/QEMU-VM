#!/bin/bash

LC_ALL=C

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd )"
SCRIPTS_DIR="$( cd .. && cd scripts && pwd )"
CONFIG_LOC="${SCRIPTS_DIR}"/config

echo "Create image and populate paths."

function vhd_create() {
	echo -e "\033[1;31mWARNING: This will overwrite already existing image if given the same name, choose different name of already existing VHD files if you want to keep the old one.\033[0m"
	echo "######## FILES AND DIRECTORIES:"
	ls -1
	read -r -p "Choose name for your VHD (e.g. vhd1): " vhdname
	if [[ "$vhdname" =~ ^[a-zA-Z0-9]*$ ]]; then
		read -r -p "Choose your VHD size (in GB, numeric only): " vhdsize
		if [[ "$vhdsize" =~ ^[0-9]*$ ]]; then
			qemu-img create -f qcow2 ${SCRIPT_DIR}/${vhdname}.qcow2 ${vhdsize}G
			echo "Image created."
			vhd_populate
		else
			echo "Invalid input, use only numerics."
			vhd_create
		fi
	else
		echo "Ivalid input. No special characters allowed."
		vhd_create
	fi
}

function vhd_populate() {
	read -r -p " Do you want to populate config file with created image? [Y/n] (default: Yes) " -e -i y askvhdpop
	case $askvhdpop in
	    	[yY][eE][sS]|[yY])
	    	unset askvhdpop
		pop_choice
		;;
	[nN][oO]|[nN])
		unset askvhdpop
		;;
	*)
		echo "Invalid input..."
		unset askvhdpop
		vhd_populate
		;;
	esac
}

function pop_choice() {
	echo -e "\033[1;31mWARNING: This will overwrite already existing paths for chosen VM. If you want to use new VM when there is already existing VM for given OS, choose Other OS in order to create new entry.\033[0m"
	echo " Choose VM for populating config file with created image:"
	echo "	1) Windows"
	echo "	2) GNU/Linux"
	echo "	3) Android x86"
	echo "	4) MacOS"
	echo "	5) Custom OS"
	echo "	6) Do not populate the config file."
	until [[ $POP_CHOICE =~ ^[1-5]$ ]]; do
		read -r -p " VM choice [1-5]: " POP_CHOICE
	done
	case $POP_CHOICE in
	1)
		sed -i '/^WINDOWS_IMG=$IMAGES/c\WINDOWS_IMG=$IMAGES/'${vhdname}'.qcow2' ${CONFIG_LOC}
		ISOVMSET1='^WINDOWS_ISO=$IMAGES/iso'
		ISOVMSET2='WINDOWS_ISO=$IMAGES/iso'
		iso_populate
		unset POP_CHOICE
		;;
	2)
		sed -i '/^LINUX_IMG=$IMAGES/c\LINUX_IMG=$IMAGES/'${vhdname}'.qcow2' ${CONFIG_LOC}
		ISOVMSET1='^LINUX_ISO=$IMAGES/iso'
		ISOVMSET2='LINUX_ISO=$IMAGES/iso'
		iso_populate
		unset POP_CHOICE
		;;
	3)
		sed -i '/^ANDROID_IMG=$IMAGES/c\ANDROID_IMG=$IMAGES/'${vhdname}'.qcow2' ${CONFIG_LOC}
		ISOVMSET1='^ANDROID_ISO=$IMAGES/iso'
		ISOVMSET2='ANDROID_ISO=$IMAGES/iso'
		iso_populate
		unset POP_CHOICE
		;;
	4)
		sed -i '/^MACOS_IMG=$IMAGES/c\MACOS_IMG=$IMAGES/'${vhdname}'.qcow2' ${CONFIG_LOC}
		ISOVMSET1='^MACOS_ISO=$IMAGES/iso'
		ISOVMSET2='MACOS_ISO=$IMAGES/iso'
		iso_populate
		unset POP_CHOICE
		;;
	5)
		custom_os
		unset POP_CHOICE
		;;
	6)
		unset POP_CHOICE
		;;
	esac
}

function iso_populate() {
	read -r -p " Do you want to populate config file with iso image? [Y/n] (default: Yes) " -e -i y askisopop
	case $askisopop in
	    	[yY][eE][sS]|[yY])
		echo " Choose iso image for created image VM:"
		ls -R -1 iso/
		read -r -p " Type/copy the name of desired iso including extension (.iso): " isoname
		sed -i '/'${ISOVMSET1}'/c\'${ISOVMSET2}'/'${isoname}'' ${CONFIG_LOC}
		unset ISOVMSET1 ISOVMSET2 isoname
		echo "Config file populated."	    	
	    	unset askisopop
	    	
		;;
	[nN][oO]|[nN])
		unset askisopop
		;;
	*)
		echo "Invalid input..."
		unset askisopop
		iso_populate
		;;
	esac
}

function custom_os() {
	echo "This will create new VM based on GNU/Linux VirGL blueprint, to use it for passthrough you have to edit machine manually."
	read -r -p " Choose name for your new VM: " cosname
	if [[ "$cosname" =~ ^[a-zA-Z0-9]*$ ]]; then
		ls -R -1 iso/
		read -r -p "Type/copy the name of desired iso including extension (.iso): " isoname
		IMGVMSET=''${cosname}'_IMG=$IMAGES/'${vhdname}'.qcow2'
		ISOVMSET=''${cosname}'_ISO=$IMAGES/iso/'${isoname}''
		echo $IMGVMSET >> ${CONFIG_LOC}
		echo $ISOVMSET >> ${CONFIG_LOC}
		cp ${SCRIPTS_DIR}/.vm_bp ${SCRIPTS_DIR}/"${cosname}".sh
		chmod +x ${SCRIPTS_DIR}/"${cosname}".sh
		sed -i -e "s/DUMMY_IMG/${cosname}_IMG/g" ${SCRIPTS_DIR}/"${cosname}".sh
		sed -i -e "s/DUMMY_ISO/${cosname}_ISO/g" ${SCRIPTS_DIR}/"${cosname}".sh
		echo 'Virtual Machine "'${cosname}'" created.'
		unset IMGVMSET ISOVMSET cosname
	else
		echo "Ivalid input. No special characters allowed."
		unset cosname
		custom_os
	fi		
}

function create_new_image() {
	read -r -p " Do you want to create new image? [Y/n] (Default: No) " -e -i n askni
	case $askni in
	    	[yY][eE][sS]|[yY])
	    	unset askni
		vhd_create
		;;
	[nN][oO]|[nN])
		unset askni
		exit 0
		;;
	*)
		echo "Invalid input..."
		unset askni
		create_new_image
		;;
	esac
}

vhd_create
create_new_image

unset LC_ALL

exit 0
