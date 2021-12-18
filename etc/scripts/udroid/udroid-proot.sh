#!/usr/bin/env bash

# Udroid manager to work inside proot environment
#

version=2.1
script_name='udroid-manager'
DEFAULT_CONF="${HOME}/.udroid/udroid-lauch.conf"
CACHE_ROOT="${HOME}/.uoa-cache-root"
TPREFIX="/data/data/com.termux/files"
SCRIPT_DIR="${TPREFIX}/usr/etc/proot-distro"
INSTALL_FOLDER="${TPREFIX}/usr/var/lib/proot-distro/installed-rootfs"
DLCACHE="${TPREFIX}/usr/var/lib/proot-distro/dlcache"

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

######
trim_quotes() {
    # Usage: trim_quotes "string"
    : "${1//\'/}"
    printf '%s\n' "${_//\"/}"
}
######

_download_plugin() {
    
    shout "trying to pull plugin from github"
    # get plugin 
    repo_root="https://raw.githubusercontent.com/RandomCoderOrg/ubuntu-on-android/modified"
    suite=$1
    de=$2
    plugin_url="$repo_root/pd-plugins/udroid-$suite-$de.sh"

    if [ -z "${suite}" ] || [ -z "${varient}" ]; then
        die "Invalid arguments"
    fi

    curl \
        -L -o $SCRIPT_DIR/udroid-"$suite"-"$de".sh \
        "$plugin_url" || die "Plugin Download failed"
    
    echo udroid-"$suite"-"$de" > "$DEFAULT_CONF"
    proot-distro install udroid-"$suite"-"$de" || lshout "installation exited with non-zero exit code"
}

_install() {
    
    git clone https://github.com/RandomCoderOrg/udroid-loader.git "$CACHE_ROOT"
    cd udroid-loader || exit 1
    option=$(bash launch.sh)
    distro=$(cut -d " " -f 1 "$option")
    de=$(cut -d " " -f 2 "$option")
    case $distro in
    "2" | "ubuntu21_04") suite='hirsute' ;;
    "1" | "ubuntu21_10") suite='impish' ;;
    esac
    case $de in
    "1") de='xfce4' ;;
    "2") de='mate' ;;
    # "3") export de='kde';;
    # "4") export de='no_DE' ;;
    *) die "udroid-loader failed" ;;
    esac

    _download_plugin $suite $de
}

_lauch_or_install()
{
    # condtions

    # Udroid Conf-file
    if [ ! -f "$DEFAULT_CONF" ]; then
        export NO_CONF_FOUND=true
    else
        launch_suite=$( head -n1 "$DEFAULT_CONF" )
    fi

    # does DE specified in conf exist?
    if [ ! -d $INSTALL_FOLDER/"$launch_suite" ]; then
        export NO_SUITE_FOUND=true
    fi

    if [ $NO_CONF_FOUND ] || [ $NO_SUITE_FOUND ]; then
        _install
    else
        _proot_distro_dispatch '$*'
    fi
}

_proot_distro_dispatch() {
    # start pulse server
    
    shout "Starting pulse over 127.0.0.1"
    pulseaudio \
        --start \
        --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" \
        --exit-idle-time=-1 >>/dev/null

    cap_last_cap='--bind /dev/null:/proc/sys/kernel/cap_last_cap'
    shared_tmp='--shared-tmp'

    args="$* $cap_last_cap $shared_tmp"
    fargs="$(trim_quotes "$args")"
    distro="$( head -n1 "$DEFAULT_CONF" )"
    shout "starting udroid: $distro"
    proot-distro login "$distro" "${fargs}"
}

run_cmd() {
    proot-distro login "${distro}" -- /bin/bash -c "$@"
}
######

internet_avalible()
{
    if ping -W 4 -c 1 github.com >> /dev/null; then
        return 0
    else
        return 1
    fi   
}

upgrade() {
    if internet_avalible; then
        if [ -d $CACHE_ROOT/fs-manager-udroid ]; then
            cd fs-manager-udroid || die "failed .."
            git pull -v
            bash install.sh
        else
            git clone https://github.com/RandomCoderOrg/fs-manager-udroid "$CACHE_ROOT/fs-manager-udroid"
            cd fs-manager-udroid || die "failed .."
            bash install.sh
        fi
    fi
}

######

if [ $# -ge 1 ]; then
    case "$1" in
    --install)
        shift 1
        _install
        ;;
    --upgrade)
        upgrade
        ;;
    -v|--version)
        msg "udroid fsmgr tool($version): By SaicharanKandukuri, AnninoDr4"
        msg "a tool to launch or manage DE varients without heavy commands"
        ;;
    
    *)
        _lauch_or_install "$*"
        ;;
    esac
else
    :
fi
