#!/usr/bin/env bash

ICONDIR="/usr/share/hippo"

if [ -f app.sh ]; then
    cp app.sh /bin/hippo-xhidpi-mode
    chmod 775 /bin/hippo-xhidpi-mode
fi

if [ -f logo.png ]; then

    if ! [ -d $ICONDIR ]; then
        mkdir -p $ICONDIR
    fi

    cp logo.png $ICONDIR/xhidpi-logo.png

fi

if [ -f app.desktop ]; then
    if [ -d /usr/share/applications ]; then
        cp app.desktop /usr/share/applications/hippo-xhidpi-mode.desktop
    fi 
fi

echo "Done..."