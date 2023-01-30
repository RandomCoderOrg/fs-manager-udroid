# Audio Output

Audio output is handled by pulseaudio from container to termux pulseaudio openSL ES sink througth tcp.

termux pulse audio initalization is done in scripts with `PULSE_SERVER` environment variable set to `127.0.0.1` and with `module-native-protocol-tcp` module loaded in termux pulseaudio.

#### example

```bash
# in termux
pulseaudio  --start \
    --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" \
    --exit-idle-time=-1
# in proot container
export PULSE_SERVER=127.0.0.1

```


## limitations

> sending audio packets througth tcp with vnc will cause audio lag.
>
> _for now there is no solution for this._
