## mkudoobuntu
This script creates SD-card images for UDOO boards. It supports both desktop and 
headless images. The created images is as small as possible and expanded to the 
card size at the first boot.

### Usage
    ./mkudoobuntu.sh [RECIPE [operation] [--force]]

    <none>        Select a recipe interactively
    RECIPE        Start debootstrapping a recipe

    --force       Don't ask 
    install       Install a deb in rootfs from repos
    remove        Remove a deb from rootfs
    list          List installed pkg in rootfs
    reimage       Make a new image from a modified rootfs
    configure     Reconfigure the rootfs
    shell         Open an interactive shell in a rootfs
    
### Prerequisites
This script has been tested only on Ubuntu 15.04 and 14.04. 
It may work on other Debian-like system.

### Supported boards
1. UDOO Quad 
2. UDOO Dual
3. UDOO Neo
