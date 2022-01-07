#!/usr/bin/env bash

die()    { echo -e "${RED}[E] ${*}${RST}";exit 1;:;}
warn()   { echo -e "${RED}[W] ${*}${RST}";:;}
shout()  { echo -e "${DS}[-] ${*}${RST}";:;}
lshout() { echo -e "${DC}-> ${*}${RST}";:;}
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
        :
    }
    _msg_servic_exec() {
        :
    }
    _msg_startvnc() {
        :
    }
    _msg_stopvnc() {
        :
    }
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
    port='1'

    if [[ -n $PORT ]] && [[ $PORT =~ ^[0-9]+$ ]]; then
        port="$PORT"
    fi

    [[ -f /tmp/.X11-unix/X"${port}" ]] && vnc=true || vnc=false
    [[ -f /tmp/.X"${port}"-lock ]] && vnc=true || vnc=false


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
    service_exec dbus
}

function _init() {
    on_startup
    
}
