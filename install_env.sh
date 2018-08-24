#!/bin/bash

LINARO_BASE_URL=http://releases.linaro.org/components/toolchain/binaries
LINARO_VERSION=5.3-2016.02-x86_64
gnueabihf
ARM_GCC_64_FILE=gcc-linaro-${LINARO_VERSION}_aarch64-linux-gnu.tar.xz
ARM_GCC_32_FILE=gcc-linaro-${LINARO_VERSION}_arm-linux-gnueabihf.tar.xz
ARM_GCC_64_URL=${LINARO_BASE_URL}/5.3-2016.02/aarch64-linux-gnu/${ARM_GCC_64_FILE}
ARM_GCC_32_URL=${LINARO_BASE_URL}/5.3-2016.02/arm-linux-gnueabihf/${ARM_GCC_32_FILE}


# Install cross compile toolchain
mkdir -p /opt/linaro
chmod -R 775 /opt/linaro
chown -R $USER /opt/linaro
cd /opt/linaro
wget $ARM_GCC_64_URL
wget $ARM_GCC_32_URL
tar -xf $ARM_GCC_64_FILE
tar -xf $ARM_GCC_32_FILE
rm $ARM_GCC_64_FILE
rm $ARM_GCC_32_FILE
cd -

sudo apt-get install device-tree-compiler -y
