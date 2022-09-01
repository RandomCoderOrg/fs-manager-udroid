#!/bin/bash

ERROR_DUMP_FILE="/tmp/proot-utils-error.log"

msg() { echo -e "${*} \e[0m" >&2;:;}

p_extract() {
    # OPTIONS:
    # --path -> to set custom path
    # --file | -f -> location of the file to extract

    local NO_PROG=false

    while [ $# -gt 0 ]; do
        case $1 in
            --file | -f)        file=$2; shift  ;;
            --path)             path=$2 shift 2 ;;
            --disable-progress) NO_PROG=true    ;;
            *)
                msg "unkown option [$1]"
                shift 1
                ;;
        esac
    done

    [[ -z $file ]] && msg "file not specified" && return 1
    [[ -z $path ]] && echo "no path provided" && exit 1
    [[ ! -f $file ]] && msg "file not found" && return 1
    [[ ! -d $path ]] && msg "path not found" && return 1

    if ! $NO_PROG; then
        pv $file | proot \
                --link2symlink \
                tar -xvz -C "$path" &> $ERROR_DUMP_FILE
    else
        proot \
                --link2symlink \
                tar -xvz -C "$path" < $file
    fi
}

login() {
    # OPTIONS:
    # --disable-special-mounts
    # --disable-auto-init
    # --disable progress

    
    while [ $# -gt 0 ]; do
        case $1 in
        --disable-special-mounts) NO_S_M=true;;
        --disable-auto-init) NO_A_I=true;;
        esac
    done
}

while [ $# -gt 0 ]; do
    case $1 in
        --install|-i)   ;;
        --login|-l)     ;;
        --extract)      ;;
        --uninstall|-u) ;;
    esac
done
