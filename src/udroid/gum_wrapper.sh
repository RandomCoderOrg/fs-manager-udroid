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

# GUM="./gum/usr/bin/gum"
GUM="./gum/gum-$(dpkg --print-architecture)/usr/bin/gum"

export GUM_INPUT_CURSOR_FOREGROUND="#F2BE22"
export GUM_CHOOSE_CURSOR_FOREGROUND="#F2BE22"
export GUM_CONFIRM_PROMPT_FOREGROUND="#F2BE22"

[[ ! -f $GUM ]] && die "gum not found.."

trim_quotes() {
    # Usage: trim_quotes "string"
    : "${1//\'}"
    printf '%s\n' "${_//\"}"
}

function g_input() {
    placeholder=""

    [[ -n "$1" ]] && {
        placeholder="$1"
    }

    $GUM input --placeholder "$placeholder"
}

function g_choose() {
    options=$*
    
    [[ -n $options ]] && {
        $GUM choose $options
    }
}

function g_confirm() {
    msg=$*

    return $($GUM confirm "$msg")
}

function g_spin() {
    spinner=$1; shift
    title=$1; shift
    cmd=$*

    $GUM spin -s "$spinner" --title "$title" -- $cmd
}
