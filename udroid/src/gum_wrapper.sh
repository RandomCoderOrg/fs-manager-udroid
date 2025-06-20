#!/bin/bash

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

# arch transition
case $(dpkg --print-architecture) in
    arm64 | aarch64) ARCH=aarch64 ;;
    arm | armhf | armv7l | armv8l) ARCH=armhf ;;
    x86_64| amd64) ARCH=amd64;;
    *) die "unsupported architecture" ;;
esac

# GUM="./gum/usr/bin/gum"
GUM="./gum/gum-$ARCH/usr/bin/gum"

export GUM_INPUT_CURSOR_FOREGROUND="#F2BE22"
export GUM_CHOOSE_CURSOR_FOREGROUND="#F2BE22"
export GUM_CONFIRM_PROMPT_FOREGROUND="#F2BE22"

[[ ! -f $GUM ]] && die "gum not found.."

trim_quotes() {
    # Usage: trim_quotes "string"
    : "${1//\'}"
    printf '%s\n' "${_//\"}"
}

function g_input() {
    placeholder=""

    [[ -n "$1" ]] && {
        placeholder="$1"
    }

    $GUM input --placeholder "$placeholder"
}

function g_choose() {
    options=$*
    
    [[ -n $options ]] && {
        $GUM choose $options
    }
}

function g_confirm() {
    msg=$*

    return $($GUM confirm "$msg")
}

# g_spin "spinner_type" "Title for the spinner" "command_to_run"
# Example: g_spin "moon" "Processing..." "sleep 5"
function g_spin() {
    local spinner_type="$1"
    local title="$2"
    local cmd="${*:3}" # All arguments from the 3rd one

    if [ -z "$spinner_type" ] || [ -z "$title" ] || [ -z "$cmd" ]; then
        warn "g_spin: Spinner type, title, and command must be provided."
        return 1
    fi

    $GUM spin -s "$spinner_type" --title "$title" -- $cmd
    # Assuming the command outputs its own success/failure,
    # or we rely on set -e.
    # The original check mark echo might be misleading if $cmd fails.
    # For now, keeping it simple and not adding complex error handling here.
    # If cmd fails, gum spin will show the error.
    # If a visual confirmation of success for g_spin itself is needed,
    # we can add it back, perhaps conditionally.
    # echo -e "[\xE2\x9C\x94] $title" # Re-evaluate if this is needed
}

# g_format "string to format" -t template
# g_format "/path/to/file" -t markdown
function g_format () {
    local source_content="$1"
    shift

    if [ -z "$source_content" ]; then
        die "g_format: Source content (string or file path) not specified."
    fi

    if [ -f "$source_content" ]; then
        $GUM format "$@" < "$source_content"
    else
        echo "$source_content" | $GUM format "$@"
    fi
}

# g_table "Header1,Header2" "Row1Col1,Row1Col2\nRow2Col1,Row2Col2"
function g_table() {
    local headers="$1"
    local data="$2"

    if [ -z "$headers" ] || [ -z "$data" ]; then
        warn "g_table: Headers and data must be provided."
        return 1
    fi

    # Prepend headers to data
    local csv_data="$headers\n$data"

    echo -e "$csv_data" | $GUM table
}

# g_style "Text to style" --foreground "#FFF" --border double
function g_style() {
    local text_to_style="$1"
    shift

    if [ -z "$text_to_style" ]; then
        warn "g_style: Text to style must be provided."
        return 1
    fi

    echo "$text_to_style" | $GUM style "$@"
}

# g_log "info" "User logged in" user_id 123
function g_log() {
    local level="$1"
    shift

    if [ -z "$level" ]; then
        warn "g_log: Log level must be provided."
        return 1
    fi

    $GUM log --structured --level "$level" "$@" --time-format "2006-01-02T15:04:05Z07:00"
}

# selected_file=$(g_file "/path/to/dir")
# selected_file=$(g_file)
function g_file() {
    local start_path="$1"

    if [ -n "$start_path" ]; then
        $GUM file "$start_path"
    else
        $GUM file
    fi
}

