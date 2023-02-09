#!/bin/bash

#
# A quick script to force remove a proot installation
#

FS_PATH=$1
[[ -z $FS_PATH ]] && echo "no path provided" && exit 1
[[ ! -d $FS_PATH ]] && echo "path not found" && exit 1

# fix-up permissions
chmod u+rwx -R $FS_PATH > /dev/null 2>&1 || true

# remove files
if ! rm -rf $FS_PATH > /dev/null 2>&1; then
    echo "failed to remove files"
    exit 1
fi

