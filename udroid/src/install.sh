#!/bin/bash -x

BIN="$PREFIX/bin"
INSTALL_DIR="${PREFIX}/etc/udroid"

RTR="${PREFIX}/etc/udroid"
DEFAULT_ROOT="${PREFIX}/var/lib/udroid"
DEFAULT_FS_INSTALL_DIR="${DEFAULT_ROOT}/installed-filesystems"
DLCACHE="${DEFAULT_ROOT}/dlcache"
RTCACHE="${RTR}/.cache"

[[ -f ./gum_wrapper.sh ]] && source ./gum_wrapper.sh

function install_symlinks() {
    sleep 2
    ln -sv $INSTALL_DIR/udroid.sh $BIN/udroid
}

function create_dir() {
    local remove=$1; shift 1
    [[ $remove == 0 ]] && [[ -d $1 ]] && rm -rf $1
    g_spin minidot "Creating directory \"$1\"..." mkdir -p $1    
}

create_dir 0 $INSTALL_DIR
create_dir 1 $DEFAULT_ROOT
create_dir 1 $DEFAULT_FS_INSTALL_DIR
create_dir 1 $DLCACHE
create_dir 0 $RTCACHE

g_spin minidot "installing $(basename $(pwd))..." cp -rv ./* $INSTALL_DIR
g_spin minidot "processing symbolic link..." bash -x install_sim.sh
shout "Installation complete"
