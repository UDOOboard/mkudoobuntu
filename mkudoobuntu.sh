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

RECIPES=recipes

HOST_PACKAGES=( debootstrap qemu-user-static apt-cacher-ng rsync )

DEBOOT_PACKAGES=( openssh-server debconf-utils alsa-utils bash-completion 
  bluez curl dosfstools fbset iw nano module-init-tools ntp screen unzip usbutils 
  vlan wireless-tools wget wpasupplicant unicode-data )

BASE_PACKAGES=( console-data console-common pv git sysfsutils cpufrequtils i2c-tools 
  hostapd ntfs-3g locate firmware-ralink imx-vpu-cnm-9t udev-udoo-rules command-not-found 
  kernel-package man-db )
  
DESKTOP_PACKAGES=( lubuntu-core leafpad lxterminal galculator lxtask lxappearance 
  lxrandr lxshortcut lxinput evince transmission-gtk abiword file-roller lubuntu-software-center 
  scratch eog geany bluefish pavucontrol udoo-artwork dpkg-dev imx-gpu-viv-9t6-acc-x11 
  chromium-browser chromium-browser-l10n chromium-chromedriver chromium-codecs-ffmpeg-extra chromium-egl 
  gstreamer0.10-tools gstreamer-tools gstreamer0.10-plugins-base gstreamer0.10-plugins-bad 
  gstreamer0.10-plugins-good gstreamer0.10-pulseaudio  
  xserver-xorg-core xserver-common libdrm-dev xserver-xorg-dev xvfb )

UNWANTED_PACKAGES=( apport apport-symptoms python3-apport colord hplip libsane 
  libsane-common libsane-hpaio printer-driver-postscript-hp sane-utils modemmanager )

usage() {
 echo "./mkudoobuntu.sh [RECIPE [operation]]

    <none>        Select a recipe interactively
    RECIPE        Start debootstrapping a recipe

    install       Install a deb in rootfs from repos
    remove        Remove a deb from rootfs
    list          List installed pkg in rootfs
    reimage       Make a new image from a modified rootfs
    chrootshell   Open an interactive shell in a rootfs
 " 
}
  
error() {
  #error($E_TEXT,$E_CODE)

  local E_TEXT=$1
  local E_CODE=$2
  
  [[ -z $E_CODE ]] && E_CODE=1
  [[ -z $E_TEXT ]] || echo $E_TEXT
  exit $E_CODE
}

ok() {
  #ok($OK_TEXT)
  local OK_TEXT=$1
  [[ -z $OK_TEXT ]] && OK_TEXT="Success!!"
  [[ -z $OK_TEXT ]] || echo $OK_TEXT 
  exit 0
}

usagee(){
  usage
  error "$1" "$2"
}

checkPackage(){
  declare -a PACKAGES
  for i in $@
    do
      dpkg -l "$i" > /dev/null
      if [[ $? != 0 ]]
      then
        echo "Package ${i} is not installed. We need to grab it"
        PACKAGES+=( "$i" )
      fi
  done
  
  if [[ $PACKAGES != "" ]] 
  then
    checkroot
    apt-get install ${PACKAGES[*]}
  fi

}

mountroot(){
  if [ -z "$ROOTFS" ] && [ "$ROOTFS" = "/"  ]
  then
    error "Rootfs variable not defined. Check the recipe"
  fi

  for i in proc sys dev dev/pts
  do 
    [  -d "$ROOTFS/$i" ] || error "Rootfs not present/not populated ($ROOTFS/$i) "
  done
  checkroot
  mount -t proc chproc $ROOTFS/proc
  mount -t sysfs chsys $ROOTFS/sys
  mount -t devtmpfs chdev $ROOTFS/dev || mount --bind /dev $ROOTFS/dev
  mount -t devpts chpts $ROOTFS/dev/pts
}

umountroot(){
  checkroot
  for i in proc sys dev/pts dev 
  do
    [ -d "$ROOTFS/$i" ] && umount -lf $ROOTFS/$i
  done
}

chrootshell(){
  mountroot
  chroot $ROOTFS/ /bin/bash
  umountroot
}

installdeb(){
  (( $# )) || error "Specify packages to install"
  
  mountroot
  chroot $ROOTFS/ /bin/bash -c "apt-get update -y"
#   for i in $@ 
#   do 
#     chroot $ROOTFS/ /bin/bash -c "apt-cache showpkg -q $i >/dev/null" || 
#       error "Package \"$i\" not found"         	 
#   done
  
  # apt-get install with more than one package is not working. why?
  
  for i in $@
  do
    chroot $ROOTFS/ /bin/bash -c "apt-get install -y $i" || error
  done
  chroot $ROOTFS/ /bin/bash -c "apt-get clean -y"
  umountroot
}

removedeb(){
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

listdeb(){
  mountroot
  for i in $@
  do
      chroot $ROOTFS/ /bin/bash -c "dpkg -l $i"
  done
  umountroot
}
checkroot(){
  if [ $(id -u) -ne 0 ] 
  then
    error "You're not root! Try execute: sudo $0"
  fi
}

## START

checkPackage $HOST_PACKAGES

#no args
(( $# )) || {
  echo "Pick a building recipe:"
  select RECIPE in $RECIPES/*.conf
  do
    [[ $RECIPE == "" ]] && error "You have to pick a recipe!" 
    [ -e "$RECIPE" ] || error "Cannot find \"$1\" recipe"
    
    echo -n "You picked \"$RECIPE\", starting debootstrapping? (Y/n) "
    read CHOICE
    [[ $CHOICE =~ "n" ]] && exit 0
    
    #compile
    source $RECIPE
    checkroot
    source include/debootstrap.sh
    source include/configure.sh
    source include/imager.sh
    ok
  done
}
    
(( $# )) && case $1 in
*help|*usage) 
    usage
    exit 0
    ;;
*)
    [ -e "$RECIPES/$1.conf" ] || usagee "Cannot find \"$1\" recipe"
    source $RECIPES/"$1".conf
    
    shift
    
    #other argument
    
    case $1 in
    
    install) shift
        #install other packages
        installdeb $@ && ok
    ;;
    remove) shift
        #remove packages
        removedeb $@ && ok
    ;;
    list)
        #list packages
        listdeb && ok
    ;;
    reimage) 
        source include/imager.sh
        ok
    ;;
    chrootshell)
        chrootshell && ok
    ;;
    *)  
        #install from scratch
        (( $# )) && usage && error "Option \"$1\" not recognized" 
        
        checkroot
        source include/debootstrap.sh
        source include/configure.sh
        source include/imager.sh
        ok
    ;;
    esac
esac
    