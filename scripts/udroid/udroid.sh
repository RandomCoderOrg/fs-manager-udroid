#!/bin/bash

TERMUX="/data/data/com.termux/files"
D_SCRIPTS="${TERMUX}/usr/etc/proot-distro"
D_INSTALLED_ROOTFS="${TERMUX}/usr/var/lib/proot-distro/installed-rootfs"
D_CACHCE="${HOME}/.udroid-cache-root"
LOGIN_CACHE_FILE="${D_CACHCE}/login_rec.cache"

_c_magneta="\e[95m"
_c_green="\e[32m"
_c_red="\e[31m"
_c_blue="\e[34m"
RST="\e[0m"

die()    { echo -e "${_c_red}[E] ${*}${RST}";exit 1;:;}
warn()   { echo -e "${_c_red}[W] ${*}${RST}";:;}
shout()  { echo -e "${_c_blue}[-] ${*}${RST}";:;}
lshout() { echo -e "${_c_blue}-> ${*}${RST}";:;}
imsg()	 { if [ -n "$UDROID_VERBOSE" ]; then echo -e ": ${*} \e[0m" >&2;fi;:;}
msg()    { echo -e "${*} \e[0m" >&2;:;}

_satisfy_deps() {
	### Deps
	for deb in {proot-distro,proot,tar}; do
		if ! command -v $deb >> /dev/null; then
			missing_debs="$deb $missing_debs"
		fi
	done

	if [ -n "$missing_debs" ]; then
		shout "Trying to install required packages..."
		apt install -y $missing_debs
	fi
}

_login() {

	varient=$1; shift
	extra_args=$*

	cd "$D_INSTALLED_ROOTFS" || die "$D_INSTALLED_ROOTFS Not Found.."
	avalible_distros=$(find $D_INSTALLED_ROOTFS -maxdepth 1 -type d | grep udroid)
	cd "$OLDPWD" || exit

	if [ -z "$UDROID_SUITE" ] || [ -z "$_SUITE" ] ; then
		suite="udroid-focal"
	else
		suite="$UDROID_SUITE"
		msg "udroid suite is set to ${UDROID_SUITE}"
	fi

	distro="$suite-$varient"
	if [[ $avalible_distros =~ $distro ]]; then
		# store distro aliases in cache
		echo "$distro" > "$LOGIN_CACHE_FILE"

		# start distro
		start "$distro" $extra_args
	else
		# TODO: ADD SUGGESTIONS
		lwarn "$distro not found..."
	fi
}

start() {

	distro=$1; shift
	extra_args=$*

	# start Pulse Audio tcp receiver

	imsg "Starting pulseaudio at 127.0.0.1"

	# TODO: CHECK IS Pulseaudio RUNNING BEFORE EXECUTING
	pulseaudio \
		--start \
		--load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" \
		--exit-idle-time=-1 >> /dev/null

	imsg "Starting $distro.. with args\n--bind /dev/null:/proc/sys/kernel/cap_last_cap\n--shared-tmp "
	proot-distro login "$distro" --bind /dev/null:/proc/sys/kernel/cap_last_cap \
	--shared-tmp \
	$extra_args
}

l_login() {
	avalible_distros=$(find $D_INSTALLED_ROOTFS -maxdepth 1 -type d | grep udroid)

	if [ -s "$LOGIN_CACHE_FILE" ]; then
		start "$(cat LOGIN_CACHE_FILE)"
	else
		lshout "No distro found in login cache.."
		# show avalible distros
		msg "${_c_blue}Available distros to login:"
		for distro in $avalible_distros; do
			msg "  ${_c_magneta}$(basename $distro)${RST}"
		done
		msg

		msg "${_c_blue}use ${_c_magneta}udroid -l <distro>${RST} to login"
		msg "ex: ${_c_magneta}udroid -l xfce4${RST}"
	fi
}


_install() {
	SUITE=$1
	
	# make sure to satisy old docs
	if [ -z "$SUITE" ]; then
		imsg "falling back to defaults"
		SUITE="xfce4"
	fi

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
		die "$SUITE already installed."
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

	avalible_distros=$(find $D_INSTALLED_ROOTFS -maxdepth 1 -type d | grep udroid)
	varient=$1

	if [ -z "$UDROID_SUITE" ] || [ -z "$_SUITE" ] ; then
		_suite="udroid-focal"
	else
		_suite="$UDROID_SUITE"
		msg "udroid suite is set to ${UDROID_SUITE}"
	fi
	suite="${_suite}-$varient"
	if is_installed "$suite" && [[ $avalible_distros =~ $distro ]]; then
		imsg "Executing $(which proot-distro) reset $suite"
		proot-distro reset $suite
	else
		lwarn "$SUITE is not installed."
	fi
}

remove() {
	avalible_distros=$(find $D_INSTALLED_ROOTFS -maxdepth 1 -type d | grep udroid)
	varient=$1

	if [ -z "$UDROID_SUITE" ] || [ -z "$_SUITE" ] ; then
		_suite="udroid-focal"
	else
		_suite="$UDROID_SUITE"
		msg "udroid suite is set to ${UDROID_SUITE}"
	fi
	suite="${_suite}-$varient"

    if is_installed "$suite"; then
            proot-distro remove $suite
    else
            lwarn "$SUITE is not installed."
    fi
}

upgrade() {
	shout "Upgrade.."
	url_host="https://raw.githubusercontent.com"
	url_org="/RandomCoderOrg"
	repo="/fs-manager-udroid"
	
	if [ -n "$OVERRIDE_BRANCH" ]; then
		BRANCH=$OVERRIDE_BRANCH
	else
		BRANCH="main"
	fi

	path="/$BRANCH/scripts/udroid/udroid.sh"
	url="$url_host$url_org$repo$path"
	lshout "Sync tool with GitHub..."
	download "$url" "$TERMUX/usr/bin/udroid" || {
		lwarn "failed to sync tool with GitHub"
		exit 1
	}
	chmod +x "$TERMUX/usr/bin/udroid"
	lshout "Sync tool with GitHub...done"
}

is_installed() {
	target_suite=$1
	
	if [ ! -f "${D_SCRIPTS}/${target_suite}.sh" ]; then
		return 1
	fi

	if [ ! -d "${D_INSTALLED_ROOTFS}/${target_suite}" ]; then
		return 1
	fi

	return 0
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

# make sure of required packages before any option
_satisfy_deps

while [ $# -gt 0 ]; do
	case $1 in
		--suite) shift; _SUITE="$1" ;;
		-l) shift; _login $* ;;
		-i|--install) shift;_install $1; exit 0 ;;
		-re|--reset) shift ; _reset $1; exit 0 ;;
		-r|--remove) shift ; _remove $1; exit 0 ;;
		-S|--sync|--upgrade) upgrade; exit 0 ;;
		*) l_login $*;;
	esac
done

