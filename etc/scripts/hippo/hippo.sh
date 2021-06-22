#!/usr/bin/env bash

version=0

TPREFIX="/data/data/com.termux/files"

SCRIPT_DIR="${TPREFIX}/usr/etc/proot-distro/"
INSTALL_FOLDER="${TPREFIX}/usr/varlib/proot-distro/installed-rootfs"

HIPPO_DIR="${INSTALL_FOLDER}/hippo"
HIPPO_SCRIPT_FILE="${SCRIPT_DIR}/hippo.sh"

SOCIAL_PLATFORM="https://discord.gg/TAqaG5sEfW"

# HIPPO_DIR = "${INSTALL_FOLDER}/${HIPPO_DEFAULT}"
# HIPPO_SCRIPT_FILE="${SCRIPT_DIR}/hippo.sh"

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
        apt install axel
    fi
    mkdir -p .1x1tmp
    axel -o .1x1tmp/version https://raw.githubusercontent.com/RandomCoderOrg/fs-manager-hippo/main/version || {
        echo "Error"; exit 1
    }

    origin_version=$(cat .1x1tmp/version)

    rm -rf .1x1tmp

    if [ "$origin_version" -gt "$version" ]; then
        echo "upgrdae avalibe to \e[1;32${origin_version}\e[0m"
    elif [ "$origin_version" -eq "$version" ]; then
        echo "You are on latest version \e[1;32${origin_version}\e[0m]]"
    else
        echo "Upgrader hit unexpected condition..."
    fi

    if start_upgrade; then
        bash -x .1x1tmp/upgrade --summary
        rm -rf .1x1tmp
    else
        echo "Error"
    fi


}

function start_upgrade() {
    mkdir -p .1x1tmp
    axel -o .1x1tmp/upgrade.sh https://raw.githubusercontent.com/RandomCoderOrg/fs-manager-hippo/main/etc/scripts/upgrade_patch/upgrade.sh || {
        echo "Error"; exit 1
    }
    bash -x upgrade.sh || {
        return 1
    }
    return 0
}

function _lauch_or_install()
{
    if ! __check_for_plugin; then
        echo -e "Plugin at ${HIPPO_SCRIPT_FILE} is missing ......"
        echo -e "May be this not a correct installation...."
        echo -e "Try to notice us a \e[34m${SOCIAL_PLATFORM}\e[0m"
        exit 1
    else
        if ! __check_for_filesystem; then
            echo -e "Installing hippo..........."
            if proot-distro install hippo; then
                echo -e "Installation Done......\a"
                echo "Waiting..."
                sleep 2
                clear
                echo -e "Now You can launch your ubuntu 21.04 with command \e[1;32mhippo\e[0m"
                # echo -e "use hippo --help for more option and comming up features"
            else
                echo -e "Launching".....
                proot-distro login hippo
            fi
        fi
    fi
}

if [ $# -eq 0 ]; then
    case "$1" in
        upgrade) __upgrade;;
        *) _lauch_or_install;;
        # startvnc)
        # if __check_for_hippo; then
        #     proot-distro launch hippo -- startvnc
        # else
        #     echo -e "This command is supposed to run after installing hippo"
        #     # echo -e "Use \e[1;32mhippo --install\e[0m install"
        #     echo -e "\e[32mError:\e[0m Hippo not found"
        # fi
        # ;;
        # stoptvnc)
        # if __check_for_hippo; then
        #     proot-distro launch hippo -- stoptvnc
        # else
        #     echo -e "This command is supposed to run after installing hippo"
        #     # echo -e "Use \e[1;32mhippo --install\e[0m install"
        #     echo -e "\e[32mError:\e[0m Hippo not found"
        # fi
        # ;;
    esac
fi