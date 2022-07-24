#!/bin/bash
## FORCE UPGRADE TO Jammy
# mirror method

DISTRO="jammy"
_MIRROR_PORTS="http://ports.ubuntu.com/ubuntu-ports/"
_MIRROR="http://archive.ubuntu.com/ubuntu/"

ask() {
	msg="$1"
	echo -ne "$msg [Y/N]: "
	read -r response

	case $response in
		"Y"|"y"|""|"yes"|"YES") return 0 ;;
		"N"|"n"|"no"|"NO") return 1 ;;
		*) return 1 ;;
	esac
}

function upgrade() {	
# set MIRROR
case $(run_cmd dpkg --print-architecture) in
        amd64|i386) MIRROR=$_MIRROR ;;
        *) MIRROR=$_MIRROR_PORTS ;;
esac


# Inject new sources.list file
# By default proot-distro changes directory to distro root!

[[ ! -f etc/apt/sources.list ]] && touch etc/apt/sources.list
[[ ! -w etc/apt/sources.list ]] && chmod +r+x etc/apt/sources.list

cat <<-  EOF > etc/apt/sources.list
# See http://help.ubuntu.com/community/UpgradeNotes for how to upgrade to
# newer versions of the distribution.
deb $MIRROR $SUITE main restricted
# deb-src $MIRROR $SUITE main restricted
## Major bug fix updates produced after the final release of the
## distribution.
deb $MIRROR $SUITE-updates main restricted
# deb-src $MIRROR $SUITE-updates main restricted
## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team. Also, please note that software in universe WILL NOT receive any
## review or updates from the Ubuntu security team.
deb $MIRROR $SUITE universe
# deb-src $MIRROR $SUITE universe
deb $MIRROR $SUITE-updates universe
# deb-src $MIRROR $SUITE-updates universe
## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team, and may not be under a free licence. Please satisfy yourself as to
## your rights to use the software. Also, please note that software in
## multiverse WILL NOT receive any review or updates from the Ubuntu
## security team.
deb $MIRROR $SUITE multiverse
# deb-src $MIRROR $SUITE multiverse
deb $MIRROR $SUITE-updates multiverse
# deb-src $MIRROR $SUITE-updates multiverse
## N.B. software from this repository may not have been tested as
## extensively as that contained in the main release, although it includes
## newer versions of some applications which may provide useful features.
## Also, please note that software in backports WILL NOT receive any review
## or updates from the Ubuntu security team.
deb $MIRROR $SUITE-backports main restricted universe multiverse
# deb-src $MIRROR $SUITE-backports main restricted universe multiverse
EOF

# Trigger apt [ update & upgrade ]

run_cmd apt update || apt-get update
run_cmd apt upgrade -y || apt upgrade -y
}

# get confirmation
echo "FORCE UPGRADE SCRIPT.."
sleep 2
echo "DISTRO=$DISTRO"
echo
echo "READ CAREFULLY"
echo
sleep 1
echo "as of july 14 both ubuntu 21.04 & ubuntu 21.10 reached to their end-of-life and no longer supported by ubuntu"
echo "this script force upgrade your linux distro to $DISTRO"
echo
echo "This script may take around ~2hrs depending on device speed to fully upgrade distro"

if ask "Do you want to continue ?"; then
	echo "get some snacks 🍪"
	sleep 1
	echo "watch a movie 🍿"
	sleep 1
	echo "This is gonna take some time!"
	sleep 2
	upgrade
	echo "👌 Upgrade function did its job!"
	echo "A script by udroid_team"
else
	echo "Upgrade skipped"
fi
