CFDIRG="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMAGES_DIR="$CFDIRG/images"

## Virtual drive mount point locations
VHD_MOUNT_POINT=/home/$(logname)/VHD

## Check if script was executed with the root privileges.
[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"

function vhdcontrol() {
	OPTSLC=$(dialog  --backtitle "VHD Control Script" \
		--title     "Option Choice." \
		--nocancel \
		--menu "Select VM Type:" 10 40 3 \
		"1. Mount VHD" "" \
		"2. Unmount VHD" "" \
		"3. Exit" "" 3>&1 1>&2 2>&3)
	case ${OPTSLC} in
	"1. Mount VHD")
		vhdmount
		unset OPTSLC
		vhdcontrol
		;;
	"2. Unmount VHD")
		vhdunmount
		unset OPTSLC
		vhdcontrol
		;;
	"3. Exit")
		clear
		exit 0
		;;
	esac
}

function vhdmount() {
	if [ -d ${VHD_MOUNT_POINT} ]; then
		(echo "Can't mount VHD if another is already mounted.") | dialog --backtitle "VHD Control Script" --programbox "WARNING." 7 50 ; else
	(modprobe nbd max_part=8
	wait) 2>&1 | dialog --backtitle "VHD Control Script" --progressbox "Mounting." 7 50
	(echo "Use SPACE to select and ARROW keys to navigate!") | dialog --backtitle "VHD Control Script" --programbox "WARNING." 7 50
	vhdname=$(dialog  --backtitle "VHD Control Script" \
		--title     "VHD Selection." --stdout \
		--nocancel --title "Select VHD file:" --fselect ${IMAGES_DIR}/ 20 60)
	qemu-nbd --nocache --aio=native --connect=/dev/nbd0 ${vhdname}
	wait
	part_select
	if [ -z "${pn//[1-8]}" ] && [ -n "$pn" ]; then
		(sudo -u $(logname) mkdir -p ${VHD_MOUNT_POINT}
		mount /dev/nbd0p${pn} ${VHD_MOUNT_POINT}) | dialog --backtitle "VHD Control Script" --progressbox "Mounting." 7 50
		echo "Partition nbd0p"$pn" mounted." | dialog --backtitle "VHD Control Script" --programbox "Mounted." 7 50
	else
		echo "Something went wrong." | dialog --backtitle "VHD Control Script" --programbox "Error." 7 50
		vhdmount
	fi
	fi
}

function part_select() {
	p1=$(fdisk /dev/nbd0 -l | grep "nbd0p1")
	p2=$(fdisk /dev/nbd0 -l | grep "nbd0p2")
	p3=$(fdisk /dev/nbd0 -l | grep "nbd0p3")
	p4=$(fdisk /dev/nbd0 -l | grep "nbd0p4")
	p5=$(fdisk /dev/nbd0 -l | grep "nbd0p5")
	p6=$(fdisk /dev/nbd0 -l | grep "nbd0p6")
	p7=$(fdisk /dev/nbd0 -l | grep "nbd0p7")
	p8=$(fdisk /dev/nbd0 -l | grep "nbd0p8")
	partchoice=$(dialog  --backtitle "VHD Control Script" \
		--title     "Partition choice." \
		--nocancel \
		--menu "Choose partition to mount:" 15 80 8 \
		"1." "- $p1" \
		"2." "- $p2" \
		"3." "- $p3" \
		"4." "- $p4" \
		"5." "- $p5" \
		"6." "- $p6" \
		"7." "- $p7" \
		"8." "- $p8" 3>&1 1>&2 2>&3)
	case $partchoice in
	"1.")
		pn=$(echo $partchoice | head -c 1)
		;;
	"2.")
		pn=$(echo $partchoice | head -c 1)
		;;
	"3.")
		pn=$(echo $partchoice | head -c 1)
		;;
	"4.")
		pn=$(echo $partchoice | head -c 1)
		;;
	"5.")
		pn=$(echo $partchoice | head -c 1)
		;;
	"6.")
		pn=$(echo $partchoice | head -c 1)
		;;
	"7.")
		pn=$(echo $partchoice | head -c 1)
		;;
	"8.")
		pn=$(echo $partchoice | head -c 1)
		;;
	esac
}

function vhdunmount() {
	if [ -d ${VHD_MOUNT_POINT} ]; then
	(umount $VHD_MOUNT_POINT
	wait
	qemu-nbd --disconnect /dev/nbd0
	wait
	rmmod nbd
	wait
	rm -d $VHD_MOUNT_POINT) | dialog --backtitle "VHD Control Script" --progressbox "Unmounting." 7 50
	echo "Partition unmounted." | dialog --backtitle "VHD Control Script" --programbox "Unmounted." 7 50
	else
	(echo -e "VHD is not mounted.") | dialog --backtitle "VHD Control Script" --programbox "VHD Unmount." 7 50
	fi
}

vhdcontrol
