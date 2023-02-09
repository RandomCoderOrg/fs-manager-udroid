#!/bin/bash
BIN="${PREFIX}/bin"
INSTALL_DIR="${PREFIX}/etc/udroid"

sleep 2
ln -sv $INSTALL_DIR/udroid.sh $BIN/udroid || {
    echo "Installation failed.."
    exit 1
}
