#!/usr/bin/env bash
# hi-shell installer for Arch Linux + Hyprland 0.56+ (Lua config).
#
#   ./install.sh                 from a clone of the repo
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/imu-useful/hi-shell/main/install.sh)"
#
# It first lets you choose what to install, then asks before each action:
#   y = yes, n = no, a = yes for all the rest (Enter = yes)
#
# Options:
#   --no-deps   don't install packages
#   --yes       don't ask: install everything that isn't switched off by another option
#   --no-start  don't start the shell at the end
#   --no-dots   don't offer hi-shell's terminal configs (fish, ...)
#   --with-apps also install the optional apps (Zen Browser, Telegram, Vesktop, osu!lazer,
#               Steam, Spotify, Neovim) with --yes; in the menu they're off by default
#
# What it does: installs the packages hi-shell uses, links the repo to
# ~/.config/quickshell/hi-shell, copies hypr/hi-shell/ into ~/.config/hypr and loads it from
# your Hyprland config (one line, marked "hi-shell" so uninstall.sh can remove it) and starts the shell.
set -euo pipefail

REPO_URL="https://github.com/imu-useful/hi-shell.git"
CLONE_DIR="${HI_SHELL_DIR:-$HOME/.local/share/hi-shell/repo}"
QS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
MARKER="-- hi-shell (added by install.sh)"

DEPS=true YES=false START=true DOTS=true APPS=false
NOCONFIRM=()
for arg in "$@"; do
    case "$arg" in
        --no-deps) DEPS=false ;;
        --yes | -y) YES=true; NOCONFIRM=(--noconfirm) ;;
        --no-start) START=false ;;
        --no-dots) DOTS=false ;;
        --with-apps) APPS=true ;;
        -h | --help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg (see --help)" >&2; exit 1 ;;
    esac
done

bold=$'\e[1m' green=$'\e[32m' yellow=$'\e[33m' red=$'\e[31m' reset=$'\e[0m'
step() { echo "${bold}${green}::${reset}${bold} $*${reset}"; }
warn() { echo "${yellow}warning:${reset} $*" >&2; }
die() { echo "${red}error:${reset} $*" >&2; exit 1; }
ask() { # ask "Should I do x?" -> 0 for yes; "a" answers yes to this and every later question
    $YES && return 0
    local reply
    while true; do
        read -r -p "$1 [Y/n/a = yes for all] " reply </dev/tty || return 1
        case "${reply,,}" in
            "" | y | yes) return 0 ;;
            n | no) return 1 ;;
            a | all | yesforall) YES=true; NOCONFIRM=(--noconfirm); return 0 ;;
            *) echo "Answer y, n or a." ;;
        esac
    done
}

# --- What to install ---
# One line per part; the hi-shell files themselves (source and link) are always installed.
APP_PARTS=(zen telegram vesktop osu steam spotify neovim)
PARTS=(deps hypr fish kitty fastfetch btop dolphin "${APP_PARTS[@]}" start)
declare -A PART_NAME=(
    [deps]="Packages hi-shell needs (pacman and AUR)"
    [hypr]="Load hi-shell from your Hyprland config"
    [fish]="Terminal config: fish (prompt, aliases)"
    [kitty]="Terminal config: kitty (colors follow the wallpaper)"
    [fastfetch]="Terminal config: fastfetch"
    [btop]="Terminal config: btop (colors follow the wallpaper)"
    [dolphin]="Dolphin: Google Sans Flex as the file list font"
    [start]="Start hi-shell when done"
    [zen]="App: Zen Browser"
    [telegram]="App: Telegram"
    [vesktop]="App: Vesktop (Discord)"
    [osu]="App: osu!lazer"
    [steam]="App: Steam"
    [spotify]="App: Spotify"
    [neovim]="App: Neovim"
)
# Optional apps: the package to install (the first name found in a repo or the AUR wins).
declare -A APP_PKG=(
    [zen]="zen-browser-bin" [telegram]="telegram-desktop" [vesktop]="vesktop vesktop-bin"
    [osu]="osu-lazer-bin" [steam]="steam" [spotify]="spotify" [neovim]="neovim"
)
declare -A WANT=([deps]=$DEPS [hypr]=true [fish]=$DOTS [kitty]=$DOTS [fastfetch]=$DOTS [btop]=$DOTS [dolphin]=$DOTS [start]=$START
    [zen]=$APPS [telegram]=$APPS [vesktop]=$APPS [osu]=$APPS [steam]=$APPS [spotify]=$APPS [neovim]=$APPS)
choose_parts() {
    $YES && return
    [[ -r /dev/tty ]] || return
    local reply i n
    while true; do
        step "What do you want to install?"
        for i in "${!PARTS[@]}"; do
            n=${PARTS[$i]}
            printf '  %d) [%s] %s\n' $((i + 1)) "$([[ ${WANT[$n]} == true ]] && echo x || echo ' ')" "${PART_NAME[$n]}"
        done
        read -r -p "Numbers to switch on / off (e.g. 3 4), a = all, n = none, Enter = continue: " reply </dev/tty || return
        case "${reply,,}" in
            "") break ;;
            a | all) for n in "${PARTS[@]}"; do WANT[$n]=true; done ;;
            n | none) for n in "${PARTS[@]}"; do WANT[$n]=false; done ;;
            *)
                for i in $reply; do
                    if [[ "$i" =~ ^[0-9]+$ ]] && ((i >= 1 && i <= ${#PARTS[@]})); then
                        n=${PARTS[$((i - 1))]}
                        [[ ${WANT[$n]} == true ]] && WANT[$n]=false || WANT[$n]=true
                    fi
                done
                ;;
        esac
    done
    DEPS=${WANT[deps]} START=${WANT[start]}
}

[[ $EUID -eq 0 ]] && die "run as your user, not root (sudo is used where needed)"
command -v pacman >/dev/null || die "hi-shell targets Arch Linux (pacman not found)"
choose_parts

# --- Packages ---
PACMAN_PKGS=(
    matugen python pipewire wireplumber networkmanager bluez upower brightnessctl ddcutil
    libnotify hyprsunset hyprlock cliphist translate-shell grim slurp wl-clipboard hyprpicker
    cava imagemagick curl libqalculate tesseract tesseract-data-eng tesseract-data-rus wf-recorder pacman-contrib git python-fonttools wtype
)
AUR_PKGS=(quickshell-git ttf-material-symbols-variable-git)

if $DEPS; then
    step "Packages"
    missing=()
    for p in "${PACMAN_PKGS[@]}"; do pacman -Qq "$p" &>/dev/null || missing+=("$p"); done
    if ((${#missing[@]})); then
        echo "Missing: ${missing[*]}"
        if ask "Should I install them with pacman?"; then
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
            if ask "Should I install them with $(basename "$helper")?"; then
                "$helper" -S --needed "${NOCONFIRM[@]}" "${aur_missing[@]}"
            fi
        else
            warn "install ${aur_missing[*]} from the AUR (no paru or yay found)"
        fi
    fi
fi

# --- Optional apps ---
# Only what you switched on in the menu (or --with-apps). A package that's in a configured
# repo goes through pacman, anything else through the AUR helper.
app_repo=() app_aur=()
for app in "${APP_PARTS[@]}"; do
    [[ ${WANT[$app]} == true ]] || continue
    found=""
    for p in ${APP_PKG[$app]}; do
        if pacman -Qq "$p" &>/dev/null; then found="installed"; break; fi
        if pacman -Si "$p" &>/dev/null; then app_repo+=("$p"); found="repo"; break; fi
    done
    if [[ -z "$found" ]]; then
        # Not in any repo: the first name, from the AUR.
        for p in ${APP_PKG[$app]}; do
            if pacman -Qq "$p" &>/dev/null; then found="installed"; break; fi
        done
        [[ -z "$found" ]] && app_aur+=("${APP_PKG[$app]%% *}")
        [[ -z "$found" && "$app" == steam ]] && warn "steam is in the multilib repo: enable [multilib] in /etc/pacman.conf first"
    fi
done
if ((${#app_repo[@]} + ${#app_aur[@]})); then
    step "Optional apps"
    if ((${#app_repo[@]})); then
        echo "From the repositories: ${app_repo[*]}"
        ask "Should I install them with pacman?" && sudo pacman -S --needed "${NOCONFIRM[@]}" "${app_repo[@]}"
    fi
    if ((${#app_aur[@]})); then
        helper=$(command -v paru || command -v yay || true)
        if [[ -n "$helper" ]]; then
            echo "From the AUR: ${app_aur[*]}"
            ask "Should I install them with $(basename "$helper")?" && "$helper" -S --needed "${NOCONFIRM[@]}" "${app_aur[@]}"
        else
            warn "install ${app_aur[*]} from the AUR (no paru or yay found)"
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
# hypr/hi-shell/ (startup, keybinds, window and layer rules, ...) is copied into your Hyprland
# folder, so it's right there to edit, and loaded from your config with one line.
step "Hyprland"
HYPR_LUA_DIR="$HYPR_DIR/hi-shell"
entry="$HYPR_LUA_DIR/init.lua"
line="dofile(os.getenv(\"HOME\") .. \"${entry#"$HOME"}\")"
# Where earlier versions loaded it from: the repo's folder, then a single ~/.config/hypr/hi-shell.lua.
old_paths=("quickshell/hi-shell/hypr/hi-shell.lua" ".config/hypr/hi-shell.lua")
if [[ -f "$HYPR_DIR/custom/execs.lua" ]]; then
    hypr_file="$HYPR_DIR/custom/execs.lua"   # illogical-impulse / end-4 dots
elif [[ -f "$HYPR_DIR/hyprland.lua" ]]; then
    hypr_file="$HYPR_DIR/hyprland.lua"
else
    hypr_file=""
fi
# An earlier install may have the line in another file of the Hyprland folder.
loaded_in="$(grep -rlF -e "${old_paths[0]}" -e "${old_paths[1]}" -e "${entry#"$HOME"}" "$HYPR_DIR" --include='*.lua' 2>/dev/null | grep -v -e '\.backup' -e "^$HYPR_LUA_DIR/" -e "^$HYPR_DIR/hi-shell.lua$" | head -1 || true)"
[[ -n "$loaded_in" ]] && hypr_file="$loaded_in"

# Copy the files; one that differs from hi-shell's (yours, edited) is replaced only on request.
copy_hypr_lua() {
    local src name changed=false
    mkdir -p "$HYPR_LUA_DIR"
    for src in "$REPO"/hypr/hi-shell/*.lua; do
        name="$(basename "$src")"
        [[ -f "$HYPR_LUA_DIR/$name" ]] && ! cmp -s "$src" "$HYPR_LUA_DIR/$name" && changed=true
    done
    if $changed && ! ask "Files in $HYPR_LUA_DIR differ from hi-shell's. Replace them (yours are kept as <name>.backup-<date>)?"; then
        # Only the files you don't have yet.
        for src in "$REPO"/hypr/hi-shell/*.lua; do
            [[ -e "$HYPR_LUA_DIR/$(basename "$src")" ]] || cp "$src" "$HYPR_LUA_DIR/"
        done
        return 0
    fi
    for src in "$REPO"/hypr/hi-shell/*.lua; do
        name="$(basename "$src")"
        if [[ -f "$HYPR_LUA_DIR/$name" ]] && ! cmp -s "$src" "$HYPR_LUA_DIR/$name"; then
            cp "$HYPR_LUA_DIR/$name" "$HYPR_LUA_DIR/$name.backup-$(date +%Y%m%d-%H%M%S)"
        fi
        cp "$src" "$HYPR_LUA_DIR/$name"
    done
    echo "Copied hi-shell's Hyprland files to $HYPR_LUA_DIR (edit your keys and rules there)"
    # The single file of the previous layout is replaced by the folder.
    if [[ -f "$HYPR_DIR/hi-shell.lua" ]]; then
        mv "$HYPR_DIR/hi-shell.lua" "$HYPR_DIR/hi-shell.lua.backup-$(date +%Y%m%d-%H%M%S)"
        echo "Moved the old $HYPR_DIR/hi-shell.lua aside (any edits of yours are in the backup)"
    fi
}

if [[ ${WANT[hypr]} != true ]]; then
    echo "Skipped. Copy hypr/hi-shell/ to $HYPR_LUA_DIR and add this line to your Hyprland config yourself: $line"
elif [[ -z "$hypr_file" ]]; then
    warn "no Lua Hyprland config found ($HYPR_DIR/hyprland.lua). hi-shell needs Hyprland 0.56+ with the Lua config;"
    warn "copy hypr/hi-shell/ to $HYPR_LUA_DIR and add this line to your config yourself: $line"
elif grep -qF "${entry#"$HOME"}" "$hypr_file"; then
    echo "Already loaded from $hypr_file"
    copy_hypr_lua
elif ask "Should I copy hi-shell's Hyprland files to $HYPR_LUA_DIR and load them from $hypr_file (a backup of the file is kept)?"; then
    copy_hypr_lua
    cp "$hypr_file" "$hypr_file.backup-hi-shell"
    if grep -qF -e "${old_paths[0]}" -e "${old_paths[1]}" "$hypr_file"; then
        # An earlier layout: point its line at the folder.
        sed -i -e "\\#${old_paths[0]}#c\\$line" -e "\\#${old_paths[1]}#c\\$line" "$hypr_file"
        echo "Updated the line in $hypr_file (backup: $hypr_file.backup-hi-shell)"
    else
        # Start on a new line; uninstall.sh removes exactly these two lines.
        [[ -s "$hypr_file" && -n "$(tail -c1 "$hypr_file")" ]] && echo >>"$hypr_file"
        printf '%s\n%s\n' "$MARKER" "$line" >>"$hypr_file"
        echo "Added to $hypr_file (backup: $hypr_file.backup-hi-shell)"
    fi
fi

# Another bar or notification daemon would run next to hi-shell.
for other in "qs -c ii" "caelestia" "waybar" "noctalia" "swaync" "mako" "dunst"; do
    if pgrep -f "$other" >/dev/null; then
        warn "\"$other\" is running; stop it (and remove it from your Hyprland autostart) to use hi-shell alone"
    fi
done

# --- Terminal configs (dots/) ---
# Each one is offered separately; an existing file is kept as <file>.backup-<date>.
install_dot() { # install_dot <name> <file in dots/> <destination>
    local src="$REPO/dots/$2" dst="$3"
    [[ -f "$src" && ${WANT[$1]} == true ]] || return 0
    if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
        echo "$1: already installed"
        return 0
    fi
    ask "Should I install hi-shell's $1 config ($dst)?" || return 0
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" ]]; then
        local backup="$dst.backup-$(date +%Y%m%d-%H%M%S)"
        cp -a "$dst" "$backup"
        echo "$1: previous config kept as $backup"
    fi
    cp "$src" "$dst"
    echo "$1: installed"
}
if [[ ${WANT[fish]} == true || ${WANT[kitty]} == true || ${WANT[fastfetch]} == true || ${WANT[btop]} == true ]]; then
    step "Terminal configs"
    install_dot fish fish/config.fish "${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
    install_dot kitty kitty/kitty.conf "${XDG_CONFIG_HOME:-$HOME/.config}/kitty/kitty.conf"
    install_dot fastfetch fastfetch/config.jsonc "${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/config.jsonc"
    install_dot btop btop/btop.conf "${XDG_CONFIG_HOME:-$HOME/.config}/btop/btop.conf"
fi

# Dolphin: the file list in Google Sans Flex. Only the font keys of dolphinrc are written (through
# kwriteconfig6), so the rest of your Dolphin settings stay; the file is kept as dolphinrc.backup-<date>.
if [[ ${WANT[dolphin]} == true ]] && command -v dolphin >/dev/null && command -v kwriteconfig6 >/dev/null; then
    step "Dolphin"
    rc="${XDG_CONFIG_HOME:-$HOME/.config}/dolphinrc"
    if [[ "$(kreadconfig6 --file dolphinrc --group DetailsMode --key FontFamily 2>/dev/null)" == "Google Sans Flex" ]]; then
        echo "dolphin: already uses Google Sans Flex"
    elif ask "Should I set Google Sans Flex as Dolphin's file list font ($rc)?"; then
        [[ -f "$rc" ]] && cp -a "$rc" "$rc.backup-$(date +%Y%m%d-%H%M%S)"
        for mode in IconsMode CompactMode DetailsMode; do
            kwriteconfig6 --file dolphinrc --group "$mode" --key UseSystemFont false
            kwriteconfig6 --file dolphinrc --group "$mode" --key FontFamily "Google Sans Flex"
            kwriteconfig6 --file dolphinrc --group "$mode" --key FontSize 11
        done
        echo "dolphin: done (applies the next time Dolphin starts)"
    fi
fi

command -v claude >/dev/null || warn "Claude Code isn't installed: the AI palette and chat need it (npm install -g @anthropic-ai/claude-code, then run claude once)"

# --- Start ---
if $START && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    step "Start"
    hyprctl reload >/dev/null || true
    qs -c hi-shell kill &>/dev/null || true
    "$REPO/run.sh" -d &>/dev/null
    errors=$(hyprctl configerrors 2>/dev/null | grep -v '^$' || true)
    [[ -n "$errors" ]] && warn "hyprctl configerrors:"$'\n'"$errors"
    echo "hi-shell is running. Tap Super for the launcher, Super+Escape for settings."
else
    echo "Done. hi-shell starts with Hyprland (or run: qs -c hi-shell -d)."
fi
