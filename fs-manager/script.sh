#!/usr/bin/env bash

VERSION="0.1"

# clours (ncurses)
if [ -n "$(command -v tput)" ] && [ "$(tput colors)" -ge 8 ]; then
	RST="$(tput sgr0)"
	RED="${RST}$(tput setaf 1)"
	BRED="${RST}$(tput bold)$(tput setaf 1)"
	GREEN="${RST}$(tput setaf 2)"
	YELLOW="${RST}$(tput setaf 3)"
	BYELLOW="${RST}$(tput bold)$(tput setaf 3)"
	BLUE="${RST}$(tput setaf 4)"
	CYAN="${RST}$(tput setaf 6)"
	BCYAN="${RST}$(tput bold)$(tput setaf 6)"
	ICYAN="${RST}$(tput sitm)$(tput setaf 6)"
else
	RED=""
	BRED=""
	GREEN=""
	YELLOW=""
	BYELLOW=""
	BLUE=""
	CYAN=""
	BCYAN=""
	ICYAN=""
	RST=""
fi
function msg()
{
    echo -e "$@" >&2
}

function __check_for_termux()
{
    if [[ "$(pwd)" == /data/data/com.termux/* ]]; then
        return 0
    else
        return 1
    fi
}

########################

function cmd_backup()
{
    :
}
function cmd_purge()
{
    :
}
function upgrade()
{
    :
}
function cmd_install()
{
    :
}


##################
function __check_for()
{
    in_cache=( "$@" )
    if [ $# -ge 1 ]; then
        for i in "$@"; do
            if  command -v "${in_cache[@]}" >> /dev/null ; then
                if [[ "${in_cache[1]}" != --force ]]; then
                    msg "[${RED} FAILED ${RST}] Unable to find $i try using \"apt install ${i} \""
                    ((x=x+1))
                else
                    msg "[${GREEN} Executing ${RST}] sudo apt install -y $i"
                    sudo apt install -y "$i"
                fi
            fi
        done
        if ((x >= 1)); then
            return 1
        else
            return 0
        fi
        
    fi
}
function cmd_help()
{
    if [ -n "${VERSION}" ]; then
        msg "fs-manager v${VERSION}"
    fi
}
function require_root(){
    if [ "$(id -u)" != 0 ]; then
        msg "[${RED} FAILED ${RST}] This has done as root user.."
        exit 1
    fi
}
trap 'echo -e "\\r[${GREEN} Done ${RST}] Exiting immediately as requested."; exit 1;' HUP INT TERM

if [ $# -ge 1 ]; then
    case $1 in
    --backup|backup) shift 1; backup;;
    --help|-h) shift 1; cmd_help;;
    esac
fi