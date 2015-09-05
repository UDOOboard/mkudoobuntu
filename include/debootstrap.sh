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

if [ -d $ROOTFS ]
then
  umountroot
  echo -n "Deleting old root filesystem, are you sure? (y/N) "
  read CHOICE
  
  [[ $CHOICE = [Yy] ]] || error
  
  rm -rf $ROOTFS
fi

echo -e "Debootstrapping" >&1 >&2
DEBOOT_PACKAGES=`echo $DEBOOT_PACKAGES | sed -e 's/ /,/g'`
debootstrap  --foreign \
             --arch=armhf \
             --include="$DEBOOT_PACKAGES" trusty $ROOTFS http://127.0.0.1:3142/ports.ubuntu.com

echo -e "Using emulator to finish install" >&1 >&2
cp /usr/bin/qemu-arm-static $ROOTFS/usr/bin
chroot $ROOTFS/ /bin/bash -c "/debootstrap/debootstrap --second-stage"
mountroot

echo -e "Disabling services" >&1 >&2
mkdir $ROOTFS/fake
for i in initctl invoke-rc.d restart start stop start-stop-daemon service
do
  ln -s /bin/true $ROOTFS/fake/"$i"
done

cp patches/gpg.key $ROOTFS/tmp/

echo -e "Upgrade, dist-upgrade" >&1 >&2
install -m 644 patches/sources.list $ROOTFS/etc/apt/sources.list
install -m 644 patches/udoo.list $ROOTFS/etc/apt/sources.list.d/udoo.list
install -m 644 patches/udoo.preferences $ROOTFS/etc/apt/preferences.d/udoo

LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTFS/ /bin/bash -c "apt-key add /tmp/gpg.key"
LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTFS/ /bin/bash -c "apt-get -y update"
LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTFS/ /bin/bash -c 'PATH=/fake:$PATH apt-get -y --allow-unauthenticated dist-upgrade'
LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTFS/ /bin/bash -c 'PATH=/fake:$PATH apt-get -y -qq install locales'
LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTFS/ /bin/bash -c "locale-gen en_US.UTF-8 it_IT.UTF-8 en_GB.UTF-8"
LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTFS/ /bin/bash -c "export LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 DEBIAN_FRONTEND=noninteractive"
LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTFS/ /bin/bash -c "update-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_MESSAGES=POSIX"

echo -e "Install packages" >&1 >&2
chroot $ROOTFS/ /bin/bash -c "PATH=/fake:$PATH DEBIAN_FRONTEND=noninteractive apt-get -y install ${BASE_PACKAGES[*]}"

if [ "$BUILD_DESKTOP" = "yes" ]; then
  echo -e "Install desktop environment" >&1 >&2
  chroot $ROOTFS/ /bin/bash -c "PATH=/fake:$PATH DEBIAN_FRONTEND=noninteractive apt-get -y install ${DESKTOP_PACKAGES[*]}"
fi

echo -e "Cleanup" >&1 >&2
touch $ROOTFS/etc/init.d/modemmanager
chroot $ROOTFS/ /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get purge -y -qq ${UNWANTED_PACKAGES[*]}"
chroot $ROOTFS/ /bin/bash -c "PATH=/fake:$PATH DEBIAN_FRONTEND=noninteractive apt-get autoremove -y"
chroot $ROOTFS/ /bin/bash -c "PATH=/fake:$PATH DEBIAN_FRONTEND=noninteractive apt-get clean -y "
chroot $ROOTFS/ /bin/bash -c "PATH=/fake:$PATH DEBIAN_FRONTEND=noninteractive apt-get autoclean -y "
rm -rf $ROOTFS/fake
