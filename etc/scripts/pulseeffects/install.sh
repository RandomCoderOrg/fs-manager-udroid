#!/usr/bin/env bash

# * Usefull functions
# die()     exit with code 1 with printing given string
# warn()    like die() without exit status (used when exit is not necessary)
# shout()   pring messege in a good way with some lines
# lshout()  print messege in a standard way

die    () { echo -e "${RED}Error ${*}${RST}";exit 1 ;:;}
warn   () { echo -e "${RED}Error ${*}${RST}";:;}
shout  () { echo -e "${DC}-----";echo -e "${*}";echo -e "-----${RST}";:; }
lshout () { echo -e "${DC}";echo -e "${*}";echo -e "${RST}";:; }

shout "trying to update indexes........."
apt update; apt upgrade -y || {
    warn "failed to update indexes..."
}


shout "trying to install pulse-effects...."

apt install pulseeffects || {
    die "failed to install pulseeffects........"
}
lshout "Done..."

shout "setting up workaround....."

timeout 9 dconf reset -f /com/github/wwmm/pulseeffects/ || warn "timeout.." && lshout "Done!.."
