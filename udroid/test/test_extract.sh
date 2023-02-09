#!/bin/bash

set -e -u
unset LD_PRELOAD

TERMUX_ROOT="/data/data/com.termux/files"
PROOT_DLCACHE="$TERMUX_ROOT/usr/var/lib/proot-distro/dlcache"
PROOTD_DIR="$TERMUX_ROOT/usr/var/lib/proot-distro/installed-rootfs"
source ../src/proot-utils/proot-utils.sh

[[ -f $PROOT_DLCACHE/udroid-arm64-xfce4-V3MBB2.tar.gz ]] &&  {
    file="$PROOT_DLCACHE/udroid-arm64-xfce4-V3MBB2.tar.gz"
}

# works only with udroid-impish-xfce4 for now
p_extract --file $file --path $PROOTD_DIR/udroid
