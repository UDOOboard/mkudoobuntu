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

BASE_PACKAGES="console-data console-common pv sysfsutils cpufrequtils i2c-tools hostapd ntfs-3g \
locate firmware-ralink udev-udoo-rules"

DESKTOP_PACKAGES="lubuntu-core leafpad lxterminal unrar lxmusic galculator lxtask lxappearance \
lxrandr lxshortcut lxinput evince transmission-gtk abiword gimp file-roller lubuntu-software-center \
scratch gimp geany bluefish pavucontrol udoo-artwork dpkg-dev imx-vpu-cnm-9t imx-gpu-viv-9t6-acc-x11 \
chromium-browser chromium-browser-l10n chromium-chromedriver chromium-codecs-ffmpeg chromium-egl \
xserver-xorg-core xserver-common libdrm-dev xserver-xorg-dev xvfb arduino-ide-udoo-qdl"

UNWANTED_PACKAGES="apport apport-symptoms python3-apport colord hplip libsane \
libsane-common libsane-hpaio printer-driver-postscript-hp sane-utils modemmanager"

if [ -d rootfs ]
then
	echo -e "Deleting old root filesystem"
	rm -rf rootfs
fi
echo -e "Debootstrapping"
debootstrap --foreign --arch=armhf --include="openssh-server,debconf-utils,alsa-utils,bash-completion,bluez,curl,dosfstools,fbset,iw,nano,module-init-tools,ntp,screen,unzip,usbutils,vlan,wireless-tools,wget,wpasupplicant,unicode-data" trusty rootfs http://127.0.0.1:3142/ports.ubuntu.com

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

cp patches/gpg.key rootfs/tmp/
cp patches/udookernel.deb rootfs/tmp/

echo -e "Upgrade, dist-upgrade"
install -m 644 patches/sources.list rootfs/etc/apt/sources.list
install -m 644 patches/udoo.list rootfs/etc/apt/sources.list.d/udoo.list
install -m 644 patches/udoo.preferences rootfs/etc/apt/preferences.d/udoo

LC_ALL=C LANGUAGE=C LANG=C chroot rootfs/ /bin/bash -c "apt-key add /tmp/gpg.key"
LC_ALL=C LANGUAGE=C LANG=C chroot rootfs/ /bin/bash -c "apt-get -y update"
LC_ALL=C LANGUAGE=C LANG=C chroot rootfs/ /bin/bash -c 'PATH=/fake:$PATH apt-get -y --allow-unauthenticated dist-upgrade'
LC_ALL=C LANGUAGE=C LANG=C chroot rootfs/ /bin/bash -c 'PATH=/fake:$PATH apt-get -y -qq install locales'
LC_ALL=C LANGUAGE=C LANG=C chroot rootfs/ /bin/bash -c "locale-gen en_US.UTF-8 it_IT.UTF-8 en_GB.UTF-8"
LC_ALL=C LANGUAGE=C LANG=C chroot rootfs/ /bin/bash -c "export LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 DEBIAN_FRONTEND=noninteractive"
LC_ALL=C LANGUAGE=C LANG=C chroot rootfs/ /bin/bash -c "update-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_MESSAGES=POSIX"

echo -e "Install packages"
chroot rootfs/ /bin/bash -c "PATH=/fake:$PATH DEBIAN_FRONTEND=noninteractive apt-get -y install $BASE_PACKAGES"

echo -e "Install kernel"
chroot rootfs/ /bin/bash -c "dpkg -i /tmp/udookernel.deb"

if [ "$BUILD_DESKTOP" = "yes" ]; then
	echo -e "Install desktop environment"
	chroot rootfs/ /bin/bash -c "PATH=/fake:$PATH DEBIAN_FRONTEND=noninteractive apt-get -y install $DESKTOP_PACKAGES"
fi

echo -e "Cleanup"
touch rootfs/etc/init.d/modemmanager
chroot rootfs/ /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get purge -y -qq $UNWANTED_PACKAGES"
chroot rootfs/ /bin/bash -c "apt-get autoremove"
chroot rootfs/ /bin/bash -c "apt-get clean && apt-get autoclean"
rm -rf rootfs/fake

echo -e "Unmount"
umount -lf rootfs/dev/pts
umount -lf rootfs/dev
umount -lf rootfs/proc
umount -lf rootfs/sys

