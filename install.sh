#!/usr/bin/env bash

TPREFIX="/data/data/com.termux/files"
BIN_DIR="${TPREFIX}/usr/bin"
UDORID_FILE="scripts/udroid/udroid.sh"

echo "setting udroid..."

if [ -f $UDROID_FILE ]; then
    if [ -f ${BIN_DIR}/udroid.sh ]; then
        rm -rf "${BIN_DIR}/udroid.sh"
    fi
    cp ${UDROID_FILE} ${BIN_DIR}/udroid
    chmod 775 ${BIN_DIR}/udroid
else
    echo "Installation Failed..."
    exit 1
fi

echo "Done"

exit 0
