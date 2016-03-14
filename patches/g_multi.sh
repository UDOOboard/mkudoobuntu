#!/bin/bash
###
# Simple g_multi start script
###
#
# Author: Robert C. Nelson
# Modified by: Ettore Chimenti
#
# Original at: https://gist.github.com/5103e2035f26418c6bf9.git
#
#needs: sudo apt-get install udhcpd
#sudo sed -i -e 's:no:yes:g' /etc/default/udhcpd

H=`cat /sys/fsl_otp/HW_OCOTP_CFG0 |sed -e 's/0x//'`
L=`cat /sys/fsl_otp/HW_OCOTP_CFG1 |sed -e 's/0x//'`
SerialNumber=$H$L
SerialNumber=${SerialNumber^^}
Manufacturer="SECO-AIDILAB"
Product="UDOONEO"

#host_addr/dev_addr
#Should be "constant" for a particular unit, if not specified g_multi/g_ether will
#randomly generate these, this causes interesting problems in windows/systemd/etc..
#
#systemd: ifconfig -a: (mac = device name)
#enx4e719db78204 Link encap:Ethernet  HWaddr 4e:71:9d:b7:82:04 

host_vend="4e:71:9d"
dev_vend="4e:71:9e"

if [ -f /sys/class/net/eth0/address ]; then
	#concatenate a fantasy vendor with last 3 digit of onboard eth mac
	address=$(cut -d: -f 4- /sys/class/net/eth0/address)
elif [ -f /sys/class/net/wlan0/address ]; then
	address=$(cut -d: -f 4- /sys/class/net/wlan0/address)
else
	address="aa:bb:cc"
fi

host_addr=${host_vend}:${address}
dev_addr=${dev_vend}:${address}

usb0_address="192.168.7.2"
usb0_gateway="192.168.7.1"
usb0_netmask="255.255.255.252"

unset root_drive
root_drive="$(cat /proc/cmdline | sed 's/ /\n/g' | grep root=UUID= | awk -F 'root=' '{print $2}' || true)"
if [ ! "x${root_drive}" = "x" ] ; then
	root_drive="$(/sbin/findfs UUID=${root_drive} || true)"
else
	root_drive="$(cat /proc/cmdline | sed 's/ /\n/g' | grep root= | awk -F 'root=' '{print $2}' || true)"
fi

g_network="iSerialNumber=${SerialNumber} iManufacturer=${Manufacturer}"
g_network+="iProduct=${Product} host_addr=${host_addr} dev_addr=${dev_addr}"

g_drive="cdrom=0 ro=0 stall=0 removable=1 nofua=1"

#In a single partition setup, dont load g_multi, as we could trash the linux file system...
if [ "x${root_drive}" = "x/dev/mmcblk0p1" ] || 
	 [ "x${root_drive}" = "x/dev/mmcblk1p1" ] ; then
	if [ -f /usr/sbin/dhcpd ] ; then
		#Make sure (# CONFIG_USB_ETH_EEM is not set), 
		#otherwise this shows up as "usb0" instead of ethX on host pc..
		modprobe g_ether ${g_network} || true
	else
		#serial:
		modprobe g_serial || true
	fi
else
	boot_drive="${root_drive%?}1"
	modprobe g_multi file=${boot_drive} ${g_drive} ${g_network} || true
fi

trap "echo" 1 

while [ 1 ]
do
    sleep 1000
done

