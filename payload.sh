#!/usr/bin/env bash

: "${TERMUX_PREFIX_i:=/data/data/com.termux/files/usr}"

TERMUX_ETC="/data/data/com.termux/files/usr/etc"
CONFIG_DIR="${TERMUX_ETC}/ubuntu-on-android"

cd $CONFIG_DIR/ubuntu-on-android || exit 1

if ! [ -d fs-manager-hippo ]; then
    git clone https://github.com/RandomCoderOrg/fs-manager-hippo
else
    cur=$(pwd)
    cd fs-manager-hippo || exit
    git remote add upgrade https://github.com/RandomCoderOrg/fs-manager-hippo
    git pull upstream modified
    cd "${cur}" || exit 1
fi

install -d -m 700 "${TERMUX_PREFIX_i}"/bin/ fs-manager/fs-manager
