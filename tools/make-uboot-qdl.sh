#!/bin/bash
# Author: Francesco Montefoschi <francesco.monte@gmail.com>
# License: GNU GPL version 2

if [ "$#" -ne 1 ]; then
    echo "Please call this script with u-boot-imx repo path as first argument."
    exit 1
fi

args=("$@")
ubootdir=${args[0]}
binarydir="$(dirname "$(pwd)")/binary"
targetfile="uboot-qdl.imx"

cd $ubootdir
ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make clean
ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make udoo_qdl_config
ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make
cd -

if [ ! -e $ubootdir/SPL ]; then
    echo "SPL file missing! Check build messages for errors."
    exit 1
fi

if [ ! -e $ubootdir/u-boot.img ]; then
    echo "u-boot.img file missing! Check build messages for errors."
    exit 1
fi

truncate $binarydir/$targetfile --size 500k
dd if=$ubootdir/SPL of=$binarydir/$targetfile bs=1K seek=0 conv=notrunc
dd if=$ubootdir/u-boot.img of=$binarydir/$targetfile bs=1K seek=68

echo "Your u-boot is in $binarydir/$targetfile"

