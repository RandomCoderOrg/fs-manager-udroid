#!/usr/bin/env bash

DIE() { echo -e "${@}"; exit 1 ;:;}
GWARN() { echo -e "\e[90m${*}\e[0m";:;}

# Check for termux playstore version:
if [[ "$TERMUX_VERSION" == "googleplay"* ]]; then
  GWARN "Termux Play Store version detected."
  DIE "The Play Store version is unsupported.\nPlease reinstall Termux from F-Droid: https://f-droid.org/packages/com.termux/"
fi

apt install -y jq wget proot pv pulseaudio libandroid-shmem-static which
[[ ! -d udroid/src ]] && {
    echo "udroid/src not found"
    exit 1
}

# Android version warinigs
android_version_code=$(getprop ro.system.build.version.release)
if (( $android_version_code >= 12 )); then
    sleep 1
    echo
    GWARN "[Warning]: Android version ${android_version_code} detected"
    GWARN "You may experience issues like crashing"
    GWARN "watch this to fix signal 9 issue: "
    GWARN "      https://youtu.be/GCN0gh1yXSs?si=qvqUWisk0gLHqXqs"
    GWARN ""
    echo
    sleep 2
fi

cd udroid/src || exit 1
# Remove old udroid
rm -rf $(which udroid)
bash install.sh
