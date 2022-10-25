#!/bin/bash -x

BIN="$PREFIX/bin"
INSTALL_DIR="${PREFIX}/etc/udroid"

DEFAULT_ROOT="${PREFIX}/usr/var/lib/udroid"
DEFAULT_FS_INSTALL_DIR="${DEFAULT_ROOT}/installed-filesystems"
DLCACHE="${DEFAULT_ROOT}/dlcache"
RTCACHE="${RTR}/.cache"

[[ -f ./gum_wrapper.sh ]] && source ./gum_wrapper.sh

function install_symlinks() {
    sleep 2
    ln -sv $INSTALL_DIR/udroid.sh $BIN/udroid
}

function create_dir() {
    [[ -d $1 ]] && rm -rf $1
    g_spin minidot "Creating directory..." mkdir -p $1    
}

create_dir $INSTALL_DIR
create_dir $DEFAULT_ROOT
create_dir $DEFAULT_FS_INSTALL_DIR
create_dir $DLCACHE
create_dir $RTCACHE

g_spin minidot "installing $(basename $(pwd))..." cp -rv ./* $INSTALL_DIR
g_spin minidot "processing symbolic link..." bash -x install_sim.sh
shout "Installation complete"
