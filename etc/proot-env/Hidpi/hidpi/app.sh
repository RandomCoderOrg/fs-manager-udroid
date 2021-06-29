#!/usr/bin/env bash

SETTINGS_DIR=~/.config/hippo-HiDPI/
DESKTOP="$XDG_CURRENT_DESKTOP"

case "$DESKTOP" in
        XFCE)
                ;;
        *)
                echo 'ERROR: HiDPI mode only works on Xfce desktop' >&2
                notify-send -i dialog-warning 'ERROR: HiDPI mode only works on Xfce desktop'
                exit 1
                ;;
esac

mkdir -p "$SETTINGS_DIR"
grep -q "$SETTINGS_DIR" ~/.xsessionrc 2>/dev/null || \
        echo "[ -r ${SETTINGS_DIR}xsession-settings ] && . ${SETTINGS_DIR}xsession-settings" >> ~/.xsessionrc

enable_hidpi() {
    cat > "${SETTINGS_DIR}xsession-settings" <<-EOF
        export QT_SCALE_FACTOR=2
        export XCURSOR_SIZE=48
        export GDK_SCALE=2
EOF

    . "${SETTINGS_DIR}xsession-settings"

    case "$DESKTOP" in
        XFCE)
            xfconf-query -c xfwm4 -p /general/theme -s WhiteSur-light-hdpi
            xfconf-query -c xsettings -p /Gdk/WindowScalingFactor -n -t 'int' -s 2
        ;;
    esac
}

disable_hidpi()
{
    export QT_SCALE_FACTOR=1
    export XCURSOR_SIZE=
    export GDK_SCALE=1

    rm "${SETTINGS_DIR}xsession-settings"

    case "$DESKTOP" in
        XFCE)
            xfconf-query -c xfwm4 -p /general/theme -s WhiteSur-light
            xfconf-query -c xsettings -p /Gdk/WindowScalingFactor -s 1
        ;;
    esac
}

toggle_hidpi() {
        if [ -r "${SETTINGS_DIR}xsession-settings" ]
        then
                disable_hidpi
                { sleep 5 && notify-send -i dialog-information 'HiDPI mode disabled'; } &
        else
                enable_hidpi
                { sleep 5 && notify-send -i dialog-information 'HiDPI mode enabled'; } &
        fi

        if [ "$DESKTOP" = 'XFCE' ]
        then
                killall xfce4-notifyd 2> /dev/null # Hide existing notifications
                for process in xfsettingsd xfce4-panel xfdesktop
                do
                        killall -9 $process
                        $process >/dev/null 2>&1 &
                done
        fi
}

toggle_hidpi
zenity --question --title='hippo HiDPI mode(experimental)' --text 'Do you want to keep this window-scaling mode?\n(prefer no if things look bad)' --timeout=15 --width=200 || \
        toggle_hidpi
