# L4T_Carrier_V1
Tegra TX1 build enviroment, additional programs for carrier support

# Building
To setup build enviroment execute sudo ./install_env.sh
This script will download toolchain and install necessary tools

To build u-boot for the first time run ./build_uboot.sh -r
After intial build use ./build_uboot.sh

To build kernel for the first time run ./build_kernel.sh -r
After initial build use ./build_kernel.sh
