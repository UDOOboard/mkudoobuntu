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

echo -e "Unmount..."
umountroot
umount -lf sdcard/boot
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
BOOTSIZE="32"
BOOTSTART=$(($OFFSET*2048))
ROOTSTART=$(($BOOTSTART+($BOOTSIZE*2048)))
BOOTEND=$(($ROOTSTART-1))

LABELBOOT=${LABELBOOT:-boot}
LABELFS=${LABELFS:-udoobuntu}

echo -e "${GREENBOLD}Creating image partitions...${RST}" >&1 >&2
# Create partitions and file-system
parted -s $LOOP -- mklabel msdos
parted -s $LOOP -- mkpart primary fat16  $BOOTSTART"s" $BOOTEND"s"
parted -s $LOOP -- mkpart primary ext4  $ROOTSTART"s" -1s
partprobe $LOOP
mkfs.vfat -n "$LABELBOOT" $LOOP"p1" >/dev/null 2>&1
mkfs.ext4 -q $LOOP"p2" -L "$LABELFS"

mkdir sdcard 2> /dev/null
mount $LOOP"p2" sdcard

for i in boot dev proc run mnt tmp
  do mkdir -p "sdcard/$i"
done
    
chmod o+t,ugo+rw sdcard/tmp
mount "${LOOP}p1" sdcard/boot

rm -rf "$ROOTFS/home/ubuntu" #temp fix, we need to move the files later

echo -e "${GREENBOLD}Copying filesystem on SD image...${RST}" >&1 >&2
rsync -a --exclude run --exclude tmp --exclude qemu-arm-static "$ROOTFS/" sdcard/
ln -s /run sdcard/var/run
ln -s /run/network sdcard/etc/network/run
mkdir sdcard/var/tmp
chmod o+t,ugo+rw sdcard/var/tmp

echo -e "${GREENBOLD}Writing U-BOOT...${RST}" >&1 >&2
dd if=boards/$BOARD/uboot.imx of="$LOOP" bs=1k seek=1
sync

umount -lf sdcard/boot
umount -lf sdcard

losetup -d "$LOOP"
sync

echo -e "${GREENBOLD}Build complete!${RST}"
