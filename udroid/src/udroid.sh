#!/bin/bash

[[ ! -f proot-utils/proot-utils.sh ]] && echo "proot-utils.sh not found" && exit 1
[[ ! -f gum_wrapper.sh ]] && echo "gum_wrapper.sh not found" && exit 1

source proot-utils/proot-utils.sh
source gum_wrapper.sh

install() {
    local arg=$1
    local suite=${arg%%:*}
    local varient=${arg#*:}

    LOG "function args => suite=$suite varient=$varient"

    # check if seperator is present
    [[ $(echo $arg | awk '/:/' | wc -l) == 0 ]] && {
        ELOG "seperator not found"
        LOG "trying to guess what does that mean"

        if [[ $(cat $file | jq -r '.suites[]') =~ $arg ]]; then
            LOG "found suite [$arg]"
            suite=$arg
            varient=""
        else
            for _suites in $(cat $file | jq -r '.suites[]'); do
                for _varients in $(cat $file | jq -r ".${_suites}.varients[]"); do
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


    suites=$(cat $file | jq -r '.suites[]')

    [[ -z $suite ]] && {
        suite=$(g_choose $(cat $file | jq -r '.suites[]'))
    }
    [[ ! $suites =~ $suite ]] && echo "suite not found" && exit 1

    [[ -z $varient ]] && {
        varient=$(g_choose $(cat $file | jq -r ".$suite.varients[]"))
    }
    [[ ! $varient =~ $varient ]] && echo "varient not found" && exit 1
    LOG "function args => suite=$suite varient=$varient"

    # Finally to get link
}

login() {
    :
}

remove() {
    :
}

####################



while [ $# -gt 0 ]; do
    case $1 in
        --install|-i)   ;;
        --login|-l)     ;;
        --remove | --uninstall ) ;;
    esac
done
