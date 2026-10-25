#!/usr/bin/env bash
# hi-shell installer for Arch Linux + Hyprland 0.56+ (Lua config).
#
#   ./install.sh                 from a clone of the repo
#   bash <(curl -fsSL https://raw.githubusercontent.com/imu-useful/hi-shell/main/install.sh)
#
# Options:
#   --no-deps   don't install packages
#   --yes       don't ask (install packages, edit the Hyprland config)
#   --no-start  don't start the shell at the end
#
# What it does: installs the packages hi-shell uses, links the repo to
# ~/.config/quickshell/hi-shell, loads hypr/hi-shell.lua from your Hyprland config
# (one line, marked "hi-shell" so uninstall.sh can remove it) and starts the shell.
set -euo pipefail

REPO_URL="https://github.com/imu-useful/hi-shell.git"
CLONE_DIR="${HI_SHELL_DIR:-$HOME/.local/share/hi-shell/repo}"
QS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
MARKER="-- hi-shell (added by install.sh)"

DEPS=true YES=false START=true
NOCONFIRM=()
for arg in "$@"; do
    case "$arg" in
        --no-deps) DEPS=false ;;
        --yes | -y) YES=true; NOCONFIRM=(--noconfirm) ;;
        --no-start) START=false ;;
        -h | --help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg (see --help)" >&2; exit 1 ;;
    esac
done

bold=$'\e[1m' green=$'\e[32m' yellow=$'\e[33m' red=$'\e[31m' reset=$'\e[0m'
step() { echo "${bold}${green}::${reset}${bold} $*${reset}"; }
warn() { echo "${yellow}warning:${reset} $*" >&2; }
die() { echo "${red}error:${reset} $*" >&2; exit 1; }
ask() { # ask "Question?" -> 0 for yes
    $YES && return 0
    local reply
    read -r -p "$1 [Y/n] " reply </dev/tty || return 1
    [[ -z "$reply" || "$reply" =~ ^[Yy] ]]
}

[[ $EUID -eq 0 ]] && die "run as your user, not root (sudo is used where needed)"
command -v pacman >/dev/null || die "hi-shell targets Arch Linux (pacman not found)"

# --- Packages ---
PACMAN_PKGS=(
    matugen python pipewire wireplumber networkmanager bluez upower brightnessctl ddcutil
    libnotify hyprsunset hyprlock cliphist translate-shell grim slurp wl-clipboard hyprpicker
    cava imagemagick curl libqalculate tesseract tesseract-data-eng tesseract-data-rus wf-recorder pacman-contrib git
)
AUR_PKGS=(quickshell-git ttf-material-symbols-variable-git)

if $DEPS; then
    step "Packages"
    missing=()
    for p in "${PACMAN_PKGS[@]}"; do pacman -Qq "$p" &>/dev/null || missing+=("$p"); done
    if ((${#missing[@]})); then
        echo "Missing: ${missing[*]}"
        if ask "Install them with pacman?"; then
            sudo pacman -S --needed "${NOCONFIRM[@]}" "${missing[@]}"
        fi
    else
        echo "All repo packages are installed."
    fi

    aur_missing=()
    for p in "${AUR_PKGS[@]}"; do
        # Any quickshell build will do.
        [[ "$p" == quickshell-git ]] && command -v qs >/dev/null && continue
        pacman -Qq "$p" &>/dev/null || aur_missing+=("$p")
    done
    if ((${#aur_missing[@]})); then
        helper=$(command -v paru || command -v yay || true)
        if [[ -n "$helper" ]]; then
            echo "Missing from the AUR: ${aur_missing[*]}"
            if ask "Install them with $(basename "$helper")?"; then
                "$helper" -S --needed "${NOCONFIRM[@]}" "${aur_missing[@]}"
            fi
        else
            warn "install ${aur_missing[*]} from the AUR (no paru or yay found)"
        fi
    fi
fi

command -v qs >/dev/null || die "quickshell (qs) is not installed; install quickshell-git from the AUR"

# --- Source ---
step "Source"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/shell.qml" && -d "$SCRIPT_DIR/.git" ]]; then
    REPO="$SCRIPT_DIR"
    echo "Using this checkout: $REPO"
elif [[ -d "$CLONE_DIR/.git" ]]; then
    REPO="$CLONE_DIR"
    echo "Using the existing clone: $REPO (update it with update.sh)"
else
    REPO="$CLONE_DIR"
    mkdir -p "$(dirname "$REPO")"
    git clone --depth 1 "$REPO_URL" "$REPO"
fi

# --- Link into Quickshell's config folder ---
step "Link"
mkdir -p "$QS_DIR"
target="$QS_DIR/hi-shell"
if [[ -L "$target" ]]; then
    ln -sfn "$REPO" "$target"
elif [[ -e "$target" ]]; then
    backup="$target.backup-$(date +%Y%m%d-%H%M%S)"
    mv "$target" "$backup"
    warn "moved the existing $target to $backup"
    ln -s "$REPO" "$target"
else
    ln -s "$REPO" "$target"
fi
echo "$target -> $REPO"

# --- Hyprland integration ---
step "Hyprland"
line="dofile(os.getenv(\"HOME\") .. \"/.config/quickshell/hi-shell/hypr/hi-shell.lua\")"
if [[ -f "$HYPR_DIR/custom/execs.lua" ]]; then
    hypr_file="$HYPR_DIR/custom/execs.lua"   # illogical-impulse / end-4 dots
elif [[ -f "$HYPR_DIR/hyprland.lua" ]]; then
    hypr_file="$HYPR_DIR/hyprland.lua"
else
    hypr_file=""
fi

if [[ -z "$hypr_file" ]]; then
    warn "no Lua Hyprland config found ($HYPR_DIR/hyprland.lua). hi-shell needs Hyprland 0.56+ with the Lua config;"
    warn "add this line to it yourself: $line"
elif grep -qF "hi-shell/hypr/hi-shell.lua" "$hypr_file"; then
    echo "Already loaded from $hypr_file"
elif ask "Load hi-shell from $hypr_file?"; then
    cp "$hypr_file" "$hypr_file.backup-hi-shell"
    # Start on a new line; uninstall.sh removes exactly these two lines.
    [[ -s "$hypr_file" && -n "$(tail -c1 "$hypr_file")" ]] && echo >>"$hypr_file"
    printf '%s\n%s\n' "$MARKER" "$line" >>"$hypr_file"
    echo "Added to $hypr_file (backup: $hypr_file.backup-hi-shell)"
fi

# Another bar or notification daemon would run next to hi-shell.
for other in "qs -c ii" "caelestia" "waybar" "noctalia" "swaync" "mako" "dunst"; do
    if pgrep -f "$other" >/dev/null; then
        warn "\"$other\" is running; stop it (and remove it from your Hyprland autostart) to use hi-shell alone"
    fi
done

command -v claude >/dev/null || warn "Claude Code isn't installed: the AI palette and chat need it (npm install -g @anthropic-ai/claude-code, then run claude once)"

# --- Start ---
if $START && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    step "Start"
    hyprctl reload >/dev/null || true
    qs -c hi-shell kill &>/dev/null || true
    qs -c hi-shell -d &>/dev/null
    errors=$(hyprctl configerrors 2>/dev/null | grep -v '^$' || true)
    [[ -n "$errors" ]] && warn "hyprctl configerrors:"$'\n'"$errors"
    echo "hi-shell is running. Tap Super for the launcher, Super+Escape for settings."
else
    echo "Done. hi-shell starts with Hyprland (or run: qs -c hi-shell -d)."
fi
