#!/bin/bash

set -e -u
unset LD_PRELOAD

TERMUX_ROOT="/data/data/com.termux/files"
PROOT_DLCACHE="$TERMUX_ROOT/usr/var/lib/proot-distro/dlcache"

source proot-utils/proot-utils.sh

login --path ${PROOT_DLCACHE}/udroid-impish-xfce4 -- /bin/sh
