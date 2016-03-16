## mkudoobuntu
This script creates SD-card images for UDOO boards. It supports both desktop and 
headless images. The created images are as small as possible and expanded to the 
whole card size during the first boot.

### Usage
To debootstrap a new unnamed image, use:

    sudo ./mkudoobuntu.sh <board> <flavour>

Branded-release images can be generated with:

    sudo RELEASE="2.0 Beta6" ./mkudoobuntu.sh <board> <flavour>

To edit a previously debootstrapped rootfs, use:

    sudo ./mkudoobuntu.sh <board> <operation>

`<board>` can be: `udoo-qdl`, `udoo-neo`.

`<operation>` can be:
 * `install`: Install a deb in rootfs from repos
 * `remove`: Remove a deb from rootfs
 * `list`: List installed pkg in rootfs
 * `reimage`: Make a new image from a modified rootfs
 * `shell`: Open an interactive shell in a rootfs
    
### Prerequisites
This script has been tested on Ubuntu 15.10, 15.04 and 14.04. 
It may work on other Debian-like system.

### Supported boards
1. UDOO Quad 
2. UDOO Dual
3. UDOO Neo (Basic, Extended, Full)

### Misc sources
Original work:
https://github.com/igorpecovnik/lib 

U-Boot:
https://github.com/UDOOboard/uboot-imx

Kernel:
https://github.com/UDOOboard/linux_kernel/
