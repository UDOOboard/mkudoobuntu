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


echo -e "Configuring system"
# configure console
cp patches/ttymxc1.conf rootfs/etc/init/ttymxc1.conf
rm rootfs/etc/init/tty3.conf
rm rootfs/etc/init/tty4.conf
rm rootfs/etc/init/tty5.conf
rm rootfs/etc/init/tty6.conf

# enable root login
sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' rootfs/etc/ssh/sshd_config
echo manual > rootfs/etc/init/ssh.override

# fix selinux
mkdir rootfs/selinux

# remove what's anyway not working
rm rootfs/etc/init/ureadahead*
rm rootfs/etc/init/plymouth*

if [ "$BUILD_DESKTOP" = "yes" ]; then
	echo -e "Configuring desktop"
	#fix autostart https://bugs.launchpad.net/ubuntu/+source/lightdm/+bug/1188131
	sed -i 's/and plymouth-ready//' rootfs/etc/init/lightdm.conf
	echo manual > rootfs/etc/init/lightdm.override
	mkdir rootfs/etc/lightdm/lightdm.conf.d
	install -m 644 patches/autologin.lightdm rootfs/etc/lightdm/lightdm.conf.d/10-autologin.conf
	sed -e "s/USERNAMEPWD/$USERNAMEPWD/g" -i rootfs/etc/lightdm/lightdm.conf.d/10-autologin.conf
	install -m 644 patches/autologin.accountservice rootfs/var/lib/AccountsService/users/$USERNAMEPWD
	sed -e "s/\/usr\/share\/lubuntu\/wallpapers\/lubuntu-default-wallpaper\.png/\/usr\/share\/udoo\/wallpapers\/UDOO-blue.png/" -i rootfs/etc/xdg/pcmanfm/lubuntu/pcmanfm.conf
fi

echo "UTC" > rootfs/etc/timezone
chroot rootfs/ /bin/bash -c "dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1"

# setup users
chroot rootfs/ /bin/bash -c "echo root:$ROOTPWD | chpasswd"
if [ "$BUILD_DESKTOP" = "yes" ]; then
	chroot rootfs/ /bin/bash -c "useradd -U -m -G sudo,video,audio,adm,dip,plugdev,fuse,dialout $USERNAMEPWD"
else
	chroot rootfs/ /bin/bash -c "useradd -U -m -G sudo,adm,dip,plugdev,dialout $USERNAMEPWD"
fi
chroot rootfs/ /bin/bash -c "echo $USERNAMEPWD:$USERNAMEPWD | chpasswd"
chroot rootfs/ /bin/bash -c "chsh -s /bin/bash $USERNAMEPWD"

# configure fstab
install -m 644 patches/fstab rootfs/etc/fstab

# first boot services
install -m 755 patches/resize2fs rootfs/etc/init.d
install -m 755 patches/firstrun  rootfs/etc/init.d
chroot rootfs/ /bin/bash -c "update-rc.d firstrun defaults >/dev/null 2>&1"

# configure MIN / MAX speed for cpufrequtils
sed -e "s/MIN_SPEED=\"0\"/MIN_SPEED=\"$CPUMIN\"/g" -i rootfs/etc/init.d/cpufrequtils
sed -e "s/MAX_SPEED=\"0\"/MAX_SPEED=\"$CPUMAX\"/g" -i rootfs/etc/init.d/cpufrequtils

# configure bash: reverse search and shell completion
sed -e 's/# "\\e\[5~": history\-search\-backward/"\\e[5~": history-search-backward/' -i rootfs/etc/inputrc
sed -e 's/# "\\e\[6~": history\-search\-forward/"\\e[6~": history-search-forward/' -i rootfs/etc/inputrc
sed -e '/#if ! shopt -oq posix/,+6s/#//' -i rootfs/etc/bash.bashrc


# set hostname
echo $HOSTNAME > rootfs/etc/hostname

echo -e "Configuring network"
install -m 644 patches/network-interfaces rootfs/etc/network/interfaces
install -m 644 patches/hosts rootfs/etc/hosts
sed -e "s/THISHOST/$HOSTNAME/g" -i rootfs/etc/hosts
