#!/bin/bash

[[ ! -f proot-utils/proot-utils.sh ]] && echo "proot-utils.sh not found" && exit 1
[[ ! -f gum_wrapper.sh ]] && echo "gum_wrapper.sh not found" && exit 1

source proot-utils/proot-utils.sh
source gum_wrapper.sh

export distro_data

RTR="${PREFIX}/etc/udroid"
DEFAULT_ROOT="${PREFIX}/var/lib/udroid"
DEFAULT_FS_INSTALL_DIR="installed-filesystems"
DLCACHE="${TODO_DIR}/dlcache"
RTCACHE="${RTR}/.cache"

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
    local arg=$1
    local path=""
    local suite=${arg%%:*}
    local varient=${arg#*:}

    while [[ $# -gt 0 ]]; do
        case $1 in
            -p | --path) 
                shift
                local path=$1
                LOG "(install) custom installation path set to $path"
            ;;
            *) break ;;
        esac
    done

    LOG "[USER] function args => suite=$suite varient=$varient"
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
    arch=$(dpkg --print-architecture)
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

    # file extension
    ext=$(echo $link | awk -F. '{print $NF}')
    
    # if path is set then download fs and extract it to path
    # cause it make better use of path
    if [[ -z $path ]]; then
        # echo "$link + $name"
        download "$name.tar.$ext" "$link"

        # Start Extracting
        LOG "Extracting $name.tar.$ext"
        p_extract --file "$DLCACHE/$name.tar.$ext" --path "$DEFAULT_FS_INSTALL_DIR/$name"
    else
        download "$name.tar.$ext" "$link" "$path"

        [[ -d $path ]] && {
            LOG "Extracting $name.tar.$ext"
            mkdir -p $path/$name
        } || {
            ELOG "ERROR: path $path not found"
            echo "ERROR: path $path not found"
        }
        p_extract --file "$path/$name.tar.$ext" --path "$path/$name"
    fi

}

login() {
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
    axel -a -o ${path}/$name $link || {
        ELOG "failed to download $name"
        echo "failed to download $name"
        exit 1
    }
}
####################

if [ $# -eq 0 ]; then
    echo "usage: $0 [install|login|remove]"
    exit 1
fi

while [ $# -gt 0 ]; do
    case $1 in
        --install|-i) shift 1; install $1; break ;;
        --login|-l)     ;;
        --remove | --uninstall ) ;;
        *) echo "unkown option [$1]"; break ;;
    esac
done
