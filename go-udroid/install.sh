#!/usr/bin/env bash
# Build go-udroid from source and install it as `udroid-go` so it can live
# alongside the bash `udroid` binary. Termux-first; falls back to a generic
# Linux flow when run outside Termux.
#
# Usage:
#   ./install.sh [-y] [--prefix=DIR] [--bin-name=NAME] [--no-install]
#
#   -y, --yes         Non-interactive: assume yes for any prompt.
#   --prefix=DIR      Install into DIR/bin/ instead of the auto-detected
#                     location ($PREFIX/bin on Termux, /usr/local on Linux).
#   --bin-name=NAME   Output binary name (default: udroid-go).
#   --no-install      Build only; skip the install step.
#   --skip-deps       Skip the dependency check entirely (assume caller has
#                     `go`, `proot`, `tar` already on PATH).
#   -h, --help        Show this help.

set -euo pipefail

BIN_NAME=udroid-go
ASSUME_YES=0
DO_INSTALL=1
SKIP_DEPS=0
INSTALL_PREFIX=""

# usage prints the help block parsed from the top-of-file comment so help
# and the source stay in lockstep.
usage() {
    sed -n '/^# Build go-udroid/,/^$/{s/^# \{0,1\}//;p;}' "$0"
}

# parse_args walks $@ exactly once, populating the globals above. Unknown
# args are a hard error rather than a warning — silent typos in install
# scripts cause more grief than they save.
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -y|--yes) ASSUME_YES=1 ;;
            --no-install) DO_INSTALL=0 ;;
            --skip-deps) SKIP_DEPS=1 ;;
            --prefix=*) INSTALL_PREFIX="${1#--prefix=}" ;;
            --bin-name=*) BIN_NAME="${1#--bin-name=}" ;;
            -h|--help) usage; exit 0 ;;
            *) echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
        esac
        shift
    done
}

# detect_host fingerprints the environment so the install/build logic knows
# which package manager (if any) to suggest. Termux exposes $TERMUX_VERSION;
# regular distros are matched via /etc/os-release for `apt`/`pacman`.
detect_host() {
    if [ -n "${TERMUX_VERSION:-}" ] || [ -n "${PREFIX:-}" ] && [ -x "${PREFIX:-/nonexistent}/bin/pkg" ]; then
        HOST=termux
        DEFAULT_BIN_DIR="${PREFIX}/bin"
        return
    fi
    DEFAULT_BIN_DIR="/usr/local/bin"
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case "${ID:-}${ID_LIKE:-}" in
            *debian*|*ubuntu*) HOST=debian ;;
            *arch*)            HOST=arch ;;
            *)                 HOST=other ;;
        esac
        return
    fi
    HOST=other
}

# missing_deps lists which required tools aren't on PATH. `go` is needed to
# build; `proot` and `tar` are needed at runtime (proot is what the rootfs
# install/login flow shells out to). Prints nothing when all deps are
# present, so the caller can read the result with a portable while-loop.
missing_deps() {
    local missing=()
    command -v go    >/dev/null 2>&1 || missing+=(go)
    command -v proot >/dev/null 2>&1 || missing+=(proot)
    command -v tar   >/dev/null 2>&1 || missing+=(tar)
    [ ${#missing[@]} -eq 0 ] && return
    printf '%s\n' "${missing[@]}"
}

# install_deps tries the host's package manager. Maps the canonical names
# from missing_deps to per-distro package names. On `other` hosts we bail
# out with instructions rather than guessing.
install_deps() {
    local pkgs=("$@")
    [ ${#pkgs[@]} -eq 0 ] && return 0

    case "$HOST" in
        termux)
            run_pkg_install pkg "${pkgs[@]/#go/golang}" ;;
        debian)
            local mapped=()
            for p in "${pkgs[@]}"; do
                case "$p" in
                    go) mapped+=(golang-go) ;;
                    *)  mapped+=("$p") ;;
                esac
            done
            run_pkg_install "apt-get -y" "${mapped[@]}" ;;
        arch)
            run_pkg_install pacman "${pkgs[@]}" ;;
        *)
            echo "no package manager mapping for this host; please install: ${pkgs[*]}" >&2
            exit 1 ;;
    esac
}

# run_pkg_install confirms with the user (or honours --yes) and then runs
# the install with sudo when not root. The first positional is the install
# command up to but not including the package list.
run_pkg_install() {
    local cmd="$1"; shift
    local pkgs=("$@")
    echo "missing deps: ${pkgs[*]}"
    if [ "$ASSUME_YES" -eq 0 ]; then
        printf "install with '%s'? [y/N] " "$cmd"
        local ans
        read -r ans
        case "$ans" in y|Y|yes|YES) ;; *) echo "skipping dep install"; return 0 ;; esac
    fi
    local sudo=""
    [ "$HOST" != termux ] && [ "$(id -u)" -ne 0 ] && sudo="sudo"
    case "$cmd" in
        pkg)        $sudo pkg install -y "${pkgs[@]}" ;;
        "apt-get -y") $sudo apt-get update && $sudo apt-get install -y "${pkgs[@]}" ;;
        pacman)     $sudo pacman -S --noconfirm "${pkgs[@]}" ;;
    esac
}

# build_binary stamps in the version from `git describe` when available so
# `udroid-go info` shows a real tag rather than "dev". CGO is disabled for
# a fully static binary — important on Termux where libc paths shift.
build_binary() {
    local src_dir; src_dir="$(cd "$(dirname "$0")" && pwd)"
    cd "$src_dir"

    local version=dev
    if command -v git >/dev/null 2>&1 && git -C "$src_dir" rev-parse --git-dir >/dev/null 2>&1; then
        version="$(git -C "$src_dir" describe --tags --always --dirty 2>/dev/null || echo dev)"
    fi

    echo "building $BIN_NAME (version=$version)"
    CGO_ENABLED=0 go build \
        -ldflags="-s -w -X main.Version=${version}" \
        -o "$BIN_NAME" \
        ./cmd/udroid
    echo "built ./$BIN_NAME"
}

# install_binary copies the built artifact into the chosen bin dir. Uses
# sudo only if the dir isn't writable as the current user — keeps the
# Termux path prompt-free.
install_binary() {
    local bin_dir
    if [ -n "$INSTALL_PREFIX" ]; then
        bin_dir="${INSTALL_PREFIX}/bin"
    else
        bin_dir="$DEFAULT_BIN_DIR"
    fi
    mkdir -p "$bin_dir" 2>/dev/null || true

    local sudo=""
    if [ ! -w "$bin_dir" ]; then
        sudo="sudo"
    fi
    $sudo install -m 0755 "$BIN_NAME" "$bin_dir/$BIN_NAME"
    echo "installed $bin_dir/$BIN_NAME"
}

main() {
    parse_args "$@"
    detect_host

    if [ "$SKIP_DEPS" -eq 0 ]; then
        # Read missing deps with a while-loop instead of mapfile so the
        # script works on macOS's bash 3.2 (mapfile was added in bash 4).
        local missing=()
        while IFS= read -r line; do
            missing+=("$line")
        done < <(missing_deps)
        if [ ${#missing[@]} -gt 0 ]; then
            install_deps "${missing[@]}"
        fi
    fi

    build_binary
    if [ "$DO_INSTALL" -eq 1 ]; then
        install_binary
    else
        echo "skipping install (--no-install)"
    fi
}

main "$@"
