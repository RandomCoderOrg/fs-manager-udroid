#!/bin/bash

# (C) 2023 RandomCoderOrg, ubuntu-on-android
# help_udroid.sh: A part of udroid scripts
# To show help messages for different options in udroid scripts
# 

# help_login: show help for login
# TODO: document --custom|--custom-distro|-cd
help_login() {
    echo "udroid [ login| --login ] [<options>] <suite>:<varient> <cmd>"
    echo "login to a suite"
    echo
    echo "options:"
    echo "  -h, --help:         show this help message and exit"
    echo "  --user:               Allows the user to specify the login user for the filesystem."
    # echo "-p or --path:         Allows the user to set a custom installation path for the filesystem instead of the default directory."
    echo "  -cd, --custom-distro <name>: Allows the user to specify a custom distro for the filesystem."
    echo "  --bind or -b:         Allows the user to specify extra mount points for the filesystem."
    echo "  --isolated:           Creates an isolated environment for the filesystem."
    echo "  --ashmem-memfd | --memfd     enable support for memfd emulation through ashmem ( experimental )"
    echo "  --fix-low-ports:      Fixes low ports for the filesystem."
    echo "  --no-shared-tmp:      Disables shared tmp for the filesystem."
    echo "  --no-link2symlink:    Disables link2symlink for the filesystem."
    echo "  --no-sysvipc:         Disables sysvipc for the filesystem."
    echo "  --no-fake-root-id:    Disables fake root id for the filesystem."
    echo "  --no-cap-last-cap:    Disables cap last cap fix mount for the filesystem.(only per session)"
    # echo "--no-cwd-active-directory | --ncwd (unstable): Disables the current working directory for the active directory for the filesystem."
    echo "  --no-kill-on-exit:    Disables kill on exit for the filesystem."
    echo
    echo "<cmd>:"
    echo "  command to run in the filesystem and exit"
}

# help_root: show help when no option is given or every option is invalid
help_root() {
    echo "udroid <option> [<options>] [<suite>]:[<varient>]"
    echo
    echo "options:"
    echo "  install, -i [<options>] <suite>:<varient>  install a distro"
    echo "  remove, --remove <suite>:<varient>    remove a distro"
    echo "  reset, --reset <suite>:<varient>      reinstalls a distro"
    echo "  list, --list [options]                list distros"
    echo "  login, --login <suite>:<varient>      login to a distro"
    echo "  upgrade, --upgrade                    upgrade udroid scripts"
    echo "  help, --help                          show this help message and exit"
    echo "  --update-cache                        update cache from remote"  
    echo "  --clear-cache                         clear downloaded cache"      
    echo
}

# help_list: show help for list
help_list() {
    echo "udroid [ list| --list ] [options]"
    echo "show a table of all available distros/suites"
    echo "options:"
    echo "  -h, --help              show this help message and exit"
    echo "  --size                  show size of each distro"
    echo "  --show-custom-fs        show custom filesystems"
    echo "  --download-size | --ds   show download size of each distro"
    echo "  --path <path>           path to look for distros"
    echo "  --list-installed        show only installed distros"
}

# help_upgrade: show help for upgrade
help_install() {
    echo "udroid [ install| --install ] [<options>] [<suite>]:[<varient>]"
    echo "installs udroid distros"
    echo "options:"
    echo "  -cd, --custom-distro <options>  install a custom distro"
    echo "  -h, --help    show this help message and exit"
    echo "  --no-verify-integrity  do not verify integrity of filesystem"
    echo
    echo "custom distro options:"
    echo "  --file <file>  full path to filesystem tarball"
    echo "  --name <name>  name for the filesystem"
    echo
    echo "example:"
    echo "  udroid install jammy:raw"
    echo "  udroid install --install jammy:raw"
}

# help_upgrade: show help for upgrade
help_remove() {
    echo "udroid [ remove| --remove ] <distro>"
    echo "removes udroid distros"
    echo "options:"
    echo "  -h, --help    show this help message and exit"
    echo "  -cd, --custom-distro <name>  remove a custom installed distro"
    echo "example:"
    echo "  udroid remove jammy:raw"
    echo "  udroid remove --remove jammy:raw"
}
