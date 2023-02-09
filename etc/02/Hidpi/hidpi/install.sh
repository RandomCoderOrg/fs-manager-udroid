#!/usr/bin/env bash

ICONDIR="/usr/share/udroid"

if [ -f app.sh ]; then
    cp app.sh /bin/udroid-hidpi-mode
    chmod 775 /bin/udroid-hidpi-mode
fi

if [ -f logo.png ]; then

    if ! [ -d $ICONDIR ]; then
        mkdir -p $ICONDIR
    fi

    cp logo.png $ICONDIR/hidpi-logo.png

fi

if [ -f app.desktop ]; then
    if [ -d /usr/share/applications ]; then
        cp app.desktop /usr/share/applications/udroid-hidpi-mode.desktop
    fi 
fi

echo "Done..."