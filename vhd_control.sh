CFDIRG="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMAGES_DIR="${CFDIRG}/images"
MAINMP_DIR="/home/$(logname)/VHD"

## Check if script was executed with the root privileges.
[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"

function vhdcontrol() {
	OPTSLC=$(dialog  --backtitle "VHD Control Script." \
		--title     "Option Choice." \
		--nocancel \
		--menu "Select VM Type:" 10 40 3 \
		"1. Mount VHD" "" \
		"2. Unmount VHD" "" \
		"3. Exit" "" 3>&1 1>&2 2>&3)
	case ${OPTSLC} in
	"1. Mount VHD")
		vhdcheck
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

function vhdcheck() {
	vhdmpmname=$(dialog --backtitle "VHD Control Script." \
	--title     "VHD mount point name." \
	--inputbox "Type in VHD mount point name (no special characters):" 7 60 --output-fd 1)
	if [ -z "${vhdmpmname//[a-zA-Z0-9_]}" ] && [ -n "$vhdmpmname" ] && [ -n  "${vhdmpmname//[0-9]}" ]; then
		VHD_MP="${MAINMP_DIR}/${vhdmpmname}"
		modprobe nbd max_part=8
		wait
		vhdselect
	else
		echo "Invalid imput, no special characters allowed." | dialog --backtitle "VHD Control Script" --programbox "WARNING." 7 50
	fi
}

function vhdselect() {
	echo "Use SPACE to select and ARROW keys to navigate!" | dialog --backtitle "VHD Control Script" --programbox "WARNING." 7 50
	vhdname=$(dialog  --backtitle "VHD Control Script." \
		--title "VHD Selection." --stdout \
		--nocancel --title "Select VHD file:" --fselect ${IMAGES_DIR}/ 20 60)
	if [ -f "$vhdname" ] && [ -n "$vhdname" ]; then
		qemu-nbd --nocache --aio=native --connect=/dev/nbd0 ${vhdname}
		wait
		part_select
	else
		echo "\"${vhdname}\" is not a file." | dialog --backtitle "VHD Control Script." --programbox "WARNING." 7 50
		unset vhdname
		vhdselect
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
		mp=$(fdisk /dev/nbd0 -l | grep "nbd0p1" | head -c 11)
		vhdmount
		;;
	"2.")
		mp=$(fdisk /dev/nbd0 -l | grep "nbd0p2" | head -c 11)
		vhdmount
		;;
	"3.")
		mp=$(fdisk /dev/nbd0 -l | grep "nbd0p3" | head -c 11)
		vhdmount
		;;
	"4.")
		mp=$(fdisk /dev/nbd0 -l | grep "nbd0p4" | head -c 11)
		vhdmount
		;;
	"5.")
		mp=$(fdisk /dev/nbd0 -l | grep "nbd0p5" | head -c 11)
		vhdmount
		;;
	"6.")
		mp=$(fdisk /dev/nbd0 -l | grep "nbd0p6" | head -c 11)
		vhdmount
		;;
	"7.")
		mp=$(fdisk /dev/nbd0 -l | grep "nbd0p7" | head -c 11)
		vhdmount
		;;
	"8.")
		mp=$(fdisk /dev/nbd0 -l | grep "nbd0p8" | head -c 11)
		vhdmount
		;;
	esac
}

function vhdmount() {
	if [ -n "$mp" ]; then
		sudo -u $(logname) mkdir -p ${VHD_MP}
		mount ${mp} ${VHD_MP}
		echo "Partition \"$mp\" mounted." | dialog --backtitle "VHD Control Script" --programbox "Mounted." 7 50
		unset mp VHD_MP
	else
		echo "Something went wrong." | dialog --backtitle "VHD Control Script" --programbox "Error." 7 50
		vhdcontrol
	fi
}

function vhdunmount() {
	echo "Use SPACE to select and ARROW keys to navigate!" | dialog --backtitle "VHD Control Script" --programbox "WARNING." 7 50
	VHD_MPU=$(dialog  --backtitle "VHD Control Script." \
		--title "VHD Unmount." --stdout \
		--nocancel --title "Select mounted directory:" --dselect ${MAINMP_DIR}/ 20 60)
	if [ -d "${VHD_MPU}" ]; then
		up=$(lsblk | grep "${VHD_MPU}" | head -c 12 | tail -c 6)
		if [ "$(echo $up | grep "nbd0p")" ]; then
			umount ${VHD_MPU}
			sleep 2
			qemu-nbd --disconnect /dev/nbd0 > /dev/null 2>&1
			sleep 2
			rmmod nbd
			wait
			deletemp
		else
			echo "\"${VHD_MPU}\" not mounted."
		fi
	else
		echo -e "VHD is not mounted." | dialog --backtitle "VHD Control Script" --programbox "VHD Unmount." 7 50
	fi
}

function deletemp() {
	if [ "$(ls -A ${VHD_MPU})" ]; then
		echo "${VHD_MPU} is not Empty!"
	else
		rm -d ${VHD_MPU}
		echo "Partition \"${up}\" unmounted." | dialog --backtitle "VHD Control Script" --programbox "Unmounted." 7 50
		unset up
	fi
}

vhdcontrol
