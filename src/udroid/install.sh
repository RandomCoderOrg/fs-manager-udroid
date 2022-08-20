#!/bin/bash

TERMUX_ROOT="/data/data/com.termux/files"
INSTALL_DIR="${TERMUX_ROOT}/usr/etc/udroid"

[[ ! -d "$INSTALL_DIR" ]] && mkdir -pv $INSTALL_DIR
[[ -f ./gum_wrapper.sh ]] && source ./gum_wrapper.sh

g_spin minidot "installing $(basename $(pwd))..." cp -rv ./* $INSTALL_DIR

# TODO: setup simbolic links
