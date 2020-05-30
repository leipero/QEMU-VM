CFDIRG="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMGDIR="$CFDIRG/images"

## Virtual drive mount point locations
VHD_MOUNT_POINT=/home/$(logname)/VHD

function vhdcontrol() {
	echo "VHD control script, mount/unmount partitions."
	echo "	1) Mount VHD."
	echo "	2) Unmount VHD."
	echo "	3) Exit."
	until [[ ${OPTSLC} =~ ^[1-3]$ ]]; do
		read -r -p " Choose [1-3]: " OPTSLC
	done
	case ${OPTSLC} in
	1)
		vhdmount
		unset OPTSLC
		vhdcontrol
		;;
	2)
		vhdunmount
		unset OPTSLC
		vhdcontrol
		;;
	3)
		exit 0
		;;
	esac
}

function vhdmount() {
	if [ -d ${VHD_MOUNT_POINT} ]; then
		echo "Can't mount VHD if another is already mounted."; else
	mkdir -p ${VHD_MOUNT_POINT}
	sudo modprobe nbd max_part=8
	wait
	ls -1 -I firmware -I macos -I iso $IMGDIR
	read -r -p "Type/copy the name of the VHD to mount (inc. extension):" vhdmnt
	sudo qemu-nbd --nocache --aio=threads --connect=/dev/nbd0 ${IMGDIR}/${vhdmnt}
	wait
	sudo fdisk /dev/nbd0 -l
	read -r -p "Choose partition to mount (numeric only, following nbd0p):" vhdmntprt
	if [[ "$vhdmntprt" =~ ^[0-9]*$ ]]; then
		sudo mount /dev/nbd0p${vhdmntprt} ${VHD_MOUNT_POINT}
	else
		echo "invalid input"
		vhdmount
	fi
	fi
}

function vhdunmount() {
	if [ -d ${VHD_MOUNT_POINT} ]; then
	sudo umount $VHD_MOUNT_POINT
	wait
	sudo qemu-nbd --disconnect /dev/nbd0
	wait
	sudo modprobe -r nbd
	wait
	rm -d $VHD_MOUNT_POINT
	else
	echo -e "VHD is not mounted."
	fi
}

vhdcontrol
