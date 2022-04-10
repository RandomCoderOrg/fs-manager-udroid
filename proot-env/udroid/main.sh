#!/bin/bash


case $0 in
    "startvnc")
        python3 /usr/share/udroid/main.py --startvnc $*
    ;;
    "stopvnc")
        python3 /usr/share/udroid/main.py --stopvnc $*
    ;;
esac
