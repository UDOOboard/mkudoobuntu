#!/bin/bash
# Author: Francesco Montefoschi <francesco.monte@gmail.com>
# License: GNU GPL version 2

set -e

if [ $(id -u) -ne 0 ]; then
    echo "Run the script using fakeroot!"
    exit 1
fi

if [ "$#" -ne 2 ]; then
    echo "Usage: fakeroot ./make-kpkg </path/to/linux_kernel> <qdl|neo|a62>"
    exit 1
fi

args=("$@")
kerneldir=${args[0]}
defcfg=${args[1]}
KERNEL_NAME="linux-udoo${defcfg}"

if [ $defcfg == "qdl" ]; then
    echo "Building for UDOO Quad/Dual"
    defconfig="udoo_quad_dual_defconfig"
    dtbs=$(eval echo "imx6{q,dl}-udoo{-lvds7,-lvds15,-hdmi}.dtb")
else
    if [ $defcfg == "neo" ]; then
        echo "Building for UDOO Neo"
        defconfig="udoo_neo_defconfig"
        dtbs=$(eval echo "imx6sx-udoo-neo-{basic,basicks,extended,full}{-hdmi,-lvds7,-lvds15,}{-m4,}.dtb")
    else
        if [ $defcfg == "a62" ]; then
            echo "Building for A62"
            defconfig="seco_a62_defconfig"
            dtbs=$(eval echo "imx6{q,dl}-seco_SBC_A62.dtb")
            KERNEL_NAME="linux-${defcfg}"
        else
            echo "Board type must be \"neo\" or \"qdl\""
            exit 1
        fi
    fi
fi

cd $kerneldir

CPUS=$(grep -c 'processor' /proc/cpuinfo)
CTHREADS="-j${CPUS}";
KCFLAGS="-O2 -march=armv7-a -mtune=cortex-a9 -mfpu=vfpv3-d16 -pipe -fomit-frame-pointer"
XCOMPILER="arm-linux-gnueabihf-"

TEMP=$(mktemp -d /tmp/udoo${defcfg}-kernel.XXXXXXXX)
mkdir -p $TEMP/boot/dts
mkdir -p $TEMP/lib/modules
mkdir -p $TEMP/DEBIAN

# echo "Cleaning kernel..."
# ARCH=arm make clean

echo "Building kernel..."
ARCH=arm make $defconfig
ARCH=arm CROSS_COMPILE=$XCOMPILER KCFLAGS="$KCFLAGS" make $CTHREADS zImage ${dtbs} firmware modules

echo "Build complete! Copying files in the fake root..."
cp arch/arm/boot/zImage $TEMP/boot/
cp arch/arm/boot/dts/*udoo*.dtb $TEMP/boot/dts
ARCH=arm CROSS_COMPILE=$XCOMPILER KCFLAGS="$KCFLAGS" make $CTHREADS INSTALL_MOD_PATH=$TEMP modules_install firmware_install

KERNEL_VERSION=$(ls $TEMP/lib/modules/)
OUTPUT_FILE="/tmp/${KERNEL_NAME}_${KERNEL_VERSION}_armhf.deb"
SIZE=$(du -s $TEMP |awk '{print $1}')

cat <<END > $TEMP/DEBIAN/control
Package: $KERNEL_NAME
Version: $KERNEL_VERSION
Architecture: armhf
Provides: linux-image, linux-image-2.6, linux-firmware
Maintainer: UDOO Team <social@udoo.org>
Installed-Size: $SIZE
Section: kernel
Priority: optional
Description: The Linux Kernel, patched to run on UDOO boards
END

echo "Bulding .deb file..."
dpkg-deb --build $TEMP $OUTPUT_FILE
echo "Enjoy your kernel in $OUTPUT_FILE!"


################################################################################


echo "Now it is time for kernel headers..."
objtree=$(mktemp -d /tmp/udoo${defcfg}-kernelheaders.XXXXXXXX)
mkdir -p $objtree/debian
mkdir -p $objtree/ROOT/DEBIAN
kernel_headers_dir=$objtree/ROOT
(find . -name Makefile\* -o -name Kconfig\* -o -name \*.pl) > "$objtree/debian/hdrsrcfiles"
(find arch/arm/include include scripts -type f) >> "$objtree/debian/hdrsrcfiles"
(find arch/arm -name module.lds -o -name Kbuild.platforms -o -name Platform) >> "$objtree/debian/hdrsrcfiles"
(find $(find arch/arm -name include -o -name scripts -type d) -type f) >> "$objtree/debian/hdrsrcfiles"
(find arch/arm/include Module.symvers include scripts -type f) >> "$objtree/debian/hdrobjfiles"
destdir=$kernel_headers_dir/usr/src/linux-headers-$KERNEL_VERSION
mkdir -p "$destdir"
mkdir -p "$kernel_headers_dir/lib/modules/$KERNEL_VERSION/"
(tar -c -f - -T -) < "$objtree/debian/hdrsrcfiles" | (cd $destdir; tar -xf -)
(tar -c -f - -T -) < "$objtree/debian/hdrobjfiles" | (cd $destdir; tar -xf -)
(cp .config $destdir/.config) # copy .config manually to be where it's expected to be
ln -sf "/usr/src/linux-headers-$KERNEL_VERSION" "$kernel_headers_dir/lib/modules/$KERNEL_VERSION/build"
rm -f "$objtree/debian/hdrsrcfiles" "$objtree/debian/hdrobjfiles"

cat <<EOF >> $objtree/ROOT/DEBIAN/control
Package: $KERNEL_NAME-headers
Version: $KERNEL_VERSION
Provides: linux-headers, linux-headers-2.6
Maintainer: UDOO Team <social@udoo.org>
Architecture: armhf
Section: kernel
Priority: optional
Description: Linux kernel headers for $KERNEL_VERSION
 This package provides kernel header files for KERNEL_VERSION
 .
 This is useful for people who need to build external modules
EOF

OUTPUT_FILE="/tmp/${KERNEL_NAME}-headers_${KERNEL_VERSION}_armhf.deb"
dpkg-deb --build $objtree/ROOT $OUTPUT_FILE


################################################################################

echo "Finally libc headers..."
objtree=$(mktemp -d /tmp/udoo${defcfg}-libc.XXXXXXXX)
mkdir -p $objtree/DEBIAN
mkdir -p $objtree/usr

ARCH=arm CROSS_COMPILE=$XCOMPILER KCFLAGS="$KCFLAGS" make $CTHREADS INSTALL_MOD_PATH=$TEMP headers_install KBUILD_SRC= INSTALL_HDR_PATH=$objtree/usr

cat <<EOF >> $objtree/DEBIAN/control
Package: linux-libc-dev
Version: $KERNEL_VERSION
Provides: linux-kernel-headers
Maintainer: UDOO Team <social@udoo.org>
Architecture: armhf
Section: kernel
Priority: optional
Description: Linux support headers for userspace development
 This package provides userspaces headers from the Linux kernel.  These headers
 are used by the installed headers for GNU glibc and other system libraries.
EOF

OUTPUT_FILE="/tmp/linux-libc-dev_${KERNEL_VERSION}_armhf.deb"
dpkg-deb --build $objtree $OUTPUT_FILE

