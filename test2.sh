#                                                                    
# █▀▀ █▀█ █░█     ▄▀█ █▀▀ █▀▀ █▀▀ █░   ░ ▄▀ █░█ █▀ █ █▄░█ █▀▀    ▀█ █ █▄░█ █▄▀ ▀▄
# █▄█ █▀▀ █▄█     █▀█ █▄▄ █▄▄ ██▄ █▄▄    ▀▄ █▄█ ▄█ █ █░▀█ █▄█    █▄ █ █░▀█ █░█ ▄▀
#
# AUTOMATED BY Thundersnow#7929, ThatMG393
# PATCHES MADE BY Thundersnow#7929, Twaik Yont (https://github.com/Twaik)

export DISPLAY=:0
export XDG_RUNTIME_DIR="$PREFIX/tmp"

clear -x

# Might go below 2 or 1
CORES="$(( $(nproc)-2 ))"

# Possible values can only be 'enable', 'fix', and 'disable'
# Putting another values will just disable xf86bigfont
USE_XF86BF="fix"

# Possible values can only be 'yes' and 'no'
# Putting another values will just disable the DRI3 feature
ENABLE_DRI3="yes"

# Utils / Helpers
# Yoink from UDroid
DIE() { echo -e "\e[1;31m${*}\e[0m"; exit 1 ;:; }
WARN() { echo -e "\e[1;33m${*}\e[0m";:; }

INFO_NewLineAbove() { echo ""; echo -e "\e[1;32m${*}\e[0m";:; }
INFO_NoNewLineAbove() { echo -e "\e[1;32m${*}\e[0m";:; }
INFO_NLANoNextLine() { echo ""; echo -n -e "\e[1;32m${*}\e[0m";:; }
INFO_NoNLANoNextLine() { echo -n -e "\e[1;32m${*}\e[0m";:; }

TITLE() { echo -e "\e[100m${*}\e[0m";:; }

[ -d "/usr" ] && DIE "Building inside a proot is not supported!"

RM_SILENT() { WARN "Removing: $*"; rm -rf $* &> /dev/null ;:; }

MKDIR_NO_ERR() { if [ ! -d $1 ]; then mkdir -p $1; else WARN "Directory '$1' already exists!"; fi ;:; } 
CD_NO_ERR() { if [ ! -d $1 ]; then MKDIR_NO_ERR $1; fi; cd $1 ;:; } 

CLONE() { if [ "$2" = "latest" ]; then git clone -q --depth=$3 "$1"; else git clone -q --depth=$3 -b "$2" "$1"; fi ;:; }

SIG_HANDLER() {
	clear -x
	DIE "Immediately cancelling as the user requested..."
}

trap 'SIG_HANDLER' TERM HUP

ERR_LOGS="\nLogs:\n"

ERR_HANDLER() {
	WARN "Uh oh, something terrible has gone wrong!"
	ERR_LOGS+="Line ${1} exited with code ${2}\n"
}

trap 'ERR_HANDLER $LINENO $?' ERR

MAIN_FOLDER="$HOME/gpu_accel"
MKDIR_NO_ERR "$MAIN_FOLDER"

TMP_FOLDER="$MAIN_FOLDER/tmp"

DEPENDENCIES="vulkaninfo git pv wget"

INFO_NewLineAbove "Checking for '$DEPENDENCIES'..."
WARN "If it hangs or takes too long, try to do it manually!"
WARN "pkg in $DEPENDENCIES"

for DEPENDENCY in $DEPENDENCIES; do
	if [[ ! -n $(command -v $DEPENDENCY) || $( $DEPENDENCY --help |& grep "(No such file or directory|Command not found)" | wc -l ) == 1 ]]; then
		INFO_NewLineAbove "Downloading '$DEPENDENCY'..."
		if [ "$DEPENDENCY" = "vulkaninfo" ]; then
			pkg install vulkan-tools -y && {
				INFO_NoNewLineAbove "Success!" 
			} || {
				DIE "Failed!"
			}
		else
			pkg install $DEPENDENCY -y && {
				INFO_NoNewLineAbove "Success!" 
			} || {
				DIE "Failed!"
			}
		fi
	else
		INFO_NoNewLineAbove "'$DEPENDENCY' already installed!"
	fi
done
INFO_NewLineAbove "Done!"

clear -x

echo ""
TITLE " █▀▀ █▀█ █░█     ▄▀█ █▀▀ █▀▀ █▀▀ █░   ░ ▄▀ █░█ █▀ █ █▄░█ █▀▀    ▀█ █ █▄░█ █▄▀ ▀▄  "
TITLE " █▄█ █▀▀ █▄█     █▀█ █▄▄ █▄▄ ██▄ █▄▄    ▀▄ █▄█ ▄█ █ █░▀█ █▄█    █▄ █ █░▀█ █░█ ▄▀  "
INFO_NewLineAbove "Activating GPU Acceleration (via Zink)"

INFO_NewLineAbove "Checking for requirements..."

GPU_REQ_FEATURES=$( vulkaninfo | grep -oE '(VK_KHR_maintenance1|VK_KHR_create_renderpass2|VK_KHR_imageless_framebuffer|VK_KHR_descriptor_update_template|VK_KHR_timeline_semaphore|VK_EXT_transform_feedback)' | wc -l )

INFO_NLANoNextLine "Does GPU has feature VK_KHR_maintenance1, VK_KHR_create_renderpass2, VK_KHR_imageless_framebuffer, VK_KHR_descriptor_update_template, VK_KHR_timeline_semaphore, and VK_EXT_transform_feedback?"
if [[ $GPU_REQ_FEATURES == 6 ]]; then
	echo " yes"
elif [[ $GPU_REQ_FEATURES == 5 ]]; then
	echo ""
	INFO_NewLineAbove "Wait for another script that installs the old supported version..."
	exit 1
else
	echo " no"
	
	DIE "Double check using 'vulkaninfo | grep -oE '(VK_KHR_maintenance1|VK_KHR_create_renderpass2|VK_KHR_imageless_framebuffer|VK_KHR_descriptor_update_template|VK_KHR_timeline_semaphore|VK_EXT_transform_feedback)''"
	exit 1
fi

GPU_DRIVER_VERSION=$( vulkaninfo | grep driverVersion | cut -d ' ' -f7 | tr -d '.' )

#FIXME: Add Qualcomm/PowerVR Version compare logic
INFO_NLANoNextLine "Is the GPU driver version greater than or equal to '38.1.0'? "
if [ $GPU_DRIVER_VERSION -ge 3810 ]; then
	echo " yes"
	
	INFO_NoNewLineAbove "If your GPU Model is made by Qualcomm or PowerVR then try to increase the '3810' in the script. (Line 111, near '-ge')"
	DIE "GPU driver version >= 38.1.0 is unsupported!"
else
	echo " no"
fi

PATCHES_TAR_GZ="$MAIN_FOLDER/patches.tar.gz"
PATCHES_TAR_GZ_SHA="340578182408ff50d9e23e104513892690325de29fc1ebf901d03e42f8c04ff5"

# Source:
# Thundersnow#7929
MESA_PATCH_FILE="$MAIN_FOLDER/mesa20230212.patch"
MESA_PATCH_FILE_SHA="2f8ce934cb595e7988b9a742754b4ea54335b35451caa143ffd81332a1816c66"
XSERVER_PATCH_FILE="$MAIN_FOLDER/xserver.patch"
XSERVER_PATCH_FILE_SHA="bc4612d0d80876af4bbbec5270e89f80eef4a3068f6ff25f82c97da7098d3698"
# ------

# Source:
# https://github.com/termux/termux-packages/tree/master/x11-packages/virglrenderer-android
VIRGL_DIFF_FILE="$MAIN_FOLDER/virglrenderer.diff"
VIRGL_DIFF_FILE_SHA="dc9e29ca724833c7d7a1f9d1c5f32eb0d9e998aa7ae7f6656580af20509aa38f"
# -------


INFO_NewLineAbove "Checking for patches and diff files..."

INFO_NewLineAbove "Check for file existence..."
if [[ ! -f "$MESA_PATCH_FILE" || ! -f "$XSERVER_PATCH_FILE" || ! -f "$VIRGL_DIFF_FILE" ]]; then
	WARN "Files doesn't exists!"

	INFO_NewLineAbove "Fetching & Extracting 'patches.tar.gz'"
	WARN "This might take a while..."
	
	RM_SILENT "$PATCHES_TAR_GZ" "$MESA_PATCH_FILE" "$XSERVER_PATCH_FILE" "$VIRGL_DIFF_FILE"
	
	CD_NO_ERR "$MAIN_FOLDER"
	
	[ ! -f "$PATCHES_TAR_GZ" ] && {
		RM_SILENT "$PATCHES_TAR_GZ"  # Sanity
		wget -q --show-progress --progress=bar:force https://raw.githubusercontent.com/ThatMG393/gpu_accel_termux/master/patches.tar.gz 2>&1 && {
			INFO_NoNewLineAbove "Success! (1/2)"
		} || {
			DIE "Failed to fetch 'patches.tar.gz'. Is 'wget' installed? Try doing 'yes | pkg up -y && pkg in wget -y'"
		}
		
		tar -xvf $PATCHES_TAR_GZ && {
			INFO_NoNewLineAbove "\33[2K\rSuccess! (2/2)"
		} || {
			DIE "Failed to extract 'patches.tar.gz'. Is 'wget' and 'tar' installed? Try re-running the script."
		}
	} || {
		tar -xvf $PATCHES_TAR_GZ && {
			INFO_NoNewLineAbove "\33[2K\rSuccess! (2/2)"
		} || {
			DIE "Failed to extract 'patches.tar.gz'. Is 'wget' and 'tar' installed? Try re-running the script."
		}
	}
else
	INFO_NoNewLineAbove "Passed! (1/2)"
fi

INFO_NewLineAbove "Checking for checksum..."
if [[ "$(sha256sum "$PATCHES_TAR_GZ" | cut -d' ' -f1)" != "$PATCHES_TAR_GZ_SHA" ]] || [[ "$(sha256sum "$MESA_PATCH_FILE" | cut -d' ' -f1)" != "$MESA_PATCH_FILE_SHA" ]] || [[ "$(sha256sum "$XSERVER_PATCH_FILE" | cut -d' ' -f1)" != "$XSERVER_PATCH_FILE_SHA" ]] || [[ "$(sha256sum "$VIRGL_DIFF_FILE" | cut -d' ' -f1)" != "$VIRGL_DIFF_FILE_SHA" ]]; then
	WARN "Checksum check failed! Re-installing"

	INFO_NewLineAbove "Fetching & Extracting 'patches.tar.gz'"
	WARN "This might take a while..."
	
	RM_SILENT "$PATCHES_TAR_GZ" "$MESA_PATCH_FILE" "$XSERVER_PATCH_FILE" "$VIRGL_DIFF_FILE"
	
	CD_NO_ERR "$MAIN_FOLDER"

	[ ! -f "$PATCHES_TAR_GZ" ] && {
		RM_SILENT "$PATCHES_TAR_GZ"  # Sanity
		wget -q --show-progress --progress=bar:force https://raw.githubusercontent.com/ThatMG393/gpu_accel_termux/master/patches.tar.gz 2>&1 && {
			INFO_NoNewLineAbove "Success! (1/2)"
		} || {
			DIE "Failed to fetch 'patches.tar.gz'. Is 'wget' installed? Try doing 'yes | pkg up -y && pkg in wget -y'"
		}
		
		tar -xvf $PATCHES_TAR_GZ && {
			INFO_NoNewLineAbove "\33[2K\rSuccess! (2/2)"
		} || {
			DIE "Failed to extract 'patches.tar.gz'. Is 'wget' and 'tar' installed? Try re-running the script."
		}
	} || {
		tar -xvf $PATCHES_TAR_GZ && {
			INFO_NoNewLineAbove "\33[2K\rSuccess! (2/2)"
		} || {
			DIE "Failed to extract 'patches.tar.gz'. Is 'wget' and 'tar' installed? Try re-running the script."
		}
	}
else
	INFO_NoNewLineAbove "\33[2K\rPassed! (2/2)"
fi

INFO_NewLineAbove "You passed the requirements, congrats! Prepare for automatic install. Please keep Termux in focus and don't close Termux..."

#### MAIN LOGIC ####

echo ""
WARN "Auto compile & install is starting in 4s, interrupt (Ctrl-C) now if ran accidentally"

sleep 4
clear -x

TITLE "AUTO INSTALLATION STARTED"

INFO_NewLineAbove "Checking for x11-repo"
pkg install x11-repo -y

INFO_NoNewLineAbove "Installing build systems & binaries"
pkg install \
		clang lld binutils \
		cmake autoconf automake libtool \
		ndk-sysroot ndk-multilib \
		make python python-pip git \
		libandroid-shmem-static \
		vulkan-tools vulkan-headers vulkan-loader-android\
		ninja llvm bison flex \
		libx11 xorgproto libdrm \
		libpixman libxfixes \
		libjpeg-turbo xtrans libxxf86vm xorg-xrandr \
		xorg-font-util xorg-util-macros libxfont2 \
		libxkbfile libpciaccess xcb-util-renderutil \
		xcb-util-image xcb-util-keysyms \
		xcb-util-wm xorg-xkbcomp \
		xkeyboard-config libxdamage libxinerama -y

INFO_NoNewLineAbove "Installing meson & mako"
pip install meson mako 

clear -x

[ -d "$TMP_FOLDER" ] && (( $(ls "$TMP_FOLDER" | wc -l) != 0 )) && {
	INFO_NoNLANoNextLine "The repositories folder already exists do you want to re-clone the repositories? (y|n) "
	
	read -p "" ANSWER
	
	case $ANSWER in
		y | Y | yes ) RM_SILENT "$TMP_FOLDER" ;;
		n | N | no  ) INFO_NewLineAbove "Skipping..." ;;
	esac
}

CD_NO_ERR "$TMP_FOLDER"

clear -x
INFO_NoNewLineAbove "Cloning repositories..."

INFO_NewLineAbove "Cloning 'mesa'"
WARN "This repository takes very long to clone, don't panic!"
CLONE "https://gitlab.freedesktop.org/mesa/mesa.git" "latest" 1
INFO_NoNewLineAbove "Cloning 'virglrenderer'"
CLONE "https://gitlab.freedesktop.org/virgl/virglrenderer.git" "latest" 1

INFO_NoNewLineAbove "Cloning 'libxshmfence'"
CLONE "https://gitlab.freedesktop.org/xorg/lib/libxshmfence.git" "latest" 1
INFO_NoNewLineAbove "Cloning 'libepoxy'"
CLONE "https://github.com/anholt/libepoxy.git" "latest" 1
INFO_NoNewLineAbove "Cloning 'wayland'"
CLONE "https://gitlab.freedesktop.org/wayland/wayland.git" "latest" 1
INFO_NoNewLineAbove "Cloning 'wayland-protocols'"
CLONE "https://gitlab.freedesktop.org/wayland/wayland-protocols.git" "latest" 1
INFO_NoNewLineAbove "Cloning 'libsha1'"
CLONE "https://github.com/dottedmag/libsha1.git" "latest" 1
INFO_NoNewLineAbove "Cloning 'xorg-server_v21.1.7'"
CLONE "https://gitlab.freedesktop.org/xorg/xserver.git" "xorg-server-21.1.7" 1
# xorg-server-1.20.14

INFO_NewLineAbove "DONE!"
clear -x

# set -e # Late enable

#compile libxshmfence
clear -x
TITLE "Compiling libxshmfence... (1/8)"
echo ""

cd $TMP_FOLDER/libxshmfence

RM_SILENT $PREFIX/lib/libxshmfence*

./autogen.sh --prefix=$PREFIX --with-shared-memory-dir=$TMPDIR;
sed -i s/values.h/limits.h/ ./src/xshmfence_futex.h;

make -j${CORES} install CPPFLAGS=-DMAXINT=INT_MAX;

#compile mesa
clear -x
TITLE "Compiling & Patching mesa... (2/8)"
WARN "Prepare for LAG!"
echo ""

cd $TMP_FOLDER/mesa
[ ! -f "$MESA_PATCH_FILE" ] && {
	DIE "Mesa patch file not found! Try re-running the script..."
}
git checkout -f main
git apply --reject "$MESA_PATCH_FILE"

MKDIR_NO_ERR b
CD_NO_ERR b

if [ "$ENABLE_DRI3" = "yes" ]; then
	LDFLAGS='-l:libandroid-shmem.a -llog' meson .. -Dprefix=$PREFIX -Dplatforms=x11 -Ddri3=true -Dgbm=enabled -Dgallium-drivers=zink,swrast -Dllvm=enabled -Dvulkan-drivers='' -Dcpp_rtti=false -Dc_args=-Wno-error=incompatible-function-pointer-types -Dbuildtype=release
else
	LDFLAGS='-l:libandroid-shmem.a -llog' meson .. -Dprefix=$PREFIX -Dplatforms=x11 -Dgbm=enabled -Dgallium-drivers=zink,swrast -Dllvm=enabled -Dvulkan-drivers='' -Dcpp_rtti=false -Dc_args=-Wno-error=incompatible-function-pointer-types -Dbuildtype=release
fi

# RM_SILENT $PREFIX/lib/libglapi*
# RM_SILENT $PREFIX/lib/libGL*
# RM_SILENT $PREFIX/lib/libEGL*
# RM_SILENT $PREFIX/lib/libgbm*
# RM_SILENT $PREFIX/lib/dri

ninja install

CD_NO_ERR ../bin
python3 install_megadrivers.py \
	$TMP_FOLDER/mesa/b/src/gallium/targets/dri/libgallium_dri.so \
	/data/data/com.termux/files/usr/lib/dri \
	swrast_dri.so kms_swrast_dri.so zink_dri.so

#compile libepoxy
clear -x
TITLE "Compiling libepoxy... (3/8)"
echo ""

cd $TMP_FOLDER/libepoxy

MKDIR_NO_ERR b
CD_NO_ERR b

meson -Dprefix=$PREFIX -Dbuildtype=release -Dglx=yes -Degl=yes -Dtests=false -Dc_args="-U__ANDROID__" ..

RM_SILENT $PREFIX/lib/libepoxy*

ninja install

#compile virglrenderer
clear -x
TITLE "Compiling & Patching virglrenderer... (4/8)"
echo ""

cd $TMP_FOLDER/virglrenderer

git checkout -f master
[ ! -f "$VIRGL_DIFF_FILE" ] && {
	DIE "VirGL diff file not found! Try re-running the script..."
}
git apply "$VIRGL_DIFF_FILE"

MKDIR_NO_ERR b
CD_NO_ERR b

meson -Dbuildtype=release -Dprefix=$PREFIX -Dplatforms=egl ..

RM_SILENT $PREFIX/lib/libvirglrenderer*

ninja install

# RM_SILENT $PREFIX/lib/libwayland*

ninja install

#compile wayland-protocols
clear -x
TITLE "Compiling wayland-protocols... (6/8)"
echo ""

RM_SILENT $PREFIX/lib/pkgconfig/wayland-protocols.pc

cd $TMP_FOLDER/wayland-protocols

MKDIR_NO_ERR b
CD_NO_ERR b

meson -Dprefix=$PREFIX -Dtests=false -Dbuildtype=release ..
ninja install

#compile libsha1
clear -x
TITLE "Compiling libsha1... (7/8)"
echo ""

cd $TMP_FOLDER/libsha1

./autogen.sh --prefix=$PREFIX

RM_SILENT $PREFIX/lib/libsha1*

make -s -j${CORES} install

#compile Xwayland
clear -x
TITLE "Compiling & Patching xserver... (8/8)"
echo ""

cd $TMP_FOLDER/xserver
[ ! -f "$XSERVER_PATCH_FILE" ] && {
	DIE "xserver patch file not found! Try re-running the script..."
}

# git checkout -f "xorg-server-1.20.14"
git checkout -f "xorg-server-21.1.7"
git apply --reject "$XSERVER_PATCH_FILE"

# FOR NEWER VERSIONS! (Still implementing fixes)
# MKDIR_NO_ERR include/sys/
# touch include/sys/kd.h
# sed -i 's/set[gu]id\(\)/\(int\)/g' os/utils.c
# MKDIR_NO_ERR b
# CD_NO_ERR b
# LDFLAGS='-l:libandroid-shmem.a -llog' meson .. -Dprefix=$PREFIX -Dvendor_name="Mediatek" -Dvendor_name_short="MTK" -Ddri3=true -Dmitshm=true -Dxcsecurity=true -Dxf86bigfont=true -Dxwayland=true -Dxorg=true -Dxnest=true -Dxvfb=true -Dxwin=false -Dxephyr=true -Ddevel-docs=false -Dhal=false -Dudev=false -Ddtrace=false -Dglamor=false -Dglx=true -Dsha1=libsha1 -Dc_args="-DKDSETMODE=0 -DKDSKBMODE=0 -DKD_TEXT=0 -DK_OFF=0 -DKD_GRAPHICS=0 -DKDGKBMODE=0 -DK_RAW=0 -Dnolock=i"
# RM_SILENT $PREFIX/lib/libX*
# ninja install

if [[ "$USE_XF86BF" = "enable" || "$USE_XF86BF" = "fix" ]]; then
	if [ "$ENABLE_DRI3" = "yes" ]; then
		./autogen.sh --enable-dri3 --enable-mitshm --enable-xcsecurity --enable-xf86bigfont --enable-xwayland --enable-xorg --enable-xnest --enable-xvfb --disable-xwin --enable-xephyr --enable-kdrive --disable-devel-docs --disable-config-hal --disable-config-udev --disable-unit-tests --disable-selective-werror --disable-static --without-dtrace --disable-glamor --enable-glx --with-sha1=libsha1 --with-pic --prefix=$PREFIX
	else
		./autogen.sh --enable-mitshm --enable-xcsecurity --enable-xf86bigfont --enable-xwayland --enable-xorg --enable-xnest --enable-xvfb --disable-xwin --enable-xephyr --enable-kdrive --disable-devel-docs --disable-config-hal --disable-config-udev --disable-unit-tests --disable-selective-werror --disable-static --without-dtrace --disable-glamor --enable-glx --with-sha1=libsha1 --with-pic --prefix=$PREFIX
	fi
else
	if [ "$ENABLE_DRI3" = "yes" ]; then
		./autogen.sh --enable-dri3 --enable-mitshm --enable-xcsecurity --disable-xf86bigfont --enable-xwayland --enable-xorg --enable-xnest --enable-xvfb --disable-xwin --enable-xephyr --enable-kdrive --disable-devel-docs --disable-config-hal --disable-config-udev --disable-unit-tests --disable-selective-werror --disable-static --without-dtrace --disable-glamor --enable-glx --with-sha1=libsha1 --with-pic --prefix=$PREFIX
	else
		./autogen.sh --enable-mitshm --enable-xcsecurity --disable-xf86bigfont --enable-xwayland --enable-xorg --enable-xnest --enable-xvfb --disable-xwin --enable-xephyr --enable-kdrive --disable-devel-docs --disable-config-hal --disable-config-udev --disable-unit-tests --disable-selective-werror --disable-static --without-dtrace --disable-glamor --enable-glx --with-sha1=libsha1 --with-pic --prefix=$PREFIX
	fi
fi

# RM_SILENT $PREFIX/lib/libX*

if [ "$USE_XF86BF" = "fix" ]; then
	make -s -j${CORES} install LDFLAGS='-fuse-ld=lld /data/data/com.termux/files/usr/lib/libandroid-shmem.a -llog' CFLAGS="-DKDSETMODE=0 -DKDSKBMODE=0 -DKD_TEXT=0 -DK_OFF=0 -DKD_GRAPHICS=0 -DKDGKBMODE=0 -DK_RAW=0"
else
	make -s -j${CORES} install LDFLAGS='-fuse-ld=lld /data/data/com.termux/files/usr/lib/libandroid-shmem.a -llog' CFLAGS="-DKDSETMODE=0 -DKDSKBMODE=0 -DKD_TEXT=0 -DK_OFF=0 -DKD_GRAPHICS=0 -DKDGKBMODE=0 -DK_RAW=0" CPPFLAGS=-DSHMLBA=4096 # CHANGE THIS IF CRASHING OR SMTH
fi

clear -x

TITLE "DONE!"
INFO_NewLineAbove "Build success!"

INFO_NewLineAbove "Termux-X11 is recommended when using this!"
WARN "Please, please, please dont upgrade all of the packages that has been compiled"
WARN "Or you will encounter weird issues."
WARN "A recompile should fix the issue (not so sure)"

INFO_NewLineAbove "Script signing off..."

WARN $ERR_LOGS

exit 0
