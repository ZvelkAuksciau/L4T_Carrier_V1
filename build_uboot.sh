#! /bin/bash


"Setting Environmental Variables..."
export ARCH=arm64
export CROSS32CC=/opt/linaro/gcc-linaro-5.3-2016.02-x86_64_arm-linux-gnueabihf/bin/arm-linux-gnueabihf-gcc
export TX_BASE_DIR=${PWD}
export CROSS_COMPILE=/opt/linaro/gcc-linaro-5.3-2016.02-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-
export TEGRA_UBOOT_OUT=$TX_BASE_DIR/Linux_for_Tegra/bootloader/t210ref/kmti200-2180
export ROOTFS_PATH=$TX_BASE_DIR/Linux_for_Tegra/rootfs
export UBOOT_SOURCE=$TX_BASE_DIR/Linux_for_Tegra/sources/u-boot


COMMAND="BUILD"

#Parse the Inputs

echo "Key: $1"

while [[ $# > 0 ]]
do
key="$1"

case $key in
    -r|--rebuild)
    COMMAND="REBUILD"
    shift # past argument

    ;;
    -m|--menu)
    COMMAND="MENU"
    shift # past argument

    ;;
    *)
    # unknown option

    ;;
esac
shift
done

echo "Finished parsing inputs"

echo "Updating git submodules"
git submodule update --init --recursive

cd $UBOOT_SOURCE

if [ "$COMMAND" == "BUILD" ]; then
  echo "Build"
  make O=$TEGRA_UBOOT_OUT -j4
fi
if [ "$COMMAND" == "REBUILD" ]; then
  echo "Re-Build"
  make mrproper
  make O=$TEGRA_UBOOT_OUT -j4 distclean
  make O=$TEGRA_UBOOT_OUT -j4 kmti200-2180_defconfig
  make O=$TEGRA_UBOOT_OUT -j4
fi
if [ "$COMMAND" == "MENU" ]; then
  echo "Menu Config"
  make O=$TEGRA_UBOOT_OUT -j4 menuconfig
fi
