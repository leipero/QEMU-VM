#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd )"

function vhd_create() {
	echo "GNU/Linux VM creation:"
	read -r -p "Choose name for your VHD (e.g. vhd1): " vhdname
	if [[ "$vhdname" =~ ^[a-zA-Z0-9]*$ ]]; then
		read -r -p "Choose your VHD size (in GB, numeric only): " vhdsize
		if [[ "$vhdsize" =~ ^[0-9]*$ ]]; then
			qemu-img create -f qcow2 ${SCRIPT_DIR}/${vhdname}.qcow2 ${vhdsize}G
			echo "Image created."
		else
			echo "Invalid input, use only numerics."
			vhd_create
		fi
	else
		echo "Ivalid input. No special characters allowed."
		vhd_create
	fi
}

vhd_create
