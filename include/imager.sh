#!/bin/bash
#
#             UU                                                              
#         U   UU  UU                                                          
#         UU  UU  UU                                                          
#         UU  UU  UU  UU                                                      
#         UU  UU  UU  UU                                                      
#         UU  UUU UU  UU                                 Filesystem Builder   
#                                                                             
#         UUUUUUUUUUUUUU  DDDDDDDDDD         OOOOOOOO         OOOOOOOOO       
#    UUU  UUUUUUUUUUUUUU  DDDDDDDDDDDD     OOOOOOOOOOOO     OOOOOOOOOOOOO     
#     UUU UUUUUUUUUUUUUU  DDDDDDDDDDDDD  OOOOOOOOOOOOOOOO  OOOOOOOOOOOOOOOO   
#       UUUUUUUUUUUUUUUU  DDDDDDDDDDDDD  OOOOOOOOOOOOOOOO  OOOOOOOOOOOOOOOO   
#        UUUUUUUUUUUUUU   DDDDDDDDDDDDD  OOOOOOOOOOOOOOOO  OOOOOOOOOOOOOOOO   
#          UUUUUUUUUUUU   DDDDDDDDDDDD    OOOOOOOOOOOOOO    OOOOOOOOOOOOOO    
#           UUUUUUUUUU    DDDDDDDDDDD       OOOOOOOOOO        OOOOOOOOOO      
#
#   Author: Francesco Montefoschi <francesco.monte@gmail.com>
#   Author: Ettore Chimenti <ek5.chimenti@gmail.com>
#   Based on: Igor Pečovnik's work - https://github.com/igorpecovnik/lib
#   License: GNU GPL version 2
#
################################################################################

KERNEL=$1
UBOOT=$2

dd if=/dev/zero of=$OUTPUT bs=1M count=$SDSIZE status=noxfer >/dev/null 2>&1
LOOP=$(losetup -f)
losetup $LOOP $OUTPUT

OFFSET="1"
BOOTSIZE="32"
BOOTSTART=$(($OFFSET*2048))
ROOTSTART=$(($BOOTSTART+($BOOTSIZE*2048)))
BOOTEND=$(($ROOTSTART-1))

# Create partitions and file-system
parted -s $LOOP -- mklabel msdos
parted -s $LOOP -- mkpart primary fat16  $BOOTSTART"s" $BOOTEND"s"
parted -s $LOOP -- mkpart primary ext4  $ROOTSTART"s" -1s
partprobe $LOOP
mkfs.vfat -n "BOOT" $LOOP"p1" >/dev/null 2>&1
mkfs.ext4 -q $LOOP"p2"

mkdir sdcard
mount $LOOP"p2" sdcard
mkdir sdcard/boot
mkdir sdcard/dev
mkdir sdcard/proc
mkdir sdcard/run
mkdir sdcard/tmp
mkdir sdcard/mnt
mount $LOOP"p1" sdcard/boot

rsync -a --exclude dev --exclude proc --exclude run --exclude tmp --exclude mnt --exclude sys rootfs/ sdcard/

cp $KERNEL sdcard/tmp/kernel.deb
chroot sdcard/ /bin/bash -c "dpkg -i /tmp/kernel.deb && rm /tmp/kernel.deb"

rm sdcard/usr/bin/qemu-arm-static

# write bootloader
dd if=$UBOOT of=$LOOP bs=1k seek=1
sync

umount -l sdcard/boot
umount -l sdcard

losetup -d $LOOP
sync
