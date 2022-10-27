#!/bin/bash

RTR="${PREFIX}/etc/udroid"
DEFAULT_ROOT="${PREFIX}/usr/var/lib/udroid"
DEFAULT_FS_INSTALL_DIR="${DEFAULT_ROOT}/installed-filesystems"
DLCACHE="${DEFAULT_ROOT}/dlcache"
RTCACHE="${RTR}/.cache"

[[ -d ${RTR} ]] && cd $RTR || exit 1
[[ ! -f proot-utils/proot-utils.sh ]] && echo "proot-utils.sh not found" && exit 1
[[ ! -f gum_wrapper.sh ]] && echo "gum_wrapper.sh not found" && exit 1

source proot-utils/proot-utils.sh
source gum_wrapper.sh

export distro_data

fetch_distro_data() {
    URL="https://raw.githubusercontent.com/RandomCoderOrg/udroid-download/main/distro-data.json"
    _path="${RTCACHE}/distro-data.json.cache"

    gum_spin dot "Fetching distro data.." curl -L -s -o $_path $URL || {
        ELOG "[${0}] failed to fetch distro data"
    }
    
    if [[ -f $_path ]]; then
        LOG "set distro_data to $_path"
        distro_data=$_path
    else
        die "Distro data fetch failed!"
    fi
}

install() {
    ###
    # install()
    #
    # stages:
    #   1) take the arguments supplied ( i.e "arg"->$1 and "path"->$2 )
    #   2) parse the arg for suite and varient
    #       2-1) if suite or varient is null (i.e not supplied) the try to prompt by guessing it with avalible arguments
    #   3) parse the download link from json ( if null exit )
    #   4) Extract the filesystem to target path
    #   5) execute fixes file

    local arg=$1; shift 1
    local path=""
    local suite=${arg%%:*}
    local varient=${arg#*:}

    while [[ $# -gt 0 ]]; do
        case $1 in
            -p | --path) 

                # Custom paths are set either to point a new directory instead of default
                # this is not-recommended cause managing installed filesystems becomes harder when they are outside of DEFAULT directories
                #       operations like: remove, reset or analyzing filesystems
                # using custom path results in abonded installation -> script only cares when its path is supplied again
                #
                # possible solution is to cache the loaction every time a path is supplied and use that for operations
                shift
                local path=$1
                LOG "(install) custom installation path set to $path"
            ;;
            *) break ;;
        esac
    done

    LOG "[USER] function args => suite=$suite varient=$varient"
    
    # if TEST_MODE is set run scripts in current directory and use test.json for distro_conf
    [[ -n $TEST_MODE ]] && {
        LOG "[TEST] test mode enabled"
        distro_data=test.json
        DLCACHE="./tmp/dlcache"
        mkdir -p $DLCACHE
        LOG "[TEST] DLCACHE=$DLCACHE"
        LOG "[TEST] distro_data=$distro_data"
    }

    ############### START OF OPTION PARSER ##############

    # implemenation to parse two words seperated by a colon
    #   eg: jammy:xfce4
    #  Fallback conditions
    #  1. if no colon is found, then instead of error try to guess the user intentiom
    #      and give a promt to select missing value the construct the colon seperated arg
    #  2. if both colon seperated words are same then => ERROR

    # check if seperator is present & Guess logic
    [[ $(echo $arg | awk '/:/' | wc -l) == 0 ]] && {
        ELOG "seperator not found"
        LOG "trying to guess what does that mean"

        if [[ $(cat $distro_data | jq -r '.suites[]') =~ $arg ]]; then
            LOG "found suite [$arg]"
            suite=$arg
            varient=""
        else
            for _suites in $(cat $distro_data | jq -r '.suites[]'); do
                for _varients in $(cat $distro_data | jq -r ".${_suites}.varients[]"); do
                    if [[ $_varients =~ $arg ]]; then
                        suite=$""
                        varient=$arg
                    fi
                done
            done
        fi
    }
    
    # Check if somehow suite and varient are same ( which is not the case )
    if [[ "$suite" == "$varient" ]]; then
        [[ -n "$suite" ]] && [[ -n "$varient" ]] && {
            ELOG "Parsing error in [$arg] (both can't be same)"
            LOG "function args => suite=$suite varient=$varient"
            echo "parse error"
        }
    fi


    suites=$(cat $distro_data | jq -r '.suites[]')

    # if suite or varient is empty prompt user to select it!
    [[ -z $suite ]] && {
        suite=$(g_choose $(cat $distro_data | jq -r '.suites[]'))
    }
    [[ ! $suites =~ $suite ]] && echo "suite not found" && exit 1

    [[ -z $varient ]] && {
        varient=$(g_choose $(cat $distro_data | jq -r ".$suite.varients[]"))
    }
    [[ ! $varient =~ $varient ]] && echo "varient not found" && exit 1

    LOG "[Final] function args => suite=$suite varient=$varient"
    ############### END OF OPTION PARSER ##############

    # Finally to get link
    
    # arch transition
    case $(dpkg --print-architecture) in
        arm64 | aarch64) arch=aarch64 ;;
        armhf | armv7l | armv8l) arch=armhf ;;
        x86_64| amd64) arch=amd64;;
        *) die "unsupported architecture" ;;
    esac

    link=$(cat $distro_data | jq -r ".$suite.$varient.${arch}url")
    LOG "link=$link"
    name=$(cat $distro_data | jq -r ".$suite.$varient.Name")
    LOG "name=$name"
    # final checks
    [[ "$link" == "null" ]] && {
        ELOG "link not found for $suite:$varient"
        echo "ERROR:"
        echo "link not found for $suite:$varient"
        echo "either the suite or varient is not supported or invalid options supplied"
        echo "Report this issue at https://github.com/RandomCoderOrg/ubuntu-on-android/issues"
        exit 1 
    }
    if [[ -d $DEFAULT_FS_INSTALL_DIR/$name ]]; then
        ELOG "filesystem already installed"
        echo "filesystem already installed ."
        # [TODO]: write about reset and remove
        exit 1
    fi

    # file extension
    ext=$(echo $link | awk -F. '{print $NF}')
    
    # if path is set then download fs and extract it to path
    # cause it make better use of path
    if [[ -z $path ]]; then
        # echo "$link + $name"
        msg_download $name "$DLCACHE/$name.tar.$ext" $link
        download "$name.tar.$ext" "$link"

        # Start Extracting
        LOG "Extracting $name.tar.$ext"

        # create $name directory
        mkdir -p $DEFAULT_FS_INSTALL_DIR/$name

        # call proot extract
        msg_extract "$DEFAULT_FS_INSTALL_DIR/$name"
        p_extract --file "$DLCACHE/$name.tar.$ext" --path "$DEFAULT_FS_INSTALL_DIR/$name"

        echo -e "Applying proot fixes"
        bash proot-utils/proot-fixes.sh "$DEFAULT_FS_INSTALL_DIR/$name"
    else
        msg_download $name "$path/$name.tar.$ext" "$link"
        download "$name.tar.$ext" "$link" "$path"

        if [[ -d $path ]]; then
            LOG "Extracting $name.tar.$ext"
            mkdir -p $path/$name
        else
            ELOG "ERROR: path $path not found"
            echo "ERROR: path $path not found"
        fi

        msg_extract "$path/$name"
        p_extract --file "$path/$name.tar.$ext" --path "$path/$name"

        # apply proot-fixes
        echo -e "Applying proot fixes"
        bash proot-utils/proot-fixes.sh "$path/$name"
    fi

    echo -e "[\xE2\x9C\x94] $name installed."

}

login() {
    
    path=$DEFAULT_FS_INSTALL_DIR

    while [[ $# -gt 0 ]]; do
        case $1 in
            -p | --path) 

                # Custom paths are set either to point a new directory instead of default
                # this is not-recommended cause managing installed filesystems becomes harder when they are outside of DEFAULT directories
                #       operations like: remove, reset or analyzing filesystems
                # using custom path results in abonded installation -> script only cares when its path is supplied again
                #
                # possible solution is to cache the loaction every time a path is supplied and use that for operations
                local path=$2; shift 2
                LOG "(login) custom installation path set to $path"
            ;;
            -*)
                echo "Unknown option: $1"
                exit 1
            ;;
            *) distro=$1; shift; break ;;
        esac
    done

    [[ -z $distro ]] && echo "ERROR: distro not specified" && exit 1

    if [ -d $path/$distro ]; then
        LOG "login to $distro"
        p_login --path $path/$distro
    else
        ELOG "ERROR: $distro not found"
        echo "ERROR: $distro not found"
        # echo "use 'install' to install it"
        exit 1
    fi

}

list() {
    :
}

remove() {
    :
}

####################
download() {
    local name=$1
    local link=$2

    [[ -n "$3" ]] && local path=$3
    [[ -z $path ]] && path="$DLCACHE"

    LOG "download() args => name=$name link=$link path=$path"

    wget -q --show-progress --progress=bar:force -O ${path}/$name  "$link"  2>&1 || {
        ELOG "failed to download $name"
        echo "failed to download $name"
        exit 1
    }
}

msg_download() {
    local name=$1
    local path=$2
    local link=$3

    grey_color="\e[90m"
    reset_color="\e[0m"

    echo -e "Downloading $name filesystem ${grey_color}($link)${reset_color}"
    echo -e ":[PATH]= ${grey_color}${path}${reset_color}"
}

msg_extract() {
    local path=$1

    echo
    echo -e "Extracting filesystem to ${grey_color}${path}${reset_color}"
    echo -e "This may take a while..."
    echo
}
####################

if [ $# -eq 0 ]; then
    echo "usage: $0 [install|login|remove]"
    exit 1
fi

while [ $# -gt 0 ]; do
    case $1 in
        --install|-i) shift 1; install "$*" ; break ;;
        --login|-l) shift 1; login "$*"; break ;;
        --remove | --uninstall ) ;;
        *) echo "unkown option [$1]"; break ;;
    esac
done
