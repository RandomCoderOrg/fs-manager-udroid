#!/bin/bash -x

BIN="$PREFIX/bin"
INSTALL_DIR="${PREFIX}/etc/udroid"


[[ ! -d "$INSTALL_DIR" ]] && mkdir -pv $INSTALL_DIR
[[ -f ./gum_wrapper.sh ]] && source ./gum_wrapper.sh

function install_symlinks() {
    sleep 2
    ln -sv $INSTALL_DIR/udroid.sh $BIN/udroid
}

g_spin minidot "installing $(basename $(pwd))..." cp -rv ./* $INSTALL_DIR
g_spin minidot "processing symbolic link..." bash -x install_sim.sh
shout "Installation complete"
