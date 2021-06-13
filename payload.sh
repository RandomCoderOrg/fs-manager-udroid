#!/usr/bin/env bash

: "${TERMUX_PREFIX_i:=/data/data/com.termux/files/usr}"

TERMUX_ETC="/data/data/com.termux/files/usr/etc"
CONFIG_DIR="${TERMUX_ETC}/ubuntu-on-android"

if ! [ -d "${CONFIG_DIR}" ]; then
    mkdir -p "${CONFIG_DIR}"
fi

cd $CONFIG_DIR/ubuntu-on-android || exit 1

if ! [ -d fs-manager-hippo ]; then
    git clone https://github.com/RandomCoderOrg/fs-manager-hippo
else
    cur=$(pwd)
    cd fs-manager-hippo || exit
    git remote add upgrade https://github.com/RandomCoderOrg/fs-manager-hippo
    git pull upstream modified
fi

cp fs-manager/fs-manager ${TERMUX_PREFIX_i}/bin/fs-manager
chmod 755 ${TERMUX_PREFIX_i}/bin/fs-manager

if command -v fs-manager >> /dev/null; then
    fs-manager --install
    exit 0
else
    exit 1
fi
