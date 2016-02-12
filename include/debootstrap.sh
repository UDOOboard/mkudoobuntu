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

set -e

checkroot
umountroot

export LC_ALL=C LANGUAGE=C LANG=C
UBUNTURELEASE="wily"


OLDCORE=( debootstrap_${UBUNTURELEASE}_*.tar.gz )
OLDCORE_LEN=${#OLDCORE[*]}
OLDCORE_LAST=${OLDCORE[$OLDCORE_LEN-1]}

if [ -f "$OLDCORE_LAST" ]; then
    echo -e -n "${GREENBOLD}Found a ${UBUNTURELEASE} core in ${OLDCORE_LAST}, unpacking it...${RST} " >&1 >&2
    mkdir "$ROOTFS"
    tar -xzpf "$OLDCORE_LAST" -C "$ROOTFS" || error
    echo -e "${GREENBOLD}done!${RST}"
    
    mountroot
    echo -e "${GREENBOLD}Installing updates from APT...${RST}" >&1 >&2
    chroot "$ROOTFS/" /bin/bash -c "apt update"
    chroot "$ROOTFS/" /bin/bash -c 'PATH=/fake:$PATH apt -y full-upgrade'
    
else
    echo -e "${GREENBOLD}Starting debootstrap...${RST}" >&1 >&2
    
    debootstrap  --foreign \
                 --arch=armhf \
                 --include=ubuntu-keyring,apt-transport-https,ca-certificates,openssl \
                 $UBUNTURELEASE "$ROOTFS" http://127.0.0.1:3142/ports.ubuntu.com

    (( $? )) && error "Debootstrap exited with error $?"
                 
    echo -e "${GREENBOLD}Configuring keyring...${RST}" >&1 >&2
    cp /usr/bin/qemu-arm-static "$ROOTFS/usr/bin"
    chroot "$ROOTFS/" /bin/bash -c "dpkg -i /var/cache/apt/archives/ubuntu-keyring*.deb"
    echo -e "${GREENBOLD}Resuming debootstrap...${RST}" >&1 >&2
    chroot "$ROOTFS/" /bin/bash -c "/debootstrap/debootstrap --second-stage"

    mountroot
    echo -e "${GREENBOLD}Disabling services...${RST}" >&1 >&2
    mkdir "$ROOTFS/fake"
    for i in initctl invoke-rc.d restart start stop start-stop-daemon service
    do
      ln -s /bin/true "$ROOTFS/fake/$i" || error "Cannot make link to /bin/true, stopping.."
    done

    echo -e "${GREENBOLD}Configuring APT repositories...${RST}" >&1 >&2
    install -m 644 patches/apt/01proxy           "$ROOTFS/etc/apt/apt.conf.d/01proxy"
    install -m 644 patches/apt/99progressbar     "$ROOTFS/etc/apt/apt.conf.d/99progressbar"
    install -m 644 patches/apt/90-xapt-periodic  "$ROOTFS/etc/apt/apt.conf.d/90-xapt-periodic"
    install -m 644 patches/apt/sources.list      "$ROOTFS/etc/apt/sources.list"
    install -m 644 patches/apt/udoo.list         "$ROOTFS/etc/apt/sources.list.d/udoo.list"
    install -m 644 patches/apt/nodejs.list       "$ROOTFS/etc/apt/sources.list.d/nodejs.list"
    install -m 644 patches/apt/udoo.preferences  "$ROOTFS/etc/apt/preferences.d/udoo"
    sed -e "s/UBUNTURELEASE/$UBUNTURELEASE/g" -i "$ROOTFS/etc/apt/sources.list"
    sed -e "s/UBUNTURELEASE/$UBUNTURELEASE/g" -i "$ROOTFS/etc/apt/sources.list.d/nodejs.list"

    echo -e "${GREENBOLD}Adding APT repositories keys...${RST}" >&1 >&2
    chroot "$ROOTFS/" /bin/bash -c "apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 40976EAF437D05B5" #ubuntu
    chroot "$ROOTFS/" /bin/bash -c "apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 3B4FE6ACC0B21F32" #ubuntu
    chroot "$ROOTFS/" /bin/bash -c "apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 1655A0AB68576280" #nodejs
    chroot "$ROOTFS/" /bin/bash -c "apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 71F0E740"         #udoo

    echo -e "${GREENBOLD}Updating APT repositories...${RST}" >&1 >&2
    chroot "$ROOTFS/" /bin/bash -c "apt update"

    echo -e "${GREENBOLD}Fixing packages and installing upgrades...${RST}" >&1 >&2
    chroot "$ROOTFS/" /bin/bash -c "apt -y -f install"
    chroot "$ROOTFS/" /bin/bash -c 'PATH=/fake:$PATH apt -y full-upgrade'

    echo -e "${GREENBOLD}Configuring locales...${RST}" >&1 >&2
    chroot "$ROOTFS/" /bin/bash -c 'PATH=/fake:$PATH apt -y install locales'
    chroot "$ROOTFS/" /bin/bash -c "locale-gen en_US.UTF-8 it_IT.UTF-8 en_GB.UTF-8"
    chroot "$ROOTFS/" /bin/bash -c "export LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8"
    chroot "$ROOTFS/" /bin/bash -c "export DEBIAN_FRONTEND=noninteractive"
    chroot "$ROOTFS/" /bin/bash -c "update-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_MESSAGES=POSIX"
    
    umountroot
    echo -e -n "${GREENBOLD}Board-indipendent debootstrap complete! Creating a backup... ${RST}" >&1 >&2
    tar -czpf "debootstrap_${UBUNTURELEASE}_$(date +%Y%m%d%H%M).tar.gz" -C "$ROOTFS" .
    echo -e "${GREENBOLD}done!${RST}" >&1 >&2
    mountroot
fi

echo -e "${GREENBOLD}Installing core packages...${RST}" >&1 >&2
chroot "$ROOTFS/" /bin/bash -c "PATH=/fake:$PATH DEBIAN_FRONTEND=noninteractive apt -y install --no-install-recommends ${BASE_PACKAGES[*]}"

if [ "$BUILD_DESKTOP" = "yes" ]; then
  echo -e "${GREENBOLD}Installing desktop packages...${RST}" >&1 >&2
  chroot "$ROOTFS/" /bin/bash -c "PATH=/fake:$PATH DEBIAN_FRONTEND=noninteractive apt -y install --no-install-recommends ${DESKTOP_PACKAGES[*]}"
fi

echo -e "${GREENBOLD}Removing unwanted packages...${RST}" >&1 >&2
chroot "$ROOTFS/" /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends purge ${UNWANTED_PACKAGES[*]}"

echo -e "${GREENBOLD}APT cleanup...${RST}" >&1 >&2
chroot "$ROOTFS/" /bin/bash -c 'PATH=/fake:$PATH apt-get autoremove -y'
chroot "$ROOTFS/" /bin/bash -c 'PATH=/fake:$PATH apt-get clean -y'
chroot "$ROOTFS/" /bin/bash -c 'PATH=/fake:$PATH apt-get autoclean -y'

echo -e "${GREENBOLD}Restoring services...${RST}" >&1 >&2
rm "$ROOTFS/etc/apt/apt.conf.d/01proxy"
rm -rf "$ROOTFS/fake"

umountroot

echo -e -n "${GREENBOLD}Debootstrap complete! Creating a backup tar... ${RST}" >&1 >&2
tar -czpf "${ROOTFS}_deboot_$(date +%Y%m%d%H%M).tar.gz" "$ROOTFS"
echo -e "${GREENBOLD}done!${RST}" >&1 >&2

set +e
