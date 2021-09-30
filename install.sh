#!/usr/bin/env bash

TPREFIX="/data/data/com.termux/files"
BIN_DIR="${TPREFIX}/usr/bin"

echo "setting udroid..."

if [ -f etc/scripts/udroid/udroid.sh ]; then
    FILE="etc/scripts/udroid/udroid.sh"
    if [ -f ${BIN_DIR}/udroid.sh ]; then
        rm -rf "${BIN_DIR}/udroid.sh"
    fi
    cp ${FILE} ${BIN_DIR}/udroid
    chmod 775 ${BIN_DIR}/udroid
else
    echo "Installation Failed..."
    exit 1
fi

echo "Done"

exit 0