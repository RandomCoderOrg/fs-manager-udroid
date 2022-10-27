#!/bin/bash

[[ -z $TMPDIR ]] && TMPDIR=/tmp
ERROR_DUMP_FILE="$TMPDIR/proot-utils.log"

msg() { echo -e "${*} \e[0m" >&2;:;}
ELOG() { echo "[$(date +%F) | $(date +%R)] Error: ${*}" >> "${ERROR_DUMP_FILE}";:;}
LOG() { echo "[$(date +%F) | $(date +%R)] MSG:${*}" >> "${ERROR_DUMP_FILE}";:;}

p_extract() {
    # OPTIONS:
    # --path -> to set custom path
    # --file | -f -> location of the file to extract

    local NO_PROG=false

    while [ $# -gt 0 ]; do
        case $1 in
            --file | -f)        file=$2; shift 2 ;;
            --path)             path=$2; shift 2 ;;
            --disable-progress) NO_PROG=true    ;;
            *)
                msg "unkown option [$1]"
                shift 1
                ;;
        esac
    done

    [[ -z $file ]] && msg "file not specified" && return 1
    [[ -z $path ]] && echo "no path provided"  && exit 1
    [[ ! -f $file ]] && msg "file not found" && return 1
    [[ ! -d $path ]] && msg "path not found" && return 1

    if ! $NO_PROG; then
        pv $file | proot \
                --link2symlink \
                tar --no-same-owner -xvz -C "$path" &> $ERROR_DUMP_FILE
    else
        proot \
                --link2symlink \
                tar --no-same-owner -xvz -C "$path" < $file
    fi
}

is_valid_rootfs() {
    local path=$1

    [[ -d $1/usr ]] && [[ -d $1/lib ]] && [[ -f $1/usr/bin/env ]] && {
        [[ -f /usr/bin/sh ]] || [[ -f /bin/bash ]] || [[ -f /bin/sh ]]
    } && return 0 || return 1
}

p_login() {
    # OPTIONS:
    # --disable-special-mounts
    # --disable-auto-init
    # --disable progress

    local root_fs_path
    local container_user

    while [ $# -gt 0 ]; do
        case $1 in
        --disable-special-mounts) NO_S_M=true;;
        --disable-auto-init) NO_A_I=true;;
        --path) root_fs_path=$2; shift 2;;
        # -b | --bind ) bind=$2; shift 2;;
        -u | --user ) container_user=$2; shift 2;;
        --) shift 1; cmd_string=$*; break;;
        *) break ;;
        esac
    done

    # user logic
    [[ -z $container_user ]] && container_user="root"
    # TODO: Make it good :)

    unset LD_PRELOAD
    proot \
        --link2symlink \
        --sysvipc \
        --kill-on-exit \
        -b /system \
        -b /sys \
        -b /proc \
        -b /dev \
        -b /dev/urandom:/dev/random \
        -b /proc/self/fd/1:/dev/stdout \
        -b /proc/self/fd/2:/dev/stderr \
        -b /proc/self/fd/0:/dev/stdin \
        -b /proc/self/fd:/dev/fd \
        -b ${root_fs_path}/proc/.vmstat:/proc/vmstat \
        -b ${root_fs_path}/proc/.version:/proc/version \
        -b ${root_fs_path}/proc/.uptime:/proc/uptime \
        -b ${root_fs_path}/proc/.stat:/proc/stat \
        -b ${root_fs_path}/proc/.loadavg:/proc/loadavg \
        -b /linkerconfig/ld.config.txt \
        -b /data/data/com.termux/files/usr \
        -b /data/data/com.termux/files/home \
        -b /data/data/com.termux/cache \
        -b /storage/self/primary:/sdcard \
        -b ${root_fs_path}/tmp:/dev/shm \
        --root-id \
        --cwd=/root -L \
        --kernel-release=5.4.0-faked \
        --sysvipc \
        --kill-on-exit \
        --rootfs=${root_fs_path} \
        -w /root \
            /usr/bin/env -i \
            HOME=/root \
            PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin \
            TERM=$TERM \
            LANG=C.UTF-8 \
            /bin/su -l $container_user \
            $cmd_string

}

if [ -n "$RUN_STANDALONE" ]; then
    while [ $# -gt 0 ]; do
        case $1 in
            --install|-i)   ;;
            --login|-l) shift 1; login $*; break    ;;
            --extract)  shift 1; extract $*; break  ;;
            --uninstall|-u) ;;
        esac
    done
fi
