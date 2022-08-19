#!/usr/bin/env bash

DEFAULT_XSTARTUP="${HOME}/.vnc/xstartup"
#DEFAULT_XSTARTUP_HIDPI=""

num='^[0-9]+$'
if [ -n "$DEFAULT_VNC_PORT" ]; then
    if [[ ${DEFAULT_VNC_PORT} =~ $num ]]; then
        port="${DEFAULT_VNC_PORT}"
        echo "VNC port set to ${port}"
    else
        echo "variable DEFAULT_VNC_PORT dosent contain a valid port number..."
        echo "getting back to default = 1..."
        port="1"
    fi
else
    port="1"
fi

if [ -f /tmp/.X11-unix/X${port} ]; then
    vnc=true
else
    vnc=false
fi

if [ -f /tmp/.X${port}-lock ]; then
    vnc=true
else
    vnc=false
fi

if ! $vnc; then
    vncserver -xstartup "${DEFAULT_XSTARTUP}" -localhost no -desktop "udroid Default VNC" :${port}
else
    echo "A vncserver lock is found for port ${port}"
    echo -e "Use \e[1;32mudroid stoptvnc\e[0m or \e[1;32mstopvnc\e[0m to stop it and try again..."
fi
