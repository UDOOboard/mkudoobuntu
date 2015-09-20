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

echo -e "Configuring system" >&2 >&1
# kernel packaging configuration
cp patches/kernel-img.conf "$ROOTFS/etc/"

# st1232 touchscreen conf
mkdir "$ROOTFS/etc/X11/xorg.conf.d/"
cp patches/90-st1232touchscreen.conf "$ROOTFS/etc/X11/xorg.conf.d/"
cp patches/91-3m_touchscreen.conf "$ROOTFS/etc/X11/xorg.conf.d/"

# configure console
cp patches/ttymxc0.conf "$ROOTFS/etc/init/ttymxc0.conf"
cp patches/ttymxc1.conf "$ROOTFS/etc/init/ttymxc1.conf"
rm "$ROOTFS/etc/init/tty3.conf"
rm "$ROOTFS/etc/init/tty4.conf"
rm "$ROOTFS/etc/init/tty5.conf"
rm "$ROOTFS/etc/init/tty6.conf"

# enable root login
sed -i 's/PermitRootLogin without-password/PermitRootLogin no/' "$ROOTFS/etc/ssh/sshd_config"
echo manual > "$ROOTFS/etc/init/ssh.override"

# fix selinux
mkdir "$ROOTFS/selinux"

# remove what's anyway not working
rm "$ROOTFS/etc/init/ureadahead*"
rm "$ROOTFS/etc/init/plymouth*"



if [ "$BUILD_DESKTOP" = "yes" ]; then
	echo -e "Configuring desktop" >&2 >&1
	#fix autostart https://bugs.launchpad.net/ubuntu/+source/lightdm/+bug/1188131
	sed -i 's/and plymouth-ready//' "$ROOTFS/etc/init/lightdm.conf"
	echo manual > "$ROOTFS/etc/init/lightdm.override"
	mkdir "$ROOTFS/etc/lightdm/lightdm.conf.d"
	install -m 644 patches/autologin.lightdm "$ROOTFS/etc/lightdm/lightdm.conf.d/10-autologin.conf"
	install -m 644 patches/vncserver.lightdm "$ROOTFS/etc/lightdm/lightdm.conf.d/12-vncserver.conf"
	sed -e "s/USERNAMEPWD/$USERNAMEPWD/g" -i "$ROOTFS/etc/lightdm/lightdm.conf.d/10-autologin.conf"
	install -m 644 patches/autologin.accountservice "$ROOTFS/var/lib/AccountsService/users/$USERNAMEPWD"

	#wallpaper
	WALLPAPER_OLD="$ROOTFS/usr/share/lubuntu/wallpapers/lubuntu-default-wallpaper.png"
	WALLPAPER_NEW="$ROOTFS/usr/share/udoo/wallpapers"

	[[ -f $WALLPAPER_NEW/$WALLPAPER.png ]] || unset $WALLPAPER
	WALLPAPER_NEW+=/${WALLPAPER:-UDOO-blue}.png

	sed -e "s|$WALLPAPER_OLD|$WALLPAPER_NEW|" -i "$ROOTFS/etc/xdg/pcmanfm/lubuntu/pcmanfm.conf"
fi

echo "UTC" > "$ROOTFS/etc/timezone"
chroot "$ROOTFS/" /bin/bash -c "dpkg-reconfigure -f noninteractive tzdata 2>&1 >/dev/null"

# setup users
chroot "$ROOTFS/" /bin/bash -c "echo root:$ROOTPWD | chpasswd"
if [ "$BUILD_DESKTOP" = "yes" ]; then
  chroot "$ROOTFS/" /bin/bash -c "echo $USERNAMEPWD | vncpasswd -f > /etc/vncpasswd"
	chroot "$ROOTFS/" /bin/bash -c "useradd -U -m -G sudo,video,audio,adm,dip,plugdev,fuse,dialout $USERNAMEPWD"
else
	chroot "$ROOTFS/" /bin/bash -c "useradd -U -m -G sudo,adm,dip,plugdev,dialout $USERNAMEPWD"
fi
chroot "$ROOTFS/" /bin/bash -c "echo $USERNAMEPWD:$USERNAMEPWD | chpasswd"
chroot "$ROOTFS/" /bin/bash -c "chsh -s /bin/bash $USERNAMEPWD"

# configure fstab
install -m 644 patches/fstab "$ROOTFS/etc/fstab"

# first boot services
install -m 755 patches/firstrun  "$ROOTFS/etc/init.d"
chroot "$ROOTFS/" /bin/bash -c "update-rc.d firstrun defaults 2>&1 >/dev/null"

# configure MIN / MAX speed for cpufrequtils
sed -e "s/MIN_SPEED=\"0\"/MIN_SPEED=\"$CPUMIN\"/g" -i "$ROOTFS/etc/init.d/cpufrequtils"
sed -e "s/MAX_SPEED=\"0\"/MAX_SPEED=\"$CPUMAX\"/g" -i "$ROOTFS/etc/init.d/cpufrequtils"

# configure bash: reverse search and shell completion
sed -e 's/# "\\e\[5~": history\-search\-backward/"\\e[5~": history-search-backward/' -i "$ROOTFS/etc/inputrc"
sed -e 's/# "\\e\[6~": history\-search\-forward/"\\e[6~": history-search-forward/' -i "$ROOTFS/etc/inputrc"
sed -e '/#if ! shopt -oq posix/,+6s/#//' -i "$ROOTFS/etc/bash.bashrc"

# set hostname
echo $HOSTNAME > "$ROOTFS/etc/hostname"
echo "default username:password is [$USERNAMEPWD:$USERNAMEPWD]" >> "$ROOTFS/etc/issue"

echo -e "Configuring network"
install -m 644 patches/network-interfaces "$ROOTFS/etc/network/interfaces"
install -m 644 patches/hosts "$ROOTFS/etc/hosts"
sed -e "s/THISHOST/$HOSTNAME/g" -i "$ROOTFS/etc/hosts"

if [ -n "$ENV" ]
	then
	echo -e "Creating uEnv"
	cat << EOF > "$ROOTFS/boot/uEnv.txt"
$UENV
EOF
fi
