#!/usr/bin/env bash

version=1

if [ -n "$HIPPO_BRANCH" ]; then
    BRANCH="$HIPPO_BRANCH"
fi

CACHE_ROOT="${HOME}/.uoa-cache-root"
TPREFIX="/data/data/com.termux/files"

SCRIPT_DIR="${TPREFIX}/usr/etc/proot-distro"
INSTALL_FOLDER="${TPREFIX}/usr/var/lib/proot-distro/installed-rootfs"

HIPPO_DIR="${INSTALL_FOLDER}/hippo"
HIPPO_SCRIPT_FILE="${SCRIPT_DIR}/hippo.sh"

SOCIAL_PLATFORM="\e[1;34mhttps://discord.gg/TAqaG5sEfW\e[0m"

# HIPPO_DIR = "${INSTALL_FOLDER}/${HIPPO_DEFAULT}"
# HIPPO_SCRIPT_FILE="${SCRIPT_DIR}/hippo.sh"


die    () { echo -e "${RED}Error ${*}${RST}";exit 1 ;:;}
warn   () { echo -e "${RED}Error ${*}${RST}";:;}
shout  () { echo -e "${DS}////////";echo -e "${*}";echo -e "////////${RST}";:; }
lshout () { echo -e "${DC}";echo -e "${*}";echo -e "${RST}";:; }


function __check_for_hippo() {
    if [ -d ${HIPPO_DIR} ] && [ -f ${HIPPO_SCRIPT_FILE} ]; then
        return 0;
    else
        return 1;
    fi
}

function __check_for_plugin() {
    
    if [ -f ${HIPPO_SCRIPT_FILE} ]; then
        return 0
    else
        return 1
    fi

}

function __check_for_filesystem() {

    if [ -d ${HIPPO_DIR}/bin ]; then
        return 0
    else
        return 1
    fi
}

function __upgrade() {
    # setup downloader
    if ! command -v axel >> /dev/null; then
        apt install axel -y
    fi

    mkdir -p "${CACHE_ROOT}"
    axel -o "${CACHE_ROOT}"/version https://raw.githubusercontent.com/RandomCoderOrg/fs-manager-hippo/main/version >> /dev/null || {
        echo "Error"; exit 1
    }

    origin_version=$(cat "${CACHE_ROOT}"/version)

    rm -rf "${CACHE_ROOT}"

    if [ "$origin_version" -gt "$version" ]; then
        echo -e "upgrdae avalibe to \e[1;32mV${origin_version}\e[0m"
    elif [ "$origin_version" -eq "$version" ]; then
        echo -e "You are on latest version \e[1;32mV${origin_version}\e[0m"
        exit 0
    else
        echo "Upgrader hit unexpected condition..."
        exit 1
    fi

    if start_upgrade; then
        bash -x "${CACHE_ROOT}"/upgrade --summary
        rm -rf "${CACHE_ROOT}"
    else
        echo "Error"
    fi


}

function start_upgrade() {
    mkdir -p "${CACHE_ROOT}"
    axel -o "${CACHE_ROOT}"/upgrade.sh https://raw.githubusercontent.com/RandomCoderOrg/fs-manager-hippo/main/etc/scripts/upgrade_patch/upgrade.sh >> /dev/null || {
        echo "Error"; exit 1
    }
    bash -x upgrade.sh || {
        return 1
    }
    return 0
}



function __force_uprade_hippo()
{
    if [ ! -d "$CACHE_ROOT" ]; then
        mkdir "$CACHE_ROOT"
    else
        rm -rf "${CACHE_ROOT:?}/"*
    fi

    FSM_URL="https://github.com/RandomCoderOrg/fs-manager-hippo"

    if [ -z "${BRANCH}" ]; then
        git clone ${FSM_URL} "${CACHE_ROOT}/fs-manager-hippo" || die "failed to clone repo"
    else
        git clone -b "${BRANCH}" "${CACHE_ROOT}/fs-manager-hippo" || die "failed to clone repo"
    fi

    if [ -f "${CACHE_ROOT}"/fs-manager-hippo/install.sh ]; then
        cd "${CACHE_ROOT}"/fs-manager-hippo || die "failed to cd ..."
        bash install.sh || die "failed to install manager..."
    fi
}

function __help()
{
    echo -e "hippo - termux Version ${version}"
    echo -e "A bash script to make basic action(login, vncserver) easier for ubuntu-on-android project"
    echo -e 
    echo -e "Usage ${0} [options]"
    echo -e 
    echo -e "Options:"
    echo -e "\e[1;34m"
    echo -e "--install      To try installing hippo"
    echo -e "--help         to display this message"
    echo -e "--enable-dbus  To start terminal session with dbus enabled"
    echo -e "startvnc       To start hippo vncserver"
    echo -e "stopvnc        To stop hippo vncserver"
    echo -e "------------------"
    # SOCIAL_MEDIA link goes here
    echo -e "Join the community and leave at DISCORD -> $SOCIAL_PLATFORM"
    echo -e "------------------"
    echo -e "\e[0m"
}

function _lauch_or_install()
{
    if ! __check_for_plugin; then
        echo -e "Plugin at ${HIPPO_SCRIPT_FILE} is missing ......"
        echo -e "May be this not a correct installation...."
        echo -e "Try to notice us at \e[34m${SOCIAL_PLATFORM}\e[0m"
        exit 1
    fi
    if ! __check_for_filesystem; then
        echo -e "Installing hippo..........."
        if proot-distro install hippo; then
            echo -e "Installation Done......\a\a"
            echo "Waiting..."
            sleep 4
            clear
            echo -e "Now You can launch your ubuntu 21.04 with command \e[1;32mhippo\e[0m"
            # echo -e "use hippo --help for more option and comming up features"
        fi
    else
        #######################################################################################################
        # Thanks to @GxmerSam Sam Alarie, @mizzunet, @Andre-cmd-rgb for the issues randome ideas and suggestion


        pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1 >> /dev/null
        if [[ -f "${CACHE_ROOT}"/ubuntu-on-android/etc/scripts/vncserver/startvnc.sh ]] && [[ ! -f ${HIPPO_DIR}/bin/startvnc ]]; then
            DIR="${CACHE_ROOT}/ubuntu-on-android/etc/scripts/vncserver/startvnc.sh"
            cp "${DIR}" ${HIPPO_DIR}/bin/startvnc
            proot-distro login hippo -- chmod 775 /bin/startvnc
        fi
        if [ -f "${CACHE_ROOT}"/ubuntu-on-android/etc/scripts/vncserver/stopvnc.sh ] && [ ! -f ${HIPPO_DIR}/bin/stopvnc ]; then
            DIR="${CACHE_ROOT}/ubuntu-on-android/etc/scripts/vncserver/stopvnc.sh"
            cp "${DIR}" ${HIPPO_DIR}/bin/stopvnc
            proot-distro login hippo -- chmod 775 /bin/stopvnc
        fi
        proot-distro login hippo "$@" || warn "program exited unexpectedly..."
    fi
}

if [ $# -ge 1 ]; then
    case "$1" in
        upgrade) __upgrade;;
        
        --force-upgrade) __force_uprade_hippo;;
        --enable-dbus) shift 1; _lauch_or_install --bind /dev/null:/proc/sys/kernel/cap_last_cap ;;
        "--enable-dbus-startvnc") shift 1; _lauch_or_install --bind /dev/null:/proc/sys/kernel/cap_last_cap -- startvnc ;;
        "--enable-dbus-stopvnc") shift 1; _lauch_or_install --bind /dev/null:/proc/sys/kernel/cap_last_cap -- stopvnc ;;
        --install) _lauch_or_install;;
        --help) __help;;

        startvnc)
        if __check_for_hippo; then
            proot-distro login hippo -- startvnc
        else
            echo -e "This command is supposed to run after installing hippo"
            # echo -e "Use \e[1;32mhippo --install\e[0m install"
            echo -e "\e[32mError:\e[0m Hippo not found"
        fi
        ;;
        
        stoptvnc)
        if __check_for_hippo; then
            proot-distro login hippo -- stoptvnc
        else
            echo -e "This command is supposed to run after installing hippo"
            # echo -e "Use \e[1;32mhippo --install\e[0m install"
            echo -e "\e[32mError:\e[0m Hippo not found"
        fi
        ;;
        *) _lauch_or_install "$@";;
    esac
else
    _lauch_or_install "$@"
fi