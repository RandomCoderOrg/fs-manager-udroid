#!/bin/bash

_c_magneta="\e[95m"
_c_green="\e[32m"
_c_red="\e[31m"
_c_blue="\e[34m"
RST="\e[0m"

die()    { echo -e "${_c_red}[E] ${*}${RST}";exit 1;:;}
warn()   { echo -e "${_c_red}[W] ${*}${RST}";:;}
shout()  { echo -e "${_c_blue}[-] ${*}${RST}";:;}
lshout() { echo -e "${_c_blue}-> ${*}${RST}";:;}
imsg()	 { if [ -n "$UDROID_VERBOSE" ]; then echo -e ": ${*} \e[0m" >&2;fi;:;}
msg()    { echo -e "${*} \e[0m" >&2;:;}

if ! command -v python3 >/dev/null 2>&1; then
    die "Python3 is not installed"
fi

if (( UID != 0 )); then
    die "You need to be root to run this script"
fi

shout "Installing udroidmgr"
mkdir -pv /usr/share/udroid || {
    die "Failed to create /usr/share/udroid"
}

if [ -d utils ]; then
    cp -rv utils /usr/share/udroid/ || {
        die "Failed to copy utils"
    }
fi

if [ -f main.py ]; then
    cp -v main.py /usr/share/udroid/ || {
        die "Failed to copy main.py"
    }
fi

if [ -f main.sh ]; then
    cp -v main.sh /usr/share/udroid/ || {
        die "Failed to copy main.sh"
    }
fi


if [[ -f /usr/bin/startvnc ]]; then
    rm -rvf /usr/bin/startvnc
fi

if [[ -f /usr/bin/stopvnc ]]; then
    rm -rvf /usr/bin/stopvnc
fi

ln -sv /usr/share/udroid/main.sh /usr/bin/startvnc || {
    die "Failed to create symlink"
}
ln -sv /usr/share/udroid/main.sh /usr/bin/stopvnc || {
    die "Failed to create symlink"
}
