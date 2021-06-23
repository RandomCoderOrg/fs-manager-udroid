#!/usr/bin/env bash

TPREFIX="/data/data/com.termux/files"
BIN_DIR="${TPREFIX}/usr/bin"
INSTALL_FOLDER="${TPREFIX}/usr/var/lib/proot-distro/installed-rootfs"
HIPPO_DIR="${INSTALL_FOLDER}/hippo"

echo "setting hippo..."

if [ -f etc/scripts/hippo/hippo.sh ]; then
    DIR="etc/scripts/hippo/hippo.sh"
    cp ${DIR} ${BIN_DIR}/hippo
    chmod 775 ${BIN_DIR}/hippo
else
    echo "Installation Failed..."
    exit 1
fi

if [ -f etc/scripts/vncserver/startvnc.sh ]; then
    DIR="etc/scripts/vncserver/startvnc.sh"
    cp ${DIR} ${HIPPO_DIR}/bin/startvnc
    proot-distro login hippo -- chmod 775 /bin/startvnc
else
    echo "Installation Failed..."
    exit 1
fi

if [ -f etc/scripts/vncserver/stopvnc.sh ]; then
    DIR="etc/scripts/vncserver/stopvnc.sh"
    cp ${DIR} ${HIPPO_DIR}/bin/stopvnc
    proot-distro login hippo -- chmod 775 /bin/stopvnc
else
    echo "Installation Failed..."
    exit 1
fi

echo "Done"

exit 0