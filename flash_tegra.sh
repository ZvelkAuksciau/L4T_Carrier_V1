#!/bin/bash

L4T_DIR=Linux_for_Tegra/

cd $L4T_DIR
sudo ./apply_binaries.sh
sudo ./flash.sh kmti200-2180 mmcblk0p1
