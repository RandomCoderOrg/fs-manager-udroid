#!/usr/bin/env bash

version=2

if [ -n "$HIPPO_BRANCH" ]; then
    BRANCH="$HIPPO_BRANCH"
fi

CACHE_ROOT="${HOME}/.uoa-cache-root"
TPREFIX="/data/data/com.termux/files"

SCRIPT_DIR="${TPREFIX}/usr/etc/proot-distro"
INSTALL_FOLDER="${TPREFIX}/usr/var/lib/proot-distro/installed-rootfs"
DLCACHE="${PREFIX}/usr/var/lib/proot-distro/dlcache"

HIPPO_DIR="${INSTALL_FOLDER}/udroid"
HIPPO_SCRIPT_FILE="${SCRIPT_DIR}/udroid.sh"

# SOCIAL_PLATFORM="\e[34mhttps://discord.gg/TAqaG5sEfW"

# HIPPO_DIR = "${INSTALL_FOLDER}/${HIPPO_DEFAULT}"
# HIPPO_SCRIPT_FILE="${SCRIPT_DIR}/udroid.sh"

# * Usefull functions
# die()     exit with code 1 with printing given string
# warn()    like die() without exit status (used when exit is not necessary)
# shout()   pring messege in a good way with some lines
# lshout()  print messege in a standard way
# msg()     print's normal echo

die    () { echo -e "${RED}!! ${*}${RST}";exit 1 ;:;}
warn   () { echo -e "${RED}?? ${*}${RST}";:;}
shout  () { echo -e "${DS}=> ${*}${RST}";:; }
lshout () { echo -e "${DC}-> ${*}${RST}";:; }
msg    () { echo -e "\e[38;5;228m ${*} \e[0m" >&2 ;:; }


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

function __verify_bin_path()
{
    BINPATH="${SHELL}"

    if [ -n "$BINPATH" ]; then
        if [ "$BINPATH" != "/data/data/com.termux/files/*" ]; then
            msg "This has to be done inside termux environment"
            die "\$SHELL != $BINPATH"
            exit 1
        fi
    else
        warn "SHELL value is empty.."
    fi
}

function __upgrade() {
    # setup downloader
    if ! command -v axel >> /dev/null; then
        apt install axel -y
    fi

    mkdir -p "${CACHE_ROOT}"
    axel -o "${CACHE_ROOT}"/version https://raw.githubusercontent.com/RandomCoderOrg/fs-manager-udroid/main/version >> /dev/null || {
        die "error"
    }

    origin_version=$(cat "${CACHE_ROOT}"/version)

    rm -rf "${CACHE_ROOT}"

    if [ "$origin_version" -gt "$version" ]; then
        lshout "upgrdae avalibe to \e[1;32mV${origin_version}\e[0m"
    elif [ "$origin_version" -eq "$version" ]; then
        lshout "You are on latest version \e[1;32mV${origin_version}\e[0m"
        exit 0
    else
        die "Upgrader hit unexpected condition..."
        exit 1
    fi

    if start_upgrade; then
        bash -x "${CACHE_ROOT}"/upgrade --summary
        rm -rf "${CACHE_ROOT}"
    else
        die "Error"
    fi


}

function start_upgrade() {
    mkdir -p "${CACHE_ROOT}"
    axel -o "${CACHE_ROOT}"/upgrade.sh https://raw.githubusercontent.com/RandomCoderOrg/fs-manager-udroid/main/etc/scripts/upgrade_patch/upgrade.sh >> /dev/null || {
        die "Error"; exit 1
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
        rm -rf "${CACHE_ROOT}/fs-manager-udroid"
    fi

    FSM_URL="https://github.com/RandomCoderOrg/fs-manager-udroid"

    if [ -z "${BRANCH}" ]; then
        git clone ${FSM_URL} "${CACHE_ROOT}/fs-manager-udroid" || die "failed to clone repo"
    else
        git clone -b "${BRANCH}" "${CACHE_ROOT}/fs-manager-udroid" || die "failed to clone repo"
    fi

    if [ -f "${CACHE_ROOT}"/fs-manager-udroid/install.sh ]; then
        cd "${CACHE_ROOT}"/fs-manager-udroid || die "failed to cd ..."
        bash install.sh || die "failed to install manager..."
    fi
}
progressfilt ()
{
    local flag=false c count cr=$'\r' nl=$'\n'
    while IFS='' read -d '' -rn 1 c
    do
        if $flag
        then
            printf '%s' "$c"
        else
            if [[ $c != $cr && $c != $nl ]]
            then
                count=0
            else
                ((count++))
                if ((count > 1))
                then
                    flag=true
                fi
            fi
        fi
    done
}
_download ()
{
  link=$1
  wget --progress=bar:force $link || die "download failed"
}
function __help()
{
    msg "udroid - termux Version ${version} by saicharankandukuri"
    msg
    msg "A bash script to make basic action(login, vncserver) easier for ubuntu-on-android project"
    msg
    msg "Usage ${0} [options]"
    msg
    msg "Options:"
    msg "--install       To try installing udroid"
    msg "--help          To display this message"
    msg "--enable-dbus   To start terminal session with dbus enabled"
    msg "--force-upgrade To reinstall this script of origin"
    msg "startvnc        To start udroid vncserver"
    msg "stopvnc         To stop udroid vncserver"
    msg "--enable-dbus-startvnc To start vnc with dbus"
    msg "------------------"#links goes here
    msg "for additional documentation see: \e[1;34mhttps://github.com/RandomCoderOrg/ubuntu-on-android#basic-usage"
    msg "report issues and feature requests at: \e[1;34mhttps://github.com/RandomCoderOrg/ubuntu-on-android/issues"
    # msg "Join the community at DISCORD -> $SOCIAL_PLATFORM"
    msg "------------------"
}

function __split_tarball_handler()
{
  target_plugin=$1
  if [ -n "$target_plugin" ] && [ -f "$target_plugin" ]; then
    source $target_plugin
  else
    die "Could not find script in tmp directory: This attribute is not for manuall entry"
  fi

  if ! $SPLIT_TARBALL_FS; then
    cp "$target_plugin" "$SCRIPT_DIR/udroid.sh"
    shift; _lauch_or_install "$@"
  fi
  shout "starting download.. this may take some time"

  if [ ! -d ${CACHE_ROOT} ]; then
    mkdir -v ${CACHE_ROOT}
  fi

  mkdir -p "${CACHE_ROOT}/fs-cache"

  # count no.of parts
  x=0
  for part in $PARTS; do
    ((x=x+1))
  done
  cd ${CACHE_ROOT}/fs-cache || die "failed.. cd"
  # start download
  y=0
  for links in $PARTS; do
    ((y=y+1))
    shout "downloading [$(basename $links)] part($y/$x).. "
    _download $links
  done
  cd $HOME || die "failed.. cd"
  shout "combining parts to one.. （￣︶￣）↗"
  cat "${CACHE_ROOT}/fs-cache/*" > "${DLCACHE}/${FINAL_NAME}"
  shout "triggering installation.."
  shift ; _lauch_or_install "$@"
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
        echo -e "Installing udroid..........."
        if proot-distro install udroid; then
            echo -e "Installation Done......\a\a" # \a triggers vibration in termux
            echo "Waiting..."
            sleep 4
            clear
            echo -e "Now You can launch your ubuntu 21.04 with command \e[1;32mudroid\e[0m"
            echo -e "use udroid --help for more option and comming up features"
        fi
    else
        #######################################################################################################
        # Thanks to @GxmerSam Sam Alarie, @mizzunet, @Andre-cmd-rgb for the issues randome ideas and suggestion


        pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1 >> /dev/null
        if [[ -f "${CACHE_ROOT}"/fs-manager-udroid/etc/scripts/vncserver/startvnc.sh ]] && [[ ! -f ${HIPPO_DIR}/bin/startvnc ]]; then
            DIR="${CACHE_ROOT}/fs-manager-udroid/etc/scripts/vncserver/startvnc.sh"
            cp "${DIR}" ${HIPPO_DIR}/bin/startvnc
            proot-distro login udroid -- chmod 775 /bin/startvnc
        fi
        if [ -f "${CACHE_ROOT}"/fs-manager-udroid/etc/scripts/vncserver/stopvnc.sh ] && [ ! -f ${HIPPO_DIR}/bin/stopvnc ]; then
            DIR="${CACHE_ROOT}/fs-manager-udroid/etc/scripts/vncserver/stopvnc.sh"
            cp "${DIR}" ${HIPPO_DIR}/bin/stopvnc
            proot-distro login udroid -- chmod 775 /bin/stopvnc
        fi
        proot-distro login udroid "$@" || warn "program exited unexpectedly..."
    fi
}
__verify_bin_path
if [ $# -ge 1 ]; then
    case "$1" in
        upgrade) __upgrade;;
        --init-setup-tarball) shift 1; __split_tarball_handler "$@";;
        --force-upgrade) __force_uprade_hippo;;
        --enable-dbus) shift 1; _lauch_or_install --bind /dev/null:/proc/sys/kernel/cap_last_cap "$@" ;;
        "--enable-dbus-startvnc") shift 1; _lauch_or_install --bind /dev/null:/proc/sys/kernel/cap_last_cap -- startvnc "$@" ;;
        "--enable-dbus-stopvnc") shift 1; _lauch_or_install --bind /dev/null:/proc/sys/kernel/cap_last_cap -- stopvnc "$@" ;; # no use
        --install) _lauch_or_install;;
        --help) __help;;

        startvnc)
        if __check_for_hippo; then
            proot-distro login udroid --no-kill-on-exit -- startvnc
        else
            echo -e "This command is supposed to run after installing udroid"
            echo -e "Use \e[1;32mhippo --install\e[0m install"
            echo -e "\e[32mError:\e[0m udroid not found"
        fi
        ;;

        stoptvnc)
        if __check_for_hippo; then
            proot-distro login udroid --no-kill-on-exit -- stoptvnc
        else
            echo -e "This command is supposed to run after installing udroid"
            echo -e "Use \e[1;32mhippo --install\e[0m install"
            echo -e "\e[32mError:\e[0m udroid not found"
        fi
        ;;
        *) _lauch_or_install "$@";;
    esac
else
    _lauch_or_install "$@"
fi
