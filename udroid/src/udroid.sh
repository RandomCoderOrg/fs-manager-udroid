#!/bin/bash

[[ ! -f proot-utils/proot-utils.sh ]] && echo "proot-utils.sh not found" && exit 1
[[ ! -f gum_wrapper.sh ]] && echo "gum_wrapper.sh not found" && exit 1

source proot-utils/proot-utils.sh
source gum_wrapper.sh

export distro_data

RTR="${PREFIX}/etc/udroid"
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
    local suite=${arg%%:*}
    local varient=${arg#*:}

    LOG "[USER] function args => suite=$suite varient=$varient"
    [[ -n $TEST_MODE ]] && distro_data=test.json

    # check if seperator is present
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
    
    if [[ $suite -eq $varient ]]; then
        [[ -n "$suite" ]] && [[ -n "$varient" ]] && {
            ELOG "Parsing error in [$arg] (both can't be same)"
            LOG "function args => suite=$suite varient=$varient"
            echo "parse error"
        }
    fi


    suites=$(cat $distro_data | jq -r '.suites[]')

    [[ -z $suite ]] && {
        suite=$(g_choose $(cat $distro_data | jq -r '.suites[]'))
    }
    [[ ! $suites =~ $suite ]] && echo "suite not found" && exit 1

    [[ -z $varient ]] && {
        varient=$(g_choose $(cat $distro_data | jq -r ".$suite.varients[]"))
    }
    [[ ! $varient =~ $varient ]] && echo "varient not found" && exit 1
    LOG "[Final] function args => suite=$suite varient=$varient"

    # Finally to get link
    arch=$(dpkg --print-architecture)
    link=$(cat $distro_data | jq -r ".$suite.$varient.${arch}url")
    name=$(cat $distro_data | jq -r ".$suite.$varient.Name")

    # echo "$link + $name"
    download "$name" "$link"

    # Start Extracting
    p_extract --file "$DLCACHE/$name" --path "$TODO_DIR"

}

login() {
    :
}

remove() {
    :
}

####################
downlaod() {
    local name=$1
    local link=$2

    axel -o ${DLCACHE}/$name $link
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
        *) echo "unkown option [$1]" ;;
    esac
done
