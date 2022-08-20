#!/bin/bash

source ./gum_wrapper.sh

inp=$(g_input "enter your name")
cod=$(g_choose "a" "b" "c")

if g_confirm "Are you sure your name is $inp & code is $cod"; then
    shout "Yes"
else
    shout "No"
fi

g_spin minidot wget -q "https://github.com/RandomCoderOrg/fs-cook/releases/download/v1.4/kinetic-raw-amd64.tar.gz"
