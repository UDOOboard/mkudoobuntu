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

HOST_PACKAGES=( debootstrap qemu-user-static apt-cacher-ng rsync )

BASE_PACKAGES=( bash-completion unicode-data console-data console-common
  openssh-server nano wget unzip zip ntp udoo-autostart
  iw wireless-tools wpasupplicant crda wireless-regdb
  udoo-firstrun udoo-gpio-export firmware-imx-12x imx-lib-12x imx-udev-rules-x12 )

PACKAGES_micro=( )

PACKAGES_minimal=( alsa-utils curl dosfstools fbset locate man-db hostapd policykit-1 vlan
  vim usbutils sysfsutils cpufrequtils manpages )

# VPU/Common
PACKAGES_minimal+=( imx-codec-12x imx-parser-12x imx-vpuwrap-12x imx-alsa-plugins-12x
  imx-vpu-12x imx-vpu-cnm-12x )

# Base and development libraries
PACKAGES_minimal+=( python-pip python-serial automake git minicom
   ntfs-3g i2c-tools pv bluez )

# Desktop
PACKAGES_desktop=( xserver-xorg xserver-xorg-core xserver-common
  lightdm lightdm-gtk-greeter
  imx-gpu-viv-x12-acc-x11 dpkg-dev
  mate-desktop-environment-core
  ubuntu-mate-themes mate-system-monitor mate-applets mate-tweak mate-media dmz-cursor-theme

  gnome-system-tools network-manager network-manager-gnome pulseaudio
  caja-gksu engrampa eom pluma galculator geany socat
  udoo-artwork xinput-calibrator xterm x11vnc dtweb
  gir1.2-secret-1 gnome-keyring

  onboard python3-pyatspi gir1.2-appindicator3-0.1 # on screen keyboard
  alsa-base dialog zenity zenity-common gvfs-fuse ibus iptables mousetweaks )

# gstreamer
PACKAGES_desktop+=( gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer-imx-x11
  gstreamer1.0-plugins-bad gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly
  gstreamer1.0-alsa )

# chromium
PACKAGES_desktop+=( chromium-browser chromium-codecs-ffmpeg-extra )

UNWANTED_PACKAGES=( valgrind )

usage() {
 echo "To debootstrap a new unnamed image, use:
    sudo ./mkudoobuntu.sh <board> <flavour>

Branded-release images can be generated with:
    sudo RELEASE=\"2.0 Beta6\" ./mkudoobuntu.sh <board> <flavour>

To edit a previously debootstrapped rootfs, use:
    sudo ./mkudoobuntu.sh <board> <operation>

<board> can be: udoo-qdl, udoo-neo.

<operation> can be:
    install       Install a deb in rootfs from repos
    remove        Remove a deb from rootfs
    list          List installed pkg in rootfs
    reimage       Make a new image from a modified rootfs
    shell         Open an interactive shell in a rootfs
 " 
}

GREEN="\e[32m"
RED="\e[31m"
BOLD="\e[1m"
RST="\e[0m"
GREENBOLD=${GREEN}${BOLD}

error() {
  local E_TEXT=$1
  local E_CODE=$2
  
  [[ -z $E_CODE ]] && E_CODE=1
  [[ -z $E_TEXT ]] || echo -e $E_TEXT >&2
  exit $E_CODE
}

ok() {
  local OK_TEXT=$1
  [[ -z $OK_TEXT ]] && OK_TEXT="Success!!"
  [[ -z $OK_TEXT ]] || echo $OK_TEXT 
  exit 0
}

usageerror() {
  usage
  error "${RED}${BOLD}$1${RST}" "$2"
}

checkroot() {
  if [ $(id -u) -ne 0 ]
  then
    error "You're not root! Try execute: sudo $0"
  fi
}

checkversions() {
  VERSION=`dpkg-query --show --showformat '${Version}' qemu-user-static`
  if dpkg --compare-versions $VERSION lt 1:2.8 ; then
    echo "WARNING: qemu version must be at least 2.8!"
  fi
}

checkPackage() {
  declare -a PACKAGES
  for i in ${HOST_PACKAGES[*]}
    do
      dpkg -l "$i" > /dev/null
      if [[ $? != 0 ]]
      then
        echo "Package ${i} is not installed. We need to grab it"
        PACKAGES+=( "$i" )
      fi
  done
  
  if (( ${#PACKAGES[*]} ))
  then
    checkroot
    apt-get install ${PACKAGES[*]}
  fi
}
checkPackage $HOST_PACKAGES

mountroot() {
  if [ -z "$ROOTFS" ] && [ "$ROOTFS" = "/"  ]
  then
    error "Rootfs variable not defined. Check the recipe"
  fi

  for i in proc sys dev dev/pts
  do 
    [  -d "$ROOTFS/$i" ] || error "Rootfs not present/not populated ($ROOTFS/$i)"
    mountpoint -q "$ROOTFS/$i" && umount -lf "$ROOTFS/$i"
  done
  checkroot
  mount -t proc chproc "$ROOTFS/proc"
  mount -t sysfs chsys "$ROOTFS/sys"
  mount -t devtmpfs chdev "$ROOTFS/dev" || mount --bind /dev "$ROOTFS/dev"
  mount -t devpts chpts "$ROOTFS/dev/pts"
}

umountroot() {
  checkroot
  for i in proc sys dev/pts dev 
  do
    if mountpoint -q "$ROOTFS/$i"
      then umount -lf "$ROOTFS/$i" || error "Cannot unmount \"$i\"" 
    fi
  done
}

chrootshell() {
  mountroot
  chroot $ROOTFS/ /bin/bash
  umountroot
}

installdeb() {
  (( $# )) || error "Specify packages to install"
  
  mountroot
  chroot $ROOTFS/ /bin/bash -c "apt update"
  
  for i in $@
  do
    chroot $ROOTFS/ /bin/bash -c "apt -y install $i" || error
  done
  chroot $ROOTFS/ /bin/bash -c "apt-get clean -y"
  umountroot
}

removedeb() {
  (( $# )) || error "Specify packages to uninstall"
  mountroot
  for i in $@ 
  do
    chroot $ROOTFS/ /bin/bash -c "dpkg -l $i" || 
      error "Package \"$i\" not found" 
  done
  chroot $ROOTFS/ /bin/bash -c "apt-get remove -y $@"
  umountroot
}

listdeb() {
  mountroot
  (( $# == 0 )) && chroot $ROOTFS/ /bin/bash -c "dpkg -l"
  for i in $@
  do
      chroot $ROOTFS/ /bin/bash -c "dpkg -l $i"
  done
  umountroot
}

debootstrapfull() {
  validRecipe=false
  for flavour in "${FLAVOURS[@]}"; do
    if [ "$flavour" == "$1" ] ; then
      validRecipe=true
    fi
  done

  if ! $validRecipe ; then
    usageerror "Invalid flavour/argument: $1! Valid flavours for $BOARD are: ${FLAVOURS[*]}."
  fi
  FLAVOUR=$1

  #check if rootfs exist
  if [ -d "$ROOTFS" ]; then
    umountroot
  
    #delete old fs
    echo -n "Deleting old root filesystem $ROOTFS/ in 5 seconds... "
    sleep 5
    rm -rf "$ROOTFS" || error
    echo -e "${GREENBOLD}done!${RST}"
  fi
  
  source include/debootstrap.sh
  source include/configure.sh
  source include/imager.sh
}

## START

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ] ; then
    usage
    exit 1
fi
    
case $1 in
    *help|*usage) 
        usage
        exit 0
        ;;
    *)
        [ -e "boards/$1/board.conf" ] || usageerror "Cannot find \"$1\" board definition."
        source boards/$1/board.conf
        BOARD=$1
        ROOTFS=$1

	PACKAGES_minimal=(${PACKAGES_minimal[*]} ${PACKAGES_micro[*]})
	PACKAGES_desktop=(${PACKAGES_desktop[*]} ${PACKAGES_minimal[*]})

        shift
        #other argument
        case $1 in
            install) shift
                installdeb $@ && ok
            ;;
            remove) shift
                removedeb $@ && ok
            ;;
            list) shift
                listdeb && ok
            ;;
            reimage)
                source include/imager.sh
                ok
            ;;
            shell)
                chrootshell && ok
            ;;
            *)
                checkroot
                checkversions
                debootstrapfull $@
                ok
            ;;
        esac
esac

