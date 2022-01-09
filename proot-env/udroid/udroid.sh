#!/usr/bin/env bash

_c_magneta="\e[95m"
_c_green="\e[32m"
_c_red="\e[31m"
_c_blue="\e[34m"

die()    { echo -e "${_c_red}[E] ${*}${RST}";exit 1;:;}
warn()   { echo -e "${_c_red}[W] ${*}${RST}";:;}
shout()  { echo -e "${_c_blue}[-] ${*}${RST}";:;}
lshout() { echo -e "${_c_blue}-> ${*}${RST}";:;}
msg()    { echo -e "${*} \e[0m" >&2;:;}

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
    shout "Backing up udroid to $of/udroid-backup.tar.gz ..."
    of="$of/udroid-backup.tar.gz"

    tar \
        --exclude={/dev/*,/sys/*,/run/*,/tmp/*} \
        --exclude={/sdcard,/vendor,/boot,/data,/linkerconfig,/media,/system} \
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
    _msg_backup() {
        msg "udroid backup [-o|--output <output file>]"
        msg "backup udroid to <output file>"
        msg
        msg "Options:"
        msg "  -o|--output <output file>  : output file name"
        msg
    }
    _msg_servic_exec() {
        msg "udroid service_exec"
        msg
        msg "parses /usr/share/udroid/auto_start_service and starts services at startup"
    }
    _msg_startvnc() {
        msg "udroid startvnc | startvnc"
        msg "starts vncserver at port 1 with name as UDROID"
        msg 
        msg "Options:"
        msg "  -h | --help    to show this messege"
        msg "  -p | --port    to set the port to use"
        msg "  --novnc        to start novnc server!"
    }
    _msg_stopvnc() {
        msg "udroid stopvnc | stopvnc"
        msg "stops vncserver and clears all pid files and sockets of port 1"
    }

    case "$1" in
        backup)
        _msg_backup
        ;;
        service_exec)
        _msg_servic_exec
        ;;
        startvnc)
        _msg_startvnc
        ;;
        stopvnc)
        _msg_stopvnc
        ;;
        *)
        die "unknown word? $1" ;;
    esac
}

function service_exec() {
    if [ -f /usr/share/udroid/auto_start_service ]; then
        grep -v '^ *#' </usr/share/udroid/auto_start_service | while IFS= read -r _service; do
            lshout "starting service ${_service}"
            service start "${_service}"
        done
    fi
}

function no_vnc() {
    novnc_path="/usr/share/novnc/utils"
    novnc="${novnc_path}/launch.sh"
    port=6080

    if [ ! -f "$novnc" ]; then
        die "novnc launch.sh not found..."
    fi

    $novnc --listen $port
}

function startvnc() {
    pubip=$(hostname -I)
    port='1'

    if [[ -n $PORT ]] && [[ $PORT =~ ^[0-9]+$ ]]; then
        port="$PORT"
    fi

    [[ -f /tmp/.X11-unix/X"${port}" ]] && vnc=true || vnc=false
    [[ -f /tmp/.X"${port}"-lock ]] && vnc=true || vnc=false


    if ! $vnc; then
    vncserver -xstartup "${DEFAULT_XSTARTUP}" -localhost no -desktop "udroid Default VNC" :${port}
    else
    msg "A vncserver lock is found for port ${port}"
    die "try using stopvnc"
    fi

    msg "VNC server started at ${pubip}:${port}"
    msg "local VNC ip -> ${_c_magneta}127.0.0.1:1"
    msg "remote VNC ip -> ${_c_magneta}${pubip}:${port}"

    if [[ -n $NOVNC ]]; then
        msg "Starting novnc server..."
        msg "local VNC ip -> ${_c_magneta}127.0.0.1:6090"
        msg "remote VNC ip -> ${_c_magneta}${pubip}:6090"
        msg
        msg "press ctrl+c to stop novnc server!"
        no_vnc
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
    service_exec dbus
}

function _init() {
    on_startup
    
}
