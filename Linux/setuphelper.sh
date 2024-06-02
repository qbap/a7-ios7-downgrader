#!/usr/bin/env bash

os=$(uname)
dir="$(pwd)/$(uname)"

BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
LIME_YELLOW=$(tput setaf 190)
POWDER_BLUE=$(tput setaf 153)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BRIGHT=$(tput bold)
NORMAL=$(tput sgr0)
BLINK=$(tput blink)
REVERSE=$(tput smso)
UNDERLINE=$(tput smul)

attn() {
    for i in $(seq "$1" -1 1); do
        printf "\r%s (%d) " "$2" "$i"
        sleep 0.5
        printf '\r\e[0m%s (%d) ' "$3" "$i"
        sleep 0.5
    done
    printf '\r\e[0m%s (0)\n' "$3"
}

do_something() {
    "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost 'rm -rf /mnt4/Applications/Setup.app'
}

function yes_or_no {
    while true; do
        read -p "$* [y/n]: " yn
        case $yn in
            [Yy]*) return 0  ;;  
            [Nn]*) echo "Aborted" ; return  1 ;;
        esac
    done
}
attn 2 "${RED}[*] Alert" "[*] Alert"
attn 2 "${RED}[*] If you boot now, you will get stuck at the \"screen time\" step in Setup.app" "[*] If you boot now, you will get stuck at the \"screen time\" step in Setup.app"
attn 2 "${RED}[*] You must delete Setup.app if you want to be able to use iOS $1" "[*] You must delete Setup.app if you want to be able to use iOS $1"
attn 2 "${RED}[*] See https://files.catbox.moe/96vhbl.mov for a video demonstration of the issue" "[*] See https://files.catbox.moe/96vhbl.mov for a video demonstration of the issue"
echo "${BLINK}[*] You will only see this message if activation_records are present for your device${NORMAL}"
yes_or_no "Would you like to delete Setup.app?" && do_something
