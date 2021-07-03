#!/usr/bin/env bash

TPREFIX="/data/data/com.termux/files"
BIN_DIR="${TPREFIX}/usr/bin"

echo "setting hippo..."

if [ -f etc/scripts/hippo/hippo.sh ]; then
    FILE="etc/scripts/hippo/hippo.sh"
    if [ -f ${BIN_DIR}/hippo.sh ]; then
        rm -rf "${BIN_DIR}/hippo.sh"
    fi
    cp ${FILE} ${BIN_DIR}/hippo
    chmod 775 ${BIN_DIR}/hippo
else
    echo "Installation Failed..."
    exit 1
fi

echo "Done"

exit 0