#!/bin/bash

help_login() {
    # TODO: Add help for login
    :
}

help_list() {
    echo "udroid [ list| --list ] [options]"
    echo "options:"
    echo "  -h, --help    show this help message and exit"
    echo "  --size        show size of each distro"
    echo "  --path <path> path to look for distros"
    echo "  --list-installed  show only installed distros"
}

help_install() {
    echo "udroid [ install| --install ] <distro>"
    echo "installs udroid distros"
    echo "example:"
    echo "  udroid install jammy:raw"
    echo "  udroid install --install jammy:raw"
}

help_remove() {
    echo "udroid [ remove| --remove ] <distro>"
    echo "removes udroid distros"
    echo "example:"
    echo "  udroid remove jammy:raw"
    echo "  udroid remove --remove jammy:raw"
}
