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

# disable root login
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin no/' "$ROOTFS/etc/ssh/sshd_config"

# fix selinux
mkdir -p "$ROOTFS/selinux"

# remove startup services
chroot "$ROOTFS/" /bin/bash -c "systemctl disable ureadahead.service"
chroot "$ROOTFS/" /bin/bash -c "systemctl disable NetworkManager-wait-online.service"
chroot "$ROOTFS/" /bin/bash -c "systemctl disable sys-kernel-debug.mount"
chroot "$ROOTFS/" /bin/bash -c "systemctl disable isc-dhcp-server6.service"

# fstab
install -m 644 patches/fstab "$ROOTFS/etc/fstab"

# setup users
echo -e "${GREENBOLD}Setting users...${RST}" >&1 >&2
chroot "$ROOTFS/" /bin/bash -c "echo root:$ROOTPWD | chpasswd"
if package_installed "x11vnc"; then
	chroot "$ROOTFS/" /bin/bash -c "x11vnc -storepasswd $USERNAMEPWD /etc/x11vnc.pass"
	chroot "$ROOTFS/" /bin/bash -c "useradd -U -m -G sudo,video,audio,adm,dip,plugdev,dialout $USERNAMEPWD" #fuse
else
	chroot "$ROOTFS/" /bin/bash -c "useradd -U -m -G sudo,adm,dip,plugdev,dialout $USERNAMEPWD"
fi
chroot "$ROOTFS/" /bin/bash -c "echo $USERNAMEPWD:$USERNAMEPWD | chpasswd"
chroot "$ROOTFS/" /bin/bash -c "chsh -s /bin/bash $USERNAMEPWD"

if package_installed "xserver-xorg-core"; then
	echo -e "${GREENBOLD}Configuring desktop...${RST}" >&1 >&2

	# touchscreen conf
	install -D -m 744 patches/90-st1232touchscreen.conf "$ROOTFS/etc/X11/xorg.conf.d/90-st1232touchscreen.conf"
	install -D -m 744 patches/91-3m_touchscreen.conf "$ROOTFS/etc/X11/xorg.conf.d/91-3m_touchscreen.conf"

	# autologin
	install -D -m 644 patches/autologin.lightdm "$ROOTFS/etc/xdg/lightdm/lightdm.conf.d/10-autologin.conf"
	sed -e "s/USERNAMEPWD/$USERNAMEPWD/g" -i "$ROOTFS/etc/xdg/lightdm/lightdm.conf.d/10-autologin.conf"

	# desktop settings
	install -D -m 644 patches/dconf/user "$ROOTFS/etc/dconf/profile/user"
	install -D -m 644 patches/dconf/udoo "$ROOTFS/etc/dconf/db/local.d/udoo"
	chroot "$ROOTFS/" /bin/bash -c "dconf update"

	#desktop icons
	#install -m 755 -o 1000 -g 1000 -d "$ROOTFS/home/$USERNAMEPWD/Desktop"
	#for APP in lxterminal arduino inputmethods/matchbox-keyboard update-manager; do
	#	install -m 644 -o 1000 "$ROOTFS/usr/share/applications/$APP.desktop" "$ROOTFS/home/$USERNAMEPWD/Desktop/"
	#done
	#chroot "$ROOTFS/" /bin/bash -c "chown $USERNAMEPWD:$USERNAMEPWD /home/$USERNAMEPWD/Desktop/*"

	# ugly hack, remove me!
	chroot "$ROOTFS/" /bin/bash -c "ln -sf /usr/lib/jni/arm-linux-gnueabihf/libastylej.so /usr/share/arduino/lib/libastylej.so"

	if [ "$HOSTNAME" = "udooneo" ]; then
		install -m 644 patches/neo-audio/asound.conf "$ROOTFS/etc/asound.conf"
		install -m 644 patches/neo-audio/asound.state "$ROOTFS/var/lib/alsa/asound.state"
	fi
fi

# configure MIN / MAX speed for cpufrequtils
sed -e "s/MIN_SPEED=\"0\"/MIN_SPEED=\"392000\"/g" -i "$ROOTFS/etc/init.d/cpufrequtils"
sed -e "s/MAX_SPEED=\"0\"/MAX_SPEED=\"996000\"/g" -i "$ROOTFS/etc/init.d/cpufrequtils"

# configure bash: reverse search and shell completion
echo -e "${GREENBOLD}Configuring shell...${RST}" >&1 >&2
sed -e 's/# "\\e\[5~": history\-search\-backward/"\\e[5~": history-search-backward/' -i "$ROOTFS/etc/inputrc"
sed -e 's/# "\\e\[6~": history\-search\-forward/"\\e[6~": history-search-forward/' -i "$ROOTFS/etc/inputrc"
sed -e '/#if ! shopt -oq posix/,+6s/#//' -i "$ROOTFS/etc/bash.bashrc"
echo "alias grep='grep --color=auto'" >> "$ROOTFS/etc/bash.bashrc"
echo "alias ls='ls --color=auto'" >> "$ROOTFS/etc/bash.bashrc"
echo 'PS1="\[\e[01;31m\]$PS1\[\e[00m\]"' >> "$ROOTFS/root/.bashrc"

# set hostname
echo $HOSTNAME > "$ROOTFS/etc/hostname"

if [ -n "$RELEASE" ]; then
cat << ISSUE > "$ROOTFS/etc/issue"
UDOObuntu $RELEASE

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

cp boards/$BOARD/uEnv.txt $ROOTFS/otgstorage/uEnv.txt
chroot "$ROOTFS/" /bin/bash -c "ln -s /otgstorage/uEnv.txt /boot/uEnv.txt"

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
