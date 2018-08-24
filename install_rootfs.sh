#!/bin/bash

ROOTFS_DIR=Linux_for_Tegra/rootfs
NVIDIA_JETSON_BASE_URL=http://developer.nvidia.com/embedded/dlc/
ROOT_FS_NAME=l4t-sample-root-filesystem-28-1
ROOT_FS_URL=${NVIDIA_JETSON_BASE_URL}${ROOT_FS_NAME}

https://developer.nvidia.com/embedded/dlc/l4t-sample-root-filesystem-28-1

cd $ROOTFS_DIR
echo "Downloading rootfs"
wget $ROOT_FS_URL
sudo tar jxpf $ROOT_FS_NAME
rm $ROOT_FS_NAME
cd -
