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
mountroot

package_installed() {
	chroot "$ROOTFS/" /bin/bash -c "dpkg -l |grep $1 > /dev/null 2>&1"
	return $?
}

echo -e "${GREENBOLD}Configuring system...${RST}" >&1 >&2

# configure console
echo -e "${GREENBOLD}Configuring console...${RST}" >&1 >&2
install -m 744 patches/ttymxc0.conf "$ROOTFS/etc/init/ttymxc0.conf"
install -m 744 patches/ttymxc1.conf "$ROOTFS/etc/init/ttymxc1.conf"
install -m 744 patches/ttyGS0.conf "$ROOTFS/etc/init/ttyGS0.conf"
rm -f "$ROOTFS/etc/init/tty3.conf"
rm -f "$ROOTFS/etc/init/tty4.conf"
rm -f "$ROOTFS/etc/init/tty5.conf"
rm -f "$ROOTFS/etc/init/tty6.conf"

# disable root login
sed -i 's/PermitRootLogin without-password/PermitRootLogin no/' "$ROOTFS/etc/ssh/sshd_config"
echo manual > "$ROOTFS/etc/init/ssh.override"

# fix selinux
mkdir -p "$ROOTFS/selinux"

# remove what's anyway not working
rm -f "$ROOTFS/etc/init/ureadahead"*
rm -f "$ROOTFS/etc/init/plymouth"*

if [ "$BOARD" = "udoo-neo" ]; then
	#enable otg gadget
	install -m 744 patches/g_multi.sh "$ROOTFS/usr/sbin/g_multi.sh"
	install -m 744 patches/g_multi.conf "$ROOTFS/etc/init/g_multi.conf"
fi

install -m 755 patches/rc.local "$ROOTFS/etc/rc.local"
install -m 644 patches/fstab "$ROOTFS/etc/fstab"

# setup users
echo -e "${GREENBOLD}Setting users...${RST}" >&1 >&2
chroot "$ROOTFS/" /bin/bash -c "echo root:$ROOTPWD | chpasswd"
if package_installed "x11vnc"; then
	chroot "$ROOTFS/" /bin/bash -c "x11vnc -storepasswd $USERNAMEPWD /etc/x11vnc.pass"
	chroot "$ROOTFS/" /bin/bash -c "useradd -U -m -G sudo,video,audio,adm,dip,plugdev,fuse,dialout $USERNAMEPWD"
else
	chroot "$ROOTFS/" /bin/bash -c "useradd -U -m -G sudo,adm,dip,plugdev,dialout $USERNAMEPWD"
fi
chroot "$ROOTFS/" /bin/bash -c "echo $USERNAMEPWD:$USERNAMEPWD | chpasswd"
chroot "$ROOTFS/" /bin/bash -c "chsh -s /bin/bash $USERNAMEPWD"

if package_installed "xserver-xorg-core"; then
	echo -e "${GREENBOLD}Configuring desktop...${RST}" >&1 >&2
	
	# touchscreen conf
	install -m 755 -d "$ROOTFS/etc/X11/xorg.conf.d/"
	install -m 744 patches/90-st1232touchscreen.conf "$ROOTFS/etc/X11/xorg.conf.d/"
	install -m 744 patches/91-3m_touchscreen.conf "$ROOTFS/etc/X11/xorg.conf.d/"

	#fix autostart https://bugs.launchpad.net/ubuntu/+source/lightdm/+bug/1188131
	sed -i 's/and plymouth-ready//' "$ROOTFS/etc/init/lightdm.conf"
	echo manual > "$ROOTFS/etc/init/lightdm.override"
	mkdir "$ROOTFS/etc/lightdm/lightdm.conf.d"
	install -m 644 patches/autologin.lightdm "$ROOTFS/etc/lightdm/lightdm.conf.d/10-autologin.conf"
	install -m 644 patches/x11vnc.conf "$ROOTFS/etc/init/x11vnc.conf"
	sed -e "s/USERNAMEPWD/$USERNAMEPWD/g" -i "$ROOTFS/etc/lightdm/lightdm.conf.d/10-autologin.conf"
	install -m 644 patches/autologin.accountservice "$ROOTFS/var/lib/AccountsService/users/$USERNAMEPWD"

	#wallpaper
	WALLPAPER_OLD="/usr/share/lubuntu/wallpapers/lubuntu-default-wallpaper.png"
	WALLPAPER_NEW="/usr/share/wallpapers/udoo"

    #check valid wallpaper
	if [[ -n $WALLPAPER ]] && [[ ! -f "$ROOTFS/$WALLPAPER_NEW/$WALLPAPER.png" ]] 
    then
        echo -e "Cannot find wallpaper $WALLPAPER"
        unset WALLPAPER
    fi
	WALLPAPER_NEW+=/${WALLPAPER:-$WALLPAPER_DEF}.png
	sed -e "s|$WALLPAPER_OLD|$WALLPAPER_NEW|" -i "$ROOTFS/etc/xdg/pcmanfm/lubuntu/pcmanfm.conf"

	#desktop icons
	install -m 755 -o 1000 -g 1000 -d \
	  "$ROOTFS/home/$USERNAMEPWD/Desktop"

	install -m 644 -o 1000 \
    "$ROOTFS/usr/share/applications/lxterminal.desktop" "$ROOTFS/home/$USERNAMEPWD/Desktop/"
	install -m 644 -o 1000 \
    "$ROOTFS/usr/share/applications/arduino.desktop" "$ROOTFS/home/$USERNAMEPWD/Desktop/"
	install -m 644 -o 1000 \
		"$ROOTFS/usr/share/applications/inputmethods/matchbox-keyboard.desktop" \
		"$ROOTFS/home/$USERNAMEPWD/Desktop/"

	chroot "$ROOTFS/" /bin/bash -c "update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/chromium-egl 50"
	chroot "$ROOTFS/" /bin/bash -c "update-alternatives --set  x-www-browser /usr/bin/chromium-egl"

	chroot "$ROOTFS/" /bin/bash -c "chown $USERNAMEPWD:$USERNAMEPWD /home/$USERNAMEPWD/Desktop/*"

	if [ "$HOSTNAME" = "udooneo" ]; then
		install -m 644 patches/neo-audio/asound.conf "$ROOTFS/etc/asound.conf"
		install -m 644 patches/neo-audio/asound.state "$ROOTFS/var/lib/alsa/asound.state"
	fi
fi

echo -e "${GREENBOLD}Installing first boot service...${RST}" >&1 >&2
install -m 755 patches/firstrun  "$ROOTFS/etc/init.d"
chroot "$ROOTFS/" /bin/bash -c "update-rc.d firstrun defaults 2>&1 >/dev/null"

# configure MIN / MAX speed for cpufrequtils
sed -e "s/MIN_SPEED=\"0\"/MIN_SPEED=\"$CPUMIN\"/g" -i "$ROOTFS/etc/init.d/cpufrequtils"
sed -e "s/MAX_SPEED=\"0\"/MAX_SPEED=\"$CPUMAX\"/g" -i "$ROOTFS/etc/init.d/cpufrequtils"

# configure bash: reverse search and shell completion
echo -e "${GREENBOLD}Configuring shell...${RST}" >&1 >&2
sed -e 's/# "\\e\[5~": history\-search\-backward/"\\e[5~": history-search-backward/' -i "$ROOTFS/etc/inputrc"
sed -e 's/# "\\e\[6~": history\-search\-forward/"\\e[6~": history-search-forward/' -i "$ROOTFS/etc/inputrc"
sed -e '/#if ! shopt -oq posix/,+6s/#//' -i "$ROOTFS/etc/bash.bashrc"
echo "alias grep='grep --color=auto'" >> "$ROOTFS/etc/bash.bashrc"
echo "alias ls='ls --color=auto'" >> "$ROOTFS/etc/bash.bashrc"

# set hostname
echo $HOSTNAME > "$ROOTFS/etc/hostname"

if [ -n "$RELEASE" ]; then
cat << ISSUE > "$ROOTFS/etc/issue"
UDOObuntu v$RELEASE

default username:password is [$USERNAMEPWD:$USERNAMEPWD]
ISSUE
else
cat << ISSUE >> "$ROOTFS/etc/issue" 

default username:password is [$USERNAMEPWD:$USERNAMEPWD]
ISSUE
fi

echo -e "${GREENBOLD}Configuring network...${RST}" >&1 >&2
install -m 644 patches/network-interfaces "$ROOTFS/etc/network/interfaces"
install -m 644 patches/hosts "$ROOTFS/etc/hosts"
sed -e "s/THISHOST/$HOSTNAME/g" -i "$ROOTFS/etc/hosts"

cp boards/$BOARD/uEnv.txt $ROOTFS/boot/uEnv.txt

if package_installed "update-manager"; then
	# remove updates from motd and autostart
	rm "$ROOTFS/etc/xdg/autostart/update-notifier.desktop"
	rm "$ROOTFS/etc/update-motd.d/90-updates-available"
	rm "$ROOTFS/etc/update-motd.d/91-release-upgrade"
	rm "$ROOTFS/etc/update-motd.d/98-reboot-required"
	chroot "$ROOTFS/" /bin/bash -c "run-parts /etc/update-motd.d/"
fi

# set documentation link
install -m 755 patches/10-help-text "$ROOTFS/etc/update-motd.d/10-help-text"
chroot "$ROOTFS/" /bin/bash -c "run-parts /etc/update-motd.d/"

umountroot
