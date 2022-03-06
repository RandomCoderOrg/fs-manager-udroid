#!/bin/bash

TERMUX="/data/data/com.termux/files"
D_SCRIPTS="${TERMUX}/usr/etc/proot-distro"
D_INSTALLED_ROOTFS="${TERMUX}/usr/var/lib/proot-distro/installed-rootfs"
D_CACHCE="${HOME}/.udroid-cache-root"

_c_magneta="\e[95m"
_c_green="\e[32m"
_c_red="\e[31m"
_c_blue="\e[34m"
RST="\e[0m"

die()    { echo -e "${_c_red}[E] ${*}${RST}";exit 1;:;}
warn()   { echo -e "${_c_red}[W] ${*}${RST}";:;}
shout()  { echo -e "${_c_blue}[-] ${*}${RST}";:;}
lshout() { echo -e "${_c_blue}-> ${*}${RST}";:;}
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
		
		pulseaudio \
			--start \
			--load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" \
			--exit-idle-time=-1 >> /dev/null

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
	
	# relative path of plugins with respect to pd-plugins dir
	# set this when you need to install another suite
	if [ -n "$OVERRIDE_REMOTE_PLUGIN_DIR" ]; then
		warn "overriding remote plugin dir with $OVERRIDE_REMOTE_PLUGIN_DIR"
		REMOTE_PLUGIN_DIR=$OVERRIDE_REMOTE_PLUGIN_DIR
	else
		REMOTE_PLUGIN_DIR="default"
	fi

	# set this to pull plugins from another branch
	if [ -n "$OVERRIDE_BRANCH" ]; then
		warn "overriding branch to $OVERRIDE_BRANCH"
		BRANCH=$OVERRIDE_BRANCH
	else
		BRANCH="modified"
	fi

	plugin_location="https://raw.githubusercontent.com/RandomCoderOrg/ubuntu-on-android/$BRANCH/pd-plugins/$REMOTE_PLUGIN_DIR"

	# pull and parse plugin properties
	download $plugin_location/plugins.prop "$D_CACHCE"/plugins.prop

	source $D_CACHCE/plugins.prop || die "failed to parse plugin data..?"
	
	for v in "${avalibe_varients[@]}"; do
		if [ "$v" == "$SUITE" ]; then
			varient=$SUITE
		fi
	done
	
	if [ -z "$varient" ]; then
		warn "unknown varient: $SUITE"
		msg "varients founds: ${avalibe_varients[*]}"
		die "installation failed."
	fi

	final_suite="udroid-$suite-$varient"
	local_target="${D_SCRIPTS}/${final_suite}.sh"
	if is_installed $final_suite; then
		msg "$SUITE already installed."
		exit 1
	fi

	shout "Installing $final_suite"
	if [ ! -f "${D_SCRIPTS}/${final_suite}.sh" ] ; then
		download "${plugin_location}/${final_suite}.sh" $local_target 
	fi
	shout "starting proot-distro"
	proot-distro install $final_suite
}
_reset() {
	case $1 in
                mate) SUITE="mate";;
                xfce|xfce4) SUITE="xfce4" ;;
                kde) SUITE="kde";;	
	esac

	suite="udroid-impish-$SUITE"

	if is_installed "$suite"; then
		proot-distro reset $suite
	else
		lwarn "$SUITE is not installed."
	fi
}

_remove() {
        case $1 in
                mate) SUITE="mate";;
                xfce|xfce4) SUITE="xfce4" ;;
                kde) SUITE="kde";;
        esac

        suite="udroid-impish-$SUITE"

        if is_installed "$suite"; then
                proot-distro remove $suite
        else
                lwarn "$SUITE is not installed."
        fi
}

is_installed() {
	target_suite=$1
	
	if [ ! -f "${D_SCRIPTS}/${target_suite}.sh" ]; then
		return 1
	fi

	if [ ! -d "${D_INSTALLED_ROOTFS}/${target_suite}.sh" ]; then
		return 1
	fi

	return 0
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
	curl -L -o $location $url || {
		die "Download operation failed."
	}
}

# make sure to create cache dir first
if [ ! -d "$D_CACHCE" ]; then
	mkdir -p "$D_CACHCE"
fi

if [ $# -ge 0 ]; then
	case $1 in
		-l) shift; _login $* ;;
		-i|--install) shift;_install $1 ;;
		-re|--reset) shift ; _reset $1 ;;
		-r|--remove) shift ; _remove $1 ;;
		*) l_login $*;;
	esac
fi

