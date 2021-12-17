#!/usr/bin/env bash

die() {
    echo -e "${RED}[!!] ${*}${RST}"
    exit 1
    :
}
warn() {
    echo -e "${RED}[??] ${*}${RST}"
    :
}
shout() {
    echo -e "${DS}[●] ${*}${RST}"
    :
}
lshout() {
    echo -e "${DC}-> ${*}${RST}"
    :
}
msg() {
    echo -e "\e[38;5;228m ${*} \e[0m" >&2
    :
}

function _backup() {
    # defaults
    default_backup_dir="/sdcard/Downloads"
    default_file_name=""
    of="/sdcard/udroid-backup.tar.gz"

    if [ $# -ge 1 ]; then
        case "$1" in
        -h | --help)
            _help backup
            ;;
        -o | --output)
            shift
            of="$*"
            ;;
        esac
    fi
    shout "Backing up to $of/udroid-backup.tar.gz ..."
    of="$of/udroid-backup.tar.gz"

    tar \
        --exclude=/dev/* \
        --exclude=/run/* \
        --exclude=/proc/* \
        --exclude=/sys/* \
        --exclude=/tmp/* \
        --exclude=/"${0}" \
        --exclude="/$of" \
        --exclude-caches-all \
        --one-file-system \
        -cpf \
        - "/" -P |
        pv -s $(($(du -skx "/" | awk '{print $1}') * 1024)) |
        gzip --best >"$of".tar.gz

}

_help() {
    # * TODO:
    :
}

function service_exec() {
    if [ -f /usr/share/udroid/auto_start_service ]; then
        grep -v '^ *#' </usr/share/udroid/auto_start_service | while IFS= read -r _service; do
            lshout "starting service ${_service}"
            service start "${_service}"
        done
    fi
}

function startvnc() {
    pubip=$(hostname -I)
    port=':1'

    if [[ -n $PORT ]] && [[ $PORT =~ ^[0-9]+$ ]]; then
        port="$PORT"
    fi

    if [ -f /tmp/.X11-unix/X"${port}" ]; then
        vnc=true
    else
        vnc=false
    fi

    if [ -f /tmp/.X"${port}"-lock ]; then
        vnc=true
    else
        vnc=false
    fi

    if ! $vnc; then
    vncserver -xstartup "${DEFAULT_XSTARTUP}" -localhost no -desktop "udroid Default VNC" :${port}
    else
    echo "A vncserver lock is found for port ${port}"
    die "try using stopvnc"
    fi 

}

function stopvnc() {
    port=':1'

    shout "stoping vnc..."
    if [[ -n $PORT ]] && [[ $PORT =~ ^[0-9]+$ ]]; then
        port="$PORT"
    fi

    vncserver --kill :1 >> /dev/null

    if [ -f /tmp/.X11-unix/X"${port}" ]; then
        rm -rv /tmp/.X11-unix/X"${port}"
    fi

    if [ -f /tmp/.X"${port}"-lock ]; then
        rm -rv /tmp/.X"${port}"-lock
    fi

    msg "Done..."
}

function start_display() {
    :
}

function on_startup() {
    service_exec
}

function _init() {
    on_startup
    
}
