#!/usr/bin/env bash

apt install -y jq wget proot pv
[[ ! -d udroid/src ]] && {
    echo "udroid/src not found"
    exit 1
}

cd udroid/src || exit 1

bash install.sh
