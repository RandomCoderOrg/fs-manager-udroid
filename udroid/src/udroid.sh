#!/bin/bash

[[ ! -f proot-utils/proot-utils.sh ]] && echo "proot-utils.sh not found" && exit 1

install() {
    :
}

login() {
    :
}

remove() {
    :
}

####################



while [ $# -gt 0 ]; do
    case $1 in
        --install|-i)   ;;
        --login|-l)     ;;
        --remove | --uninstall ) ;;
    esac
done
