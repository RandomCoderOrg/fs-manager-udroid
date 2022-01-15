#!/bin/bash

TERMUX="/data/data/com.termux/files"
D_SCRIPTS="${TERMUX}/usr/etc/proot-distro"
D_INSTALLED_ROOTDS="${TERMUX}/usr/var/lib/proot-distro/installed-rootfs"

die()    { echo -e "${RED}[E] ${*}${RST}";exit 1;:;}
warn()   { echo -e "${RED}[W] ${*}${RST}";:;}
shout()  { echo -e "${DS}[-] ${*}${RST}";:;}
lshout() { echo -e "${DC}-> ${*}${RST}";:;}
msg()    { echo -e "${*} \e[0m" >&2;:;}

_login() {
	case $1 in
		mate) SUITE="mate" shift ;;
		xfce|xfce4) SUITE="xfce4" shift ;;
		kde) SUITE="kde" shift ;;
		*) l_login $*;;
	esac

	if [ $# -gt 0 ]; then
		extra_args=$*
	fi

	suite="udroid-impish-$SUITE"

	if is_installed $suite; then
		l_cache "$suite"
		proot-distro login udroid \
		--bind /dev/null:/proc/sys/kernel/cap_last_cap \
		--shared-tmp \
		$extra_args
	else
		msg "looks like $SUITE is not installed."
		msg "use udroid -i $SUITE"
	fi

}

l_login() {
	if [ -f "${HOME}/.udroid/logindistro_cache" ]; then
		if [ -s "${HOME}/.udroid/logindistro_cache" ]; then
			login "$(${HOME}/.udroid/logindistro_cache)" $*
		fi
	else
		_msg "login"
	fi
}


_install() {
	SUITE=$1
	plugin_loation="https://raw.githubusercontent.com/RandomCoderOrg/ubuntu-on-android/beta/pd-plugins"

	final_suite="udroid-impish-$SUITE"

	if is_installed $final_suite; then
		msg "$SUITE already installed."
		exit 1
	fi

	shout "Installing $final_suite"
	if [ ! -f "${D_SCRIPTS}/${final_suite}.sh" ] ; then
		download "${plugin_loaction}/${final_suite}.sh" $D_SCRIPTS
	fi
	shout "starting proot-distro"
	proot-distro install $final_suite
}

l_cache() {
	if [ ! -d ${HOME}/.udroid ]; then
		mkdir ${HOME}/.udroid
	fi

	cat $1 > ${HOME}/.udroid/logindistro_cache
}

download() {
	url=$1
	location=$2
	curl -L -o $location $url
}

if [ $# -ge 0 ]; then
	case $1 in
		-l) shift  _login $* ;;
		-i|--install) shift _install $1 ;;
		*) l_login $*;;
	esac
fi
