#!/usr/bin/env bash
# hi-shell setup: opens the installer window, where you pick what to install and press Install.
#
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/imu-useful/hi-shell/main/setup.sh)"
#   ./setup.sh                  from a clone of the repo
#
# The window needs python-gobject, gtk4 and libadwaita; when one is missing it's installed first with
# pacman (that asks for your sudo password here, in the terminal). Without a graphical session
# (a TTY, ssh) the text installer, install.sh, runs instead.
#
# Options:
#   --text      the text installer even in a graphical session
#   anything else is passed to install.sh with --text (see install.sh --help)
set -euo pipefail

RAW_URL="${HI_SHELL_RAW_URL:-https://raw.githubusercontent.com/imu-useful/hi-shell/main}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hi-shell/setup"
GUI_PKGS=(python python-gobject gtk4 libadwaita git)

bold=$'\e[1m' green=$'\e[32m' red=$'\e[31m' reset=$'\e[0m'
step() { echo "${bold}${green}::${reset}${bold} $*${reset}"; }
die() { echo "${red}error:${reset} $*" >&2; exit 1; }

TEXT=false
INSTALL_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --text) TEXT=true ;;
        -h | --help) sed -n '2,/^set -euo/p' "$0" | sed -e '$d' -e 's/^# \{0,1\}//'; exit 0 ;;
        *) INSTALL_ARGS+=("$arg") ;;
    esac
done
((${#INSTALL_ARGS[@]})) && TEXT=true

[[ $EUID -eq 0 ]] && die "run as your user, not root (sudo is used where needed)"

# The files: this clone's, or a fresh copy of install.sh and the window from GitHub.
self="${BASH_SOURCE[0]:-$0}"
here="$(cd -P "$(dirname "$(readlink -f "$self" 2>/dev/null || echo "$self")")" 2>/dev/null && pwd -P || true)"
if [[ -n "$here" && -f "$here/install.sh" && -f "$here/installer/gui.py" ]]; then
    SRC="$here"
else
    SRC="$CACHE_DIR"
    step "Downloading the installer"
    mkdir -p "$SRC/installer"
    for f in install.sh installer/gui.py installer/logic.py; do
        curl -fsSL "$RAW_URL/$f" -o "$SRC/$f.part" || die "couldn't download $RAW_URL/$f"
        mv "$SRC/$f.part" "$SRC/$f"
    done
    chmod +x "$SRC/install.sh"
fi

graphical() { [[ -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}" ]]; }
gui_ready() {
    python3 -c 'import gi; gi.require_version("Gtk", "4.0"); gi.require_version("Adw", "1"); from gi.repository import Adw' 2>/dev/null
}

if $TEXT || ! graphical; then
    graphical || echo "No graphical session: the text installer runs instead."
    exec bash "$SRC/install.sh" "${INSTALL_ARGS[@]}"
fi

if ! gui_ready || ! command -v git >/dev/null; then
    command -v pacman >/dev/null || {
        echo "The installer window needs PyGObject, GTK 4 and libadwaita; without pacman, the text installer runs."
        exec bash "$SRC/install.sh"
    }
    missing=()
    for p in "${GUI_PKGS[@]}"; do pacman -Qq "$p" &>/dev/null || missing+=("$p"); done
    step "The installer window needs: ${missing[*]}"
    sudo pacman -S --needed "${missing[@]}" || die "couldn't install them; the text installer: bash $SRC/install.sh"
    gui_ready || die "the window still can't start; the text installer: bash $SRC/install.sh"
fi

step "Opening the installer"
exec python3 "$SRC/installer/gui.py" --script "$SRC/install.sh"
