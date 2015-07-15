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
cp patches/ttymxc1.conf rootfs/etc/init/ttymxc1.conf
# disable some getties
rm rootfs/etc/init/tty3.conf
rm rootfs/etc/init/tty4.conf
rm rootfs/etc/init/tty5.conf
rm rootfs/etc/init/tty6.conf
# enable root login for latest ssh on trusty
sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' rootfs/etc/ssh/sshd_config
# fix selinux
mkdir rootfs/selinux
# remove what's anyway not working
rm rootfs/etc/init/ureadahead*
rm rootfs/etc/init/plymouth*

#fix autostart https://bugs.launchpad.net/ubuntu/+source/lightdm/+bug/1188131
sed -i 's/and plymouth-ready//' rootfs/etc/init/lightdm.conf

echo "UTC" > rootfs/etc/timezone
chroot rootfs/ /bin/bash -c "dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1"
# set root password
chroot rootfs/ /bin/bash -c "echo root:$ROOTPWD | chpasswd"
# create non-root user
chroot rootfs/ /bin/bash -c "useradd -U -m -G sudo,video,audio $USERNAMEPWD"
chroot rootfs/ /bin/bash -c "echo $USERNAMEPWD:$USERNAMEPWD | chpasswd"

# configure fstab
echo "/dev/mmcblk0p2  /      ext4  defaults,noatime,nodiratime,data=writeback,commit=600,errors=remount-ro  0  0" >> rootfs/etc/fstab
echo "/dev/mmcblk0p1  /boot  vfat  defaults,noatime,nodiratime                                              0  0" >> rootfs/etc/fstab

install -m 755 patches/resize2fs rootfs/etc/init.d
install -m 755 patches/firstrun  rootfs/etc/init.d
chroot rootfs/ /bin/bash -c "update-rc.d firstrun defaults >/dev/null 2>&1"

# configure MIN / MAX speed for cpufrequtils
sed -e "s/MIN_SPEED=\"0\"/MIN_SPEED=\"$CPUMIN\"/g" -i rootfs/etc/init.d/cpufrequtils
sed -e "s/MAX_SPEED=\"0\"/MAX_SPEED=\"$CPUMAX\"/g" -i rootfs/etc/init.d/cpufrequtils

# set hostname
echo $HOSTNAME > rootfs/etc/hostname

# set hostname in hosts file
cat > rootfs/etc/hosts <<EOT
127.0.0.1   localhost $HOST
::1         localhost $HOST ip6-localhost ip6-loopback
fe00::0     ip6-localnet
ff00::0     ip6-mcastprefix
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOT

echo -e "Enabling network support on eth0"
echo "
# Loopback network interface
auto lo
iface lo inet loopback

# Primary network interface
#auto eth0
#iface eth0 inet dhcp" > rootfs/etc/network/interfaces

install -m 644 patches/70-persistent-net.rules rootfs/etc/udev/rules.d/70-persistent-net.rules
