#!/bin/bash

# Copyright (c) 2011-2017, NVIDIA CORPORATION. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#  * Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#  * Neither the name of NVIDIA CORPORATION nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


#
# This script applies the binaries to the rootfs dir pointed to by
# LDK_ROOTFS_DIR variable.
#

set -e

# show the usages text
function ShowUsage {
    local ScriptName=$1

    echo "Use: $1 [--bsp|-b PATH] [--factory] [--ft_dir|-t] [--root|-r PATH] [--help|-h]"
cat <<EOF
    This script installs tegra binaries
    Options are:
    --bsp|-b PATH
                   bsp location (bsp, readme, installer)
    --factory
                   install base functionality for factory install
    --ft_dir|-t PATH
                   factory target directory
    --root|-r PATH
                   install toolchain to PATH
    --help|-h
                   show this help
EOF
}

function ShowDebug {
    echo "SCRIPT_NAME    : $SCRIPT_NAME"
    echo "LDK_ROOTFS_DIR : $LDK_ROOTFS_DIR"
    echo "BOARD_NAME     : $TARGET_BOARD"
}

function ReplaceText {
	sed -i "s/$2/$3/" $1
	if [ $? -ne 0 ]; then
		echo "Error while editing a file. Exiting !!"
		exit 1
	fi
}
# if the user is not root, there is not point in going forward
THISUSER=`whoami`
if [ "x$THISUSER" != "xroot" ]; then
    echo "This script requires root privilege"
    exit 1
fi

# script name
SCRIPT_NAME=`basename $0`

# empty root and no debug
DEBUG=

# parse the command line first
TGETOPT=`getopt -n "$SCRIPT_NAME" --longoptions help,bsp:,debug,factory,ft_dir:,root: -o b:dhr:b:t: -- "$@"`

if [ $? != 0 ]; then
    echo "Terminating... wrong switch"
    ShowUsage "$SCRIPT_NAME"
    exit 1
fi

eval set -- "$TGETOPT"

while [ $# -gt 0 ]; do
    case "$1" in
	-r|--root) LDK_ROOTFS_DIR="$2"; shift ;;
	-h|--help) ShowUsage "$SCRIPT_NAME"; exit 1 ;;
	-d|--debug) DEBUG="true" ;;
	--factory) FACTORY="true" ;;
	-b|--bsp) BSP_LOCATION_DIR="$2"; shift ;;
	-t|--ft_dir) FACTORY_TARGET_DIR="$2"; shift ;;
	--) shift; break ;;
	-*) echo "Terminating... wrong switch: $@" >&2 ; ShowUsage "$SCRIPT_NAME"; exit 1 ;;
    esac
    shift
done

if [ $# -gt 0 ]; then
    ShowUsage "$SCRIPT_NAME"
    exit 1
fi

# done, now do the work, save the directory
LDK_DIR=$(cd `dirname $0` && pwd)

# use default rootfs dir if none is set
if [ -z "$LDK_ROOTFS_DIR" ] ; then
    LDK_ROOTFS_DIR="${LDK_DIR}/rootfs"
fi

echo "Using rootfs directory of: ${LDK_ROOTFS_DIR}"

if [ ! -d "${LDK_ROOTFS_DIR}" ]; then
    mkdir -p "${LDK_ROOTFS_DIR}" > /dev/null 2>&1
fi

# get the absolute path, for LDK_ROOTFS_DIR.
# otherwise, tar behaviour is unknown in last command sets
TOP=$PWD
cd "$LDK_ROOTFS_DIR"
LDK_ROOTFS_DIR="$PWD"
cd "$TOP"

if [ ! `find "$LDK_ROOTFS_DIR/etc/passwd" -group root -user root` ]; then
	echo "||||||||||||||||||||||| ERROR |||||||||||||||||||||||"
	echo "-----------------------------------------------------"
	echo "1. The root filesystem, provided with this package,"
	echo "   has to be extracted to this directory:"
	echo "   ${LDK_ROOTFS_DIR}"
	echo "-----------------------------------------------------"
	echo "2. The root filesystem, provided with this package,"
	echo "   has to be extracted with 'sudo' to this directory:"
	echo "   ${LDK_ROOTFS_DIR}"
	echo "-----------------------------------------------------"
	echo "Consult the Development Guide for instructions on"
	echo "extracting and flashing your device."
	echo "|||||||||||||||||||||||||||||||||||||||||||||||||||||"
	exit 1
fi

# assumption: this script is part of the BSP
#             so, LDK_DIR/nv_tegra always exist
LDK_NV_TEGRA_DIR="${LDK_DIR}/nv_tegra"
LDK_KERN_DIR="${LDK_DIR}/kernel"
LDK_BOOTLOADER_DIR="${LDK_DIR}/bootloader"

if [ "${FACTORY}" != "true" ] ; then
	echo "Extracting the NVIDIA user space components to ${LDK_ROOTFS_DIR}"
	pushd "${LDK_ROOTFS_DIR}" > /dev/null 2>&1
	tar xpfm ${LDK_NV_TEGRA_DIR}/nvidia_drivers.tbz2

	# On t210ref create sym-links for gpu fw loading. On < k4.4 it used
	#    /lib/firmware/tegra21x/
	# but on k4.4 and later it is using:
	#    /lib/firmware/gm20b/
	# T186 doesn't have this problem as we only supported from k4.4 forward
	# but we'll need to keep this section for the l4t binaries on t210
	if [ -d "lib/firmware/tegra21x/" ]; then
		echo "Creating t210 gm20b symbolic links..."
		GM20B_DIR="${LDK_ROOTFS_DIR}/lib/firmware/gm20b/"
		mkdir -p "${GM20B_DIR}"
		pushd "${GM20B_DIR}" > /dev/null 2>&1
		sudo ln -sf "../tegra21x/acr_ucode.bin" "acr_ucode.bin"
		sudo ln -sf "../tegra21x/gpmu_ucode.bin" "gpmu_ucode.bin"
		sudo ln -sf "../tegra21x/gpmu_ucode_desc.bin" \
				"gpmu_ucode_desc.bin"
		sudo ln -sf "../tegra21x/gpmu_ucode_image.bin" \
				"gpmu_ucode_image.bin"
		sudo ln -sf "../tegra21x/gpu2cde.bin" \
				"gpu2cde.bin"
		sudo ln -sf "../tegra21x/NETB_img.bin" "NETB_img.bin"
		sudo ln -sf "../tegra21x/fecs_sig.bin" "fecs_sig.bin"
		sudo ln -sf "../tegra21x/pmu_sig.bin" "pmu_sig.bin"
		sudo ln -sf "../tegra21x/pmu_bl.bin" "pmu_bl.bin"
		sudo ln -sf "../tegra21x/fecs.bin" "fecs.bin"
		sudo ln -sf "../tegra21x/gpccs.bin" "gpccs.bin"
		popd > /dev/null
	fi
	popd > /dev/null 2>&1

	echo "Extracting the BSP test tools to ${LDK_ROOTFS_DIR}"
	pushd "${LDK_ROOTFS_DIR}" > /dev/null 2>&1
	tar xpfm ${LDK_NV_TEGRA_DIR}/nv_tools.tbz2
	popd > /dev/null 2>&1

	echo "Extracting the NVIDIA gst test applications to ${LDK_ROOTFS_DIR}"
	pushd "${LDK_ROOTFS_DIR}" > /dev/null 2>&1
	tar xpfm ${LDK_NV_TEGRA_DIR}/nv_sample_apps/nvgstapps.tbz2
	popd > /dev/null 2>&1

	echo "Extracting the configuration files for the supplied root filesystem to ${LDK_ROOTFS_DIR}"
	pushd "${LDK_ROOTFS_DIR}" > /dev/null 2>&1
	tar xpfm ${LDK_NV_TEGRA_DIR}/config.tbz2
	popd > /dev/null 2>&1

	NV_RELEASE_BOARD=$(cat ${LDK_ROOTFS_DIR}/etc/nv_tegra_release | grep "BOARD:" | awk '{print $9}' | sed "s/,//g")

	echo "Creating a symbolic link nvgstplayer pointing to nvgstplayer-1.0"
	pushd "${LDK_ROOTFS_DIR}/usr/bin/" > /dev/null 2>&1
	if [ -h "nvgstplayer" ] || [ -e "nvgstplayer" ]; then
		rm -f nvgstplayer
	fi
	sudo ln -s "nvgstplayer-1.0" "nvgstplayer"
	popd > /dev/null

	echo "Creating a symbolic link nvgstcapture pointing to nvgstcapture-1.0"
	pushd "${LDK_ROOTFS_DIR}/usr/bin/" > /dev/null 2>&1
	if [ -h "nvgstcapture" ] || [ -e "nvgstcapture" ]; then
		rm -f nvgstcapture
	fi
	sudo ln -s "nvgstcapture-1.0" "nvgstcapture"
	popd > /dev/null

	ARM_ABI_DIR=

	if [ -d "${LDK_ROOTFS_DIR}/usr/lib/arm-linux-gnueabihf/tegra" ]; then
		ARM_ABI_DIR_ABS="usr/lib/arm-linux-gnueabihf"
	elif [ -d "${LDK_ROOTFS_DIR}/usr/lib/arm-linux-gnueabi/tegra" ]; then
		ARM_ABI_DIR_ABS="usr/lib/arm-linux-gnueabi"
	elif [ -d "${LDK_ROOTFS_DIR}/usr/lib/aarch64-linux-gnu/tegra" ]; then
		ARM_ABI_DIR_ABS="usr/lib/aarch64-linux-gnu"
	else
		echo "Error: None of Hardfp/Softfp Tegra libs found"
		exit 4
	fi

	echo "Extracting Weston to ${LDK_ROOTFS_DIR}"
	pushd "${LDK_ROOTFS_DIR}" > /dev/null 2>&1
	tar xpfm "${LDK_NV_TEGRA_DIR}/weston.tbz2"
	popd > /dev/null 2>&1

	ARM_ABI_DIR="${LDK_ROOTFS_DIR}/${ARM_ABI_DIR_ABS}"
	ARM_ABI_TEGRA_DIR="${ARM_ABI_DIR}/tegra"
	ARM_ABI_TEGRA_EGL_DIR="${ARM_ABI_DIR}/tegra-egl"
	VULKAN_ICD_DIR="${LDK_ROOTFS_DIR}/etc/vulkan/icd.d"

	# Create symlinks to satisfy applications trying to link unversioned libraries during runtime
	pushd "${ARM_ABI_TEGRA_DIR}" > /dev/null 2>&1
	echo "Adding symlink libcuda.so --> libcuda.so.1.1 in target rootfs"
	sudo ln -sf "libcuda.so.1.1" "libcuda.so"
	echo "Adding symlink libGL.so --> libGL.so.1 in target rootfs"
	sudo ln -sf "libGL.so.1" "libGL.so"
	echo "Adding symlink libnvbuf_utils.so --> libnvbuf_utils.so.1.0.0 in target rootfs"
	sudo ln -sf "libnvbuf_utils.so.1.0.0" "libnvbuf_utils.so"
	popd > /dev/null

	pushd "${ARM_ABI_DIR}" > /dev/null 2>&1
	echo "Adding symlink libcuda.so --> tegra/libcuda.so in target rootfs"
	sudo ln -sf "tegra/libcuda.so" "libcuda.so"
	popd > /dev/null

	pushd "${ARM_ABI_TEGRA_EGL_DIR}" > /dev/null 2>&1
	echo "Adding symlink libEGL.so --> libEGL.so.1 in target rootfs"
	sudo ln -sf "libEGL.so.1" "libEGL.so"
	popd > /dev/null

	pushd "${ARM_ABI_DIR}" > /dev/null 2>&1
	echo "Adding symlink ${ARM_ABI_DIR}/libdrm_nvdc.so --> ${ARM_ABI_TEGRA_DIR}/libdrm.so.2"
	sudo ln -sf "tegra/libdrm.so.2" "libdrm_nvdc.so"
	popd > /dev/null

	sudo mkdir -p "${VULKAN_ICD_DIR}"
	echo "Adding symlink nvidia_icd.json --> /etc/vulkan/icd.d/nvidia_icd.json in target rootfs"
	pushd "${VULKAN_ICD_DIR}" > /dev/null 2>&1
	sudo ln -sf "../../../${ARM_ABI_DIR_ABS}/tegra/nvidia_icd.json" "nvidia_icd.json"
	popd > /dev/null

	if [ -e "${ARM_ABI_DIR}/libglfw.so.3.3" ] ; then
		pushd "${ARM_ABI_DIR}" > /dev/null 2>&1
		echo "Adding symlink libglfw.so --> libglfw.so.3.3"
		sudo ln -sf "libglfw.so.3.3" "libglfw.so"
		echo "Adding symlink libglfw.so.3 --> libglfw.so.3.3"
		sudo ln -sf "libglfw.so.3.3" "libglfw.so.3"
		popd > /dev/null
	fi

	# Make sure the firstboot script runs before lightdm starts
	if [ -e "${LDK_ROOTFS_DIR}/etc/init/lightdm.conf" ] || [ -e "${LDK_ROOTFS_DIR}/etc/init/lightdm.conf.override" ] ; then
		ReplaceText "${LDK_ROOTFS_DIR}/etc/init/nvfb.conf" "ldconfig" "ldconfig\n\tservice lightdm restart";
		ReplaceText "${LDK_ROOTFS_DIR}/etc/systemd/nvfb.sh" "ldconfig" "ldconfig\n\tservice lightdm restart";
	fi

	if [ -e "${LDK_ROOTFS_DIR}/usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf" ] ; then
		ReplaceText "${LDK_ROOTFS_DIR}/usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf" \
				"autologin-user=ubuntu" "autologin-user=nvidia";
		if [ -e "${LDK_ROOTFS_DIR}/etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf" ] ; then
			ReplaceText "${LDK_ROOTFS_DIR}/etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf" \
				"ubuntu" "nvidia";
		fi

		grep -q -F 'allow-guest=false' \
			"${LDK_ROOTFS_DIR}/usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf" \
			|| echo 'allow-guest=false' \
			>> "${LDK_ROOTFS_DIR}/usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf"

		pushd "${LDK_ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants" > /dev/null 2>&1
		if [ -f ${LDK_ROOTFS_DIR}/etc/systemd/system/nvpmodel.service ]; then
			sudo ln -sf "../nvpmodel.service" "nvpmodel.service"
		fi
		popd > /dev/null
	fi

	echo "Adding symlinks for systemd nv.service and nvfb.service"
	mkdir -p  "${LDK_ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants"
	pushd "${LDK_ROOTFS_DIR}/etc/systemd/system/multi-user.target.wants" > /dev/null 2>&1
	sudo ln -sf "../argus-daemon.service" "argus-daemon.service"
	sudo ln -sf "../nvfb.service" "nvfb.service"
	sudo ln -sf "../nv.service" "nv.service"
	sudo ln -sf "../nvcamera-daemon.service" "nvcamera-daemon.service"
	# disable nvphs on startup due to bug 1936407.
	# sudo ln -sf "../nvphs.service" "nvphs.service"
	popd > /dev/null

	# Disabling NetworkManager-wait-online.service for Bug 200290321
	echo "Disabling NetworkManager-wait-online.service"
	if [ -h "${LDK_ROOTFS_DIR}/etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service" ]; then
		sudo rm "${LDK_ROOTFS_DIR}/etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service"
	fi

	echo "Disable the ondemand service by changing the runlevels to 'K'"
	for file in "${LDK_ROOTFS_DIR}"/etc/rc[0-9].d/; do
		if [ -f "${file}"/S*ondemand ]; then
			mv "${file}"/S*ondemand "${file}/K01ondemand"
		fi
	done

	# Disable power-switch udev rule that causing system shutdown when wakeup from lp0 suspend
	POWER_UDEV_RULES="${LDK_ROOTFS_DIR}/lib/udev/rules.d/70-power-switch.rules"
	if [ -f "${POWER_UDEV_RULES}" ]; then
		sed -i 'N;/^SUBSYSTEM.*gpio-keys.*/ s/^/#/g' "${POWER_UDEV_RULES}"
		sed -i '/^ .*gpio-keys.*/ s/^/#/g' "${POWER_UDEV_RULES}"
	fi
fi

if [ "${FACTORY}" = "true" ] ; then
	echo "Performing factory install"

	echo "Extracting tegra config files"
	TMP_FLASH_DIR=`mktemp -d`
	pushd "${TMP_FLASH_DIR}/" > /dev/null
	sudo tar jxpfm ${LDK_DIR}/nv_tegra/config.tbz2
	if [ ! -d "${TMP_FLASH_DIR}/etc" ] ; then
		echo "Error: config.tbz2 is not extracted. Exiting .."
		exit 5
	fi

	# make the etc directory
	if [ ! -d "${LDK_ROOTFS_DIR}/etc/init" ] ; then
		sudo mkdir -p ${LDK_ROOTFS_DIR}/etc/init
	fi
	if [ ! -d "${LDK_ROOTFS_DIR}/etc/udev/rules.d" ] ; then
		sudo mkdir -p ${LDK_ROOTFS_DIR}/etc/udev/rules.d
	fi
	sudo cp ${TMP_FLASH_DIR}/etc/*conf* ${LDK_ROOTFS_DIR}/etc/
	sudo cp "${TMP_FLASH_DIR}/etc/init/ttyS0.conf" "${LDK_ROOTFS_DIR}/etc/init"
	sudo cp "${TMP_FLASH_DIR}/etc/init/nv.conf" "${LDK_ROOTFS_DIR}/etc/init"
	sudo cp "${TMP_FLASH_DIR}/etc/udev/rules.d/90-alsa-asound-tegra.rules" "${LDK_ROOTFS_DIR}/etc/udev/rules.d/"
	sudo cp "${TMP_FLASH_DIR}/etc/udev/rules.d/99-tegra-devices.rules" "${LDK_ROOTFS_DIR}/etc/udev/rules.d/"
	sudo cp "${TMP_FLASH_DIR}/etc/udev/rules.d/99-tegra-mmc-ra.rules" "${LDK_ROOTFS_DIR}/etc/udev/rules.d/"

	sudo rm -rf "${TMP_FLASH_DIR}/*"

	# set nvidia as default user
	if [ -e "${LDK_ROOTFS_DIR}/etc/systemd/system/getty@tty1.service.d/autologin.conf" ] ; then
		ReplaceText "${LDK_ROOTFS_DIR}/etc/systemd/system/getty@tty1.service.d/autologin.conf" \
		"ubuntu" "nvidia";
	fi
	if [ -e "${LDK_ROOTFS_DIR}/etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf" ] ; then
		ReplaceText "${LDK_ROOTFS_DIR}/etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf" \
		"ubuntu" "nvidia";
	fi

	echo "Extracting nvidia firmware files"
	sudo tar jxpfm ${LDK_DIR}/nv_tegra/nvidia_drivers.tbz2
	if [ ! -d "${TMP_FLASH_DIR}/lib/firmware" ] ; then
		echo "Error: nvidia_drivers.tbz2 is not extracted. Exiting .."
		exit 5
	fi
	if [ ! -d "${LDK_ROOTFS_DIR}/lib/firmware" ] ; then
		sudo mkdir -p ${LDK_ROOTFS_DIR}/lib/firmware
	fi
	sudo cp -rf ${TMP_FLASH_DIR}/lib/firmware/* ${LDK_ROOTFS_DIR}/lib/firmware/
	popd > /dev/null 2>&1
	sudo rm -rf ${TMP_FLASH_DIR}

	if [ ! -d "${BSP_LOCATION_DIR}" ] ; then
		echo "ERROR: ${BSP_LOCATION_DIR} does not exist!"
		exit 1
	fi

	echo "Copying factory install license, readme, and installer"
	# install the license, readme, installer
	sudo mkdir -p ${LDK_ROOTFS_DIR}${FACTORY_TARGET_DIR}
	sudo cp ${LDK_NV_TEGRA_DIR}/LICENSE ${LDK_ROOTFS_DIR}${FACTORY_TARGET_DIR}
	TARGET_SCRIPT_DIR=${BSP_LOCATION_DIR}/target_side_scripts
	sudo cp ${TARGET_SCRIPT_DIR}/README.txt ${LDK_ROOTFS_DIR}${FACTORY_TARGET_DIR}
	sudo cp ${TARGET_SCRIPT_DIR}/installer.sh ${LDK_ROOTFS_DIR}${FACTORY_TARGET_DIR}
	sudo cp ${BSP_LOCATION_DIR}/Tegra*_Linux_R*.tbz2 ${LDK_ROOTFS_DIR}${FACTORY_TARGET_DIR}

	if [ -e "${LDK_ROOTFS_DIR}/lib/systemd/system/default.target" ]; then
		pushd "${LDK_ROOTFS_DIR}/lib/systemd/system/" > /dev/null 2>&1
		sudo rm -f "${LDK_ROOTFS_DIR}/lib/systemd/system/default.target"
		sudo ln -sf multi-user.target default.target
		popd > /dev/null 2>&1
	fi
fi

echo "Extracting the firmwares and kernel modules to ${LDK_ROOTFS_DIR}"
( cd "${LDK_ROOTFS_DIR}" ; tar jxpfm "${LDK_KERN_DIR}/kernel_supplements.tbz2" )

echo "Extracting the kernel headers to ${LDK_ROOTFS_DIR}/usr/src"
# The kernel headers package can be used on the target device as well as on another host.
# When used on the target, it should go into /usr/src and owned by root.
KERNEL_HEADERS_NAME=$(tar tf "${LDK_KERN_DIR}/kernel_headers.tbz2" | head -1 | cut -d/ -f1)
if [ ! -d "${LDK_ROOTFS_DIR}/usr/src" ] ; then
	sudo mkdir -v "${LDK_ROOTFS_DIR}/usr/src"
fi
pushd "${LDK_ROOTFS_DIR}/usr/src" > /dev/null 2>&1
sudo tar jxpfm "${LDK_KERN_DIR}/kernel_headers.tbz2"
# Since the files are owned by root, the README needs to be adjusted.
ReplaceText "${KERNEL_HEADERS_NAME}/README" "make modules_prepare" "sudo make modules_prepare";
sudo chown -R root:root "${KERNEL_HEADERS_NAME}"
# Link to the kernel headers from /lib/modules/<version>/build
KERNEL_MODULES_DIR="${LDK_ROOTFS_DIR}/lib/modules/${KERNEL_HEADERS_NAME#linux-headers-}"
if [ -d "${KERNEL_MODULES_DIR}" ] ; then
	echo "Adding symlink ${KERNEL_MODULES_DIR}/build --> /usr/src/${KERNEL_HEADERS_NAME}"
	[ -h "${KERNEL_MODULES_DIR}/build" ] && sudo unlink "${KERNEL_MODULES_DIR}/build" && rm -f "${KERNEL_MODULES_DIR}/build"
	[ ! -h "${KERNEL_MODULES_DIR}/build" ] && sudo ln -s "/usr/src/${KERNEL_HEADERS_NAME}" "${KERNEL_MODULES_DIR}/build"
fi
popd > /dev/null

if [ -e "${LDK_KERN_DIR}/zImage" ] ; then
	echo "Installing zImage into /boot in target rootfs"
	sudo install --owner=root --group=root --mode=644 -D "${LDK_KERN_DIR}/zImage" "${LDK_ROOTFS_DIR}/boot/zImage"
fi

if [ -e "${LDK_KERN_DIR}/Image" ] ; then
	echo "Installing Image into /boot in target rootfs"
	sudo install --owner=root --group=root --mode=644 -D "${LDK_KERN_DIR}/Image" "${LDK_ROOTFS_DIR}/boot/Image"
fi

shopt -s nullglob
elconfs=("${LDK_BOOTLOADER_DIR}"/*/*extlinux.conf.*)
if [ ${#elconfs[@]} -ge 1 ]; then
	echo "Installing *extlinux.conf* into /boot in target rootfs"
	for elconf in "${elconfs[@]}"; do
		dest="${LDK_ROOTFS_DIR}"/boot/${elconf##*/}
		sudo install --owner=root --group=root --mode=644 -D "${elconf}" "${dest}"
	done
fi

echo "Installing the board *.dtb files into /boot in target rootfs"
if [ ! -d "${LDK_ROOTFS_DIR}/boot" ] ; then
	sudo mkdir -v "${LDK_ROOTFS_DIR}"/boot
fi
sudo cp -a "${LDK_KERN_DIR}"/dtb/*.dtb "${LDK_ROOTFS_DIR}/boot"

echo "Success!"
