#!/bin/bash


case $(echo "$0" | cut -d "/" -f 4) in
    "startvnc")
        python3 /usr/share/udroid/main.py --startvnc $*
    ;;
    "stopvnc")
        python3 /usr/share/udroid/main.py --stopvnc $*
    ;;
esac
