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

checkroot

umountroot
umount -lf sdcard/otgstorage
umount -lf sdcard

#guessing sd image size..
ROOTSIZE="$(du -s "$ROOTFS" | cut -f 1)"
SDSIZE="$(( $ROOTSIZE * 115 / 100000 ))"

OUTPUT="udoobuntu-$BOARD-$FLAVOUR"

if [ -n "$RELEASE" ]; then
    OUTPUT+=$(echo $RELEASE | sed -e "s/ //g" | tr '[:upper:]' '[:lower:]' | awk '{print "_"$1".img"}')
else
    OUTPUT+="_$(date +%Y%m%d-%H%M).img"
fi

echo -e "${GREENBOLD}Creating a $SDSIZE MB image in $OUTPUT...${RST}" >&1 >&2
dd if=/dev/zero of=$OUTPUT bs=1M count=$SDSIZE status=noxfer >/dev/null 2>&1

LOOP=$(losetup -f)
losetup $LOOP $OUTPUT || error "Cannot set $LOOP" 

OFFSET="1"
FATPARTSIZE="32"
FATPARTSTART=$(($OFFSET*2048))
ROOTSTART=$(($FATPARTSTART+($FATPARTSIZE*2048)))
FATPARTEND=$(($ROOTSTART-1))

echo -e "${GREENBOLD}Creating image partitions...${RST}" >&1 >&2
parted -s $LOOP -- mklabel msdos
parted -s $LOOP -- mkpart primary fat16  $FATPARTSTART"s" $FATPARTEND"s"
parted -s $LOOP -- mkpart primary ext4  $ROOTSTART"s" -1s
partprobe $LOOP
mkfs.vfat -n "UDOO" $LOOP"p1" >/dev/null 2>&1
mkfs.ext4 -q $LOOP"p2" -L "UDOObuntu"

mkdir sdcard 2> /dev/null
mount $LOOP"p2" sdcard

for i in boot otgstorage dev proc run mnt tmp
  do mkdir -p "sdcard/$i"
done
    
chmod o+t,ugo+rw sdcard/tmp
mount "${LOOP}p1" sdcard/otgstorage

echo -e "${GREENBOLD}Copying filesystem on SD image...${RST}" >&1 >&2
rsync -a --exclude run --exclude tmp --exclude qemu-arm-static "$ROOTFS/" sdcard/
ln -s /run sdcard/var/run
ln -s /run/network sdcard/etc/network/run
mkdir sdcard/var/tmp
chmod o+t,ugo+rw sdcard/var/tmp

echo -e "${GREENBOLD}Writing U-Boot...${RST}" >&1 >&2
dd if=boards/$BOARD/uboot.imx of="$LOOP" bs=1k seek=1
sync

umount -lf sdcard/otgstorage
umount -lf sdcard

losetup -d "$LOOP"
sync

echo -e "${GREENBOLD}Build complete!${RST}"
