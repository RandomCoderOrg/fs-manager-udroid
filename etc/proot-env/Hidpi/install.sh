#!/usr/bin/env bash

if [ -d hidpi ] && [ -f hidpi/install.sh ]; then
    cd hidpi || exit 1
    bash install.sh
fi
if [ -d xhidpi ] && [ -f xhidpi/install.sh ]; then
    cd hidpi || exit 1
    bash install.sh
fi