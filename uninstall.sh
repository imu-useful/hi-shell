#!/usr/bin/env bash
# Remove hi-shell: stop it, take it out of the Hyprland config and unlink it.
#
#   ./uninstall.sh            keeps your settings, presets and the repo
#   ./uninstall.sh --purge    also deletes settings, state and cache (asks first)
#
# Packages stay installed (other programs may use them); remove them with pacman if you like.
set -euo pipefail

QS_LINK="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/hi-shell"
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/hi-shell"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/hi-shell"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/hi-shell"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/hi-shell"

PURGE=false
for arg in "$@"; do
    case "$arg" in
        --purge) PURGE=true ;;
        -h | --help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg (see --help)" >&2; exit 1 ;;
    esac
done

bold=$'\e[1m' green=$'\e[32m' yellow=$'\e[33m' reset=$'\e[0m'
step() { echo "${bold}${green}::${reset}${bold} $*${reset}"; }

step "Stopping hi-shell"
qs -c hi-shell kill &>/dev/null && echo "Stopped." || echo "Not running."

step "Hyprland config"
removed=false
while IFS= read -r file; do
    # Remove the dofile line and the marker comment install.sh put above it.
    cp "$file" "$file.backup-hi-shell-uninstall"
    sed -i -e '/^-- hi-shell (added by install.sh)$/d' -e '/quickshell\/hi-shell\/hypr\/hi-shell\.lua/d' "$file"
    echo "Removed from $file (backup: $file.backup-hi-shell-uninstall)"
    removed=true
done < <(grep -rlF "quickshell/hi-shell/hypr/hi-shell.lua" "$HYPR_DIR" --include='*.lua' 2>/dev/null | grep -v '\.backup' || true)
$removed || echo "hi-shell wasn't loaded from $HYPR_DIR."
[[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && hyprctl reload >/dev/null 2>&1 || true

step "Quickshell link"
repo=""
if [[ -L "$QS_LINK" ]]; then
    repo="$(readlink -f "$QS_LINK")"
    rm "$QS_LINK"
    echo "Removed $QS_LINK"
elif [[ -e "$QS_LINK" ]]; then
    echo "${yellow}$QS_LINK is not a link; left in place.${reset}"
else
    echo "No link at $QS_LINK."
fi

if $PURGE; then
    step "Settings, state and cache"
    echo "This deletes:"
    for d in "$CONFIG" "$STATE" "$CACHE" "$DATA"; do [[ -e "$d" ]] && echo "  $d"; done
    echo "(config, notifications, chats, to-do, presets, wallpaper thumbnails)"
    read -r -p "Delete them? [y/N] " reply </dev/tty || reply=""
    if [[ "$reply" =~ ^[Yy] ]]; then
        rm -rf -- "$CONFIG" "$STATE" "$CACHE" "$DATA"
        echo "Deleted."
    else
        echo "Kept."
    fi
else
    echo
    echo "Your settings are kept in $CONFIG (use --purge to delete them)."
fi

[[ -n "$repo" ]] && echo "The repo is still at $repo; delete it if you don't need it."
echo "hi-shell is uninstalled."
