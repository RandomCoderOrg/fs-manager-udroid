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

# arch transition
case $(dpkg --print-architecture) in
    arm64 | aarch64) ARCH=aarch64 ;;
    arm | armhf | armv7l | armv8l) ARCH=armhf ;;
    x86_64| amd64) ARCH=amd64;;
    *) die "unsupported architecture" ;;
esac

# GUM="./gum/usr/bin/gum"
GUM="./gum/gum-$ARCH/usr/bin/gum"

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
    echo -e "[\xE2\x9C\x94] $title"
}

function g_format () {
    file=$1
    [[ -z $file ]] && die "g_format: file not specified"
    $GUM format < $file
}

