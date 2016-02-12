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

# Default wallpaper for lxde
#
# Available in udoo-artwork
# UDOO-blue
# UDOO-gray
# UDOO-green
# UDOO-pink

WALLPAPER_DEF=UDOO-blue

HOST_PACKAGES=( debootstrap qemu-user-static apt-cacher-ng rsync )

BASE_PACKAGES=( openssh-server alsa-utils bash-completion policykit-1
  bluez blueman curl dosfstools fbset iw nano module-init-tools ntp unzip usbutils 
  vlan wireless-tools wget wpasupplicant unicode-data console-data console-common 
  pv sysfsutils cpufrequtils ntfs-3g locate command-not-found man-db git i2c-tools 
  python-pip vim minicom crda manpages systemd-services systemd-shim wireless-regdb )

#UDOO related
BASE_PACKAGES+=( firmware-imx-9t fsl-alsa-plugins-9t imx-lib-9t imx-udev-fsl-rules 
  imx-vpu-9t libfslcodec-9t libfslparser-9t libfslvpuwrap-9t hostapd dtweb )

#dev library
BASE_PACKAGES+=( python-serial librxtx-java )

DESKTOP_PACKAGES=( evince transmission-gtk abiword file-roller libmtp-runtime 
  scratch eog geany bluefish pavucontrol udoo-artwork xinput-calibrator x11vnc
  matchbox-keyboard socat )

#lubuntu
DESKTOP_PACKAGES+=( lubuntu-core leafpad lxterminal galculator lxtask lxappearance 
  lxrandr lxshortcut lxinput lubuntu-software-center )

#xorg
DESKTOP_PACKAGES+=( imx-gpu-viv-10t7-acc-x11 xserver-xorg-core xserver-common
  xserver-xorg-dev libdrm-dev )

#dev
DESKTOP_PACKAGES+=( automake default-jdk )

#gstreamer
DESKTOP_PACKAGES+=( gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer-imx 
  gstreamer1.0-plugins-bad gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly 
  gstreamer1.0-alsa )

#chromium
DESKTOP_PACKAGES+=( chromium-browser chromium-browser-l10n chromium-chromedriver 
  chromium-codecs-ffmpeg-extra )

# from install recommends
DESKTOP_PACKAGES+=( alsa-base accountsservice avahi-daemon desktop-base 
dialog fonts-liberation gnome-bluetooth gnome-menus gnome-screensaver gnome-user-share
gvfs-fuse ibus ibus-gtk ibus-gtk3 iptables indicator-applet indicator-application 
indicator-bluetooth indicator-datetime indicator-keyboard indicator-messages 
indicator-power indicator-session indicator-sound mousetweaks network-manager 
network-manager-gnome obconf policykit-1-gnome pulseaudio 
pulseaudio-module-x11 pulseaudio-utils samba-common samba-common-bin sessioninstaller 
session-migration smbclient ssl-cert ubuntu-system-service update-inetd xfonts-scalable 
gnome-keyring zenity zenity-common update-manager )

UNWANTED_PACKAGES=( valgrind )

usage() {
 echo "./mkudoobuntu.sh [RECIPE [operation] [--force]]

    <none>        Select a recipe interactively
    RECIPE        Start debootstrapping a recipe

    --force       Don't ask 
    install       Install a deb in rootfs from repos
    remove        Remove a deb from rootfs
    list          List installed pkg in rootfs
    reimage       Make a new image from a modified rootfs
    configure     Reconfigure the rootfs
    shell         Open an interactive shell in a rootfs
 " 
}

GREEN="\e[32m"
BOLD="\e[1m"
RST="\e[0m"
GREENBOLD=${GREEN}${BOLD}

error() {
  #error($E_TEXT,$E_CODE)

  local E_TEXT=$1
  local E_CODE=$2
  
  [[ -z $E_CODE ]] && E_CODE=1
  [[ -z $E_TEXT ]] || echo $E_TEXT >&2
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

checkroot(){
  if [ $(id -u) -ne 0 ] 
  then
    error "You're not root! Try execute: sudo $0"
  fi
}

checkPackage(){
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

mountroot(){
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

umountroot(){
  checkroot
  for i in proc sys dev/pts dev 
  do
    if mountpoint -q "$ROOTFS/$i"
      then umount -lf "$ROOTFS/$i" || error "Cannot unmount \"$i\"" 
    fi
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
  chroot $ROOTFS/ /bin/bash -c "apt update"
#   for i in $@ 
#   do 
#     chroot $ROOTFS/ /bin/bash -c "apt-cache showpkg -q $i >/dev/null" || 
#       error "Package \"$i\" not found"         	 
#   done
  
  # apt-get install with more than one package is not working. why?
  
  for i in $@
  do
    chroot $ROOTFS/ /bin/bash -c "apt -y install $i" || error
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
  (( $# == 0 )) && chroot $ROOTFS/ /bin/bash -c "dpkg -l"
  for i in $@
  do
      chroot $ROOTFS/ /bin/bash -c "dpkg -l $i"
  done
  umountroot
}

destrapfull(){
  #check if rootfs exist
  local -i FORCE=0
  while (( $# ))
  do 
      case $1 in
          --force) shift; FORCE=1 ;;
          *) usagee "Option \"$1\" not recognized"  ;;
      esac
      shift
  done
    
  if [ -d "$ROOTFS" ]; then
    umountroot
  
    local -i FORCE=$1
    
    #delete old fs
    if (( $FORCE ))
       then rm -rf "$ROOTFS" || error
    else
        echo -n "Deleting old root filesystem, are you sure? (y/N) " >&2 >&1
        read CHOICE
    
        if [[ $CHOICE = [Yy] ]] ; then
            echo -n "Deleting... "
            rm -rf "$ROOTFS" || error
            echo -e "${GREENBOLD}Done!${RST}"
        else
            error
        fi
    fi
  fi
  
  #resume old debootstrap
  OLDDEB=( ${ROOTFS}_deboot*.tar.gz )
  OLDLEN=${#OLDDEB[*]}
  OLDLAS=${OLDDEB[$OLDLEN-1]}  ## last backup
 
  if [ -f "$OLDLAS" ] && (( ! $FORCE )) ; then
    echo -n "Found old debootstrap tar ($OLDLAS), use it?  (Y/n) " >&2 >&1
    read CHOICE
    
    if [[ $CHOICE != [Nn] ]] ; then
      echo -n "Extracting... "
      tar -xzpf "$OLDLAS" || error
      echo -e "${GREENBOLD}Done!${RST}"
    else
        source include/debootstrap.sh
    fi
  else
     source include/debootstrap.sh
  fi
    
  source include/configure.sh
  source include/imager.sh
}

## START


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
    
    destrapfull
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
    list) shift
        #list packages
        listdeb && ok
    ;;
    debootstrap)
        #configure
        source include/debootstrap.sh
        ok
    ;;
    configure)
        #configure
        source include/configure.sh
        ok
    ;;
    reimage) 
        source include/imager.sh
        ok
    ;;
    shell)
        chrootshell && ok
    ;;
    *)  
        #install from scratch
        
        checkroot
        
        destrapfull $@

        ok
    ;;
    esac
esac
    
