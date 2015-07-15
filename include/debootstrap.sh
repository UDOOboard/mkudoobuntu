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

BASE_PACKAGES="alsa-utils bash-completion bluez cpufrequtils curl dosfstools fbset hostapd i2c-tools iw nano \
module-init-tools ntfs-3g ntp pv screen sysfsutils unzip usbutils vlan wireless-tools wget wpasupplicant \
console-data console-common unicode-data"

DESKTOP_PACKAGES="lubuntu-core lubuntu-default-session"

if [ -d rootfs ]
then
	echo -e "Deleting old root filesystem"
	rm -rf rootfs
fi
echo -e "Debootstrapping"
debootstrap --foreign --arch=armhf --include="openssh-server,debconf-utils" trusty rootfs

echo -e "Using emulator to finish install"
cp /usr/bin/qemu-arm-static rootfs/usr/bin
chroot rootfs/ /bin/bash -c "/debootstrap/debootstrap --second-stage"
mount -t proc chproc rootfs/proc
mount -t sysfs chsys rootfs/sys
mount -t devtmpfs chdev rootfs/dev || mount --bind /dev rootfs/dev
mount -t devpts chpts rootfs/dev/pts

echo -e "Disabling services"
mkdir rootfs/fake
for i in initctl invoke-rc.d restart start stop start-stop-daemon service
do
	ln -s /bin/true rootfs/fake/"$i"
done

echo -e "Upgrade, dist-upgrade"
cp patches/sources.list rootfs/etc/apt/sources.list
LC_ALL=C LANGUAGE=C LANG=C chroot rootfs/ /bin/bash -c "apt-get -y update"
LC_ALL=C LANGUAGE=C LANG=C chroot rootfs/ /bin/bash -c 'PATH=/fake:$PATH apt-get -y dist-upgrade'
LC_ALL=C LANGUAGE=C LANG=C chroot rootfs/ /bin/bash -c 'PATH=/fake:$PATH apt-get -y -qq install locales'
LC_ALL=C LANGUAGE=C LANG=C chroot rootfs/ /bin/bash -c "locale-gen en_US.UTF-8 it_IT.UTF-8 en_GB.UTF-8"
LC_ALL=C LANGUAGE=C LANG=C chroot rootfs/ /bin/bash -c "export LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 DEBIAN_FRONTEND=noninteractive"
LC_ALL=C LANGUAGE=C LANG=C chroot rootfs/ /bin/bash -c "update-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_MESSAGES=POSIX"

echo -e "Install packages"
chroot rootfs/ /bin/bash -c "PATH=/fake:$PATH DEBIAN_FRONTEND=noninteractive apt-get -y install $BASE_PACKAGES"

#echo -e "Install desktop environment"
#chroot rootfs/ /bin/bash -c "PATH=/fake:$PATH DEBIAN_FRONTEND=noninteractive apt-get -y install $DESKTOP_PACKAGES"

echo -e "Cleanup"
rm -rf rootfs/fake
chroot rootfs/ /bin/bash -c "apt-get clean && apt-get autoclean"

echo -e "Unmount"
umount -l rootfs/dev/pts
umount -l rootfs/dev
umount -l rootfs/proc
umount -l rootfs/sys

