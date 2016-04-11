#!/bin/bash
# Author: Francesco Montefoschi <francesco.monte@gmail.com>
# License: GNU GPL version 2

if [ "$#" -ne 1 ]; then
    echo "Please call this script with u-boot-imx repo path as first argument."
    exit 1
fi

args=("$@")
ubootdir=${args[0]}
OUTPUT=/tmp/qdl-sata.img

cd $ubootdir
ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make clean
ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make udoo_qd_sata_config
ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make -j8
cd -

if [ ! -e $ubootdir/SPL ]; then
    echo "SPL file missing! Check build messages for errors."
    exit 1
fi

if [ ! -e $ubootdir/u-boot.img ]; then
    echo "u-boot.img file missing! Check build messages for errors."
    exit 1
fi

truncate $OUTPUT --size 1M
dd if=$ubootdir/SPL of=$OUTPUT bs=1K seek=1 conv=notrunc
dd if=$ubootdir/u-boot.img of=$OUTPUT bs=1K seek=69 conv=notrunc

echo "Your SD image for SATA boot is in $OUTPUT"

