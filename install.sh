#!/usr/bin/env bash
# hi-shell installer for Arch Linux, ALT Linux (Sisyphus) and Debian (13 trixie with its backports, testing, sid)
# + Hyprland 0.56+ (Lua config); on NixOS it sets everything up but the packages.
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
#   --channel=git|release  where update.sh gets updates: the latest main (git) or the latest
#               tagged release (release, the default with --yes); asked when not given
#   --with-apps also install the optional apps (Zen Browser, Telegram, Vesktop, osu!lazer,
#               Steam, Spotify, Neovim) with --yes; in the menu they're off by default
#   --only=a,b  only these parts (and the hi-shell files, always), e.g. --only=hypr,fish
#   --skip=a,b  everything else but these parts; the part names: --list
#   --list      print the part names and exit
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

DEPS=true YES=false START=true DOTS=true APPS=false CHANNEL="" ONLY="" SKIP="" LIST=false
NOCONFIRM=()
for arg in "$@"; do
    case "$arg" in
        --channel=git | --channel=release) CHANNEL="${arg#--channel=}" ;;
        --channel*) echo "Use --channel=git or --channel=release" >&2; exit 1 ;;
        --no-deps) DEPS=false ;;
        --yes | -y) YES=true; NOCONFIRM=(--noconfirm) ;;
        --no-start) START=false ;;
        --no-dots) DOTS=false ;;
        --with-apps) APPS=true ;;
        --only=*) ONLY="${arg#--only=}" ;;
        --skip=*) SKIP="${arg#--skip=}" ;;
        --list) LIST=true ;;
        -h | --help) sed -n '2,/^set -euo/p' "$0" | sed -e '$d' -e 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg (see --help)" >&2; exit 1 ;;
    esac
done

# Run from the pacman package (/usr/share/hi-shell, which has .package): pacman put the files and the
# packages in place and updates them, so this only sets up your user: the link, Hyprland, the dots.
self="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd -P "$(dirname "$(readlink -f "$self" 2>/dev/null || echo "$self")")" 2>/dev/null && pwd -P || true)"
PACKAGED=false
if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/.package" && -f "$SCRIPT_DIR/shell.qml" ]]; then
    PACKAGED=true DEPS=false CHANNEL=release
fi

# The system: arch (pacman + AUR), alt (ALT Linux: apt-get + rpm), debian (apt-get + dpkg) or nixos (the
# packages come from the Nix config). HI_SHELL_DISTRO picks one by hand (the tests do).
detect_distro() {
    if [[ -n "${HI_SHELL_DISTRO:-}" ]]; then
        echo "$HI_SHELL_DISTRO"
    elif [[ -e /etc/NIXOS ]]; then
        echo nixos
    elif [[ -e /etc/altlinux-release ]] || grep -qsE '^ID="?altlinux"?$' /etc/os-release; then
        echo alt
    elif grep -qsE '^ID="?debian"?$' /etc/os-release; then
        echo debian
    else
        echo arch
    fi
}
DISTRO="$(detect_distro)"
case "$DISTRO" in
    arch | alt | debian | nixos) ;;
    *) echo "HI_SHELL_DISTRO must be arch, alt, debian or nixos" >&2; exit 1 ;;
esac
IS_NIXOS=false IS_ALT=false IS_DEBIAN=false
[[ "$DISTRO" == nixos ]] && IS_NIXOS=true
[[ "$DISTRO" == alt ]] && IS_ALT=true
[[ "$DISTRO" == debian ]] && IS_DEBIAN=true

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
# The package brings its packages itself.
$PACKAGED && PARTS=("${PARTS[@]:1}")
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
$IS_ALT && PART_NAME[deps]="Packages hi-shell needs (apt-get, ALT Sisyphus)"
$IS_DEBIAN && PART_NAME[deps]="Packages hi-shell needs (apt-get, Debian; Hyprland from the backports on stable)"
# Optional apps: the package to install (the first name found in a repo or the AUR wins).
declare -A APP_PKG=(
    [zen]="zen-browser-bin" [telegram]="telegram-desktop" [vesktop]="vesktop vesktop-bin"
    [osu]="osu-lazer-bin" [steam]="steam" [spotify]="spotify" [neovim]="neovim"
)
declare -A WANT=([deps]=$DEPS [hypr]=true [fish]=$DOTS [kitty]=$DOTS [fastfetch]=$DOTS [btop]=$DOTS [dolphin]=$DOTS [start]=$START
    [zen]=$APPS [telegram]=$APPS [vesktop]=$APPS [osu]=$APPS [steam]=$APPS [spotify]=$APPS [neovim]=$APPS)
# --only / --skip: the parts named switch on (the rest off) / off; a name that isn't a part stops the install.
apply_part_flags() {
    local list n
    for list in "$ONLY" "$SKIP"; do
        for n in ${list//,/ }; do
            [[ -v PART_NAME[$n] ]] || die "no part called \"$n\" (see --list)"
        done
    done
    if $LIST; then
        for n in "${PARTS[@]}"; do printf '  %-10s %s\n' "$n" "${PART_NAME[$n]}"; done
        exit 0
    fi
    if [[ -n "$ONLY" ]]; then
        for n in "${PARTS[@]}"; do WANT[$n]=false; done
        for n in ${ONLY//,/ }; do WANT[$n]=true; done
    fi
    for n in ${SKIP//,/ }; do WANT[$n]=false; done
    DEPS=${WANT[deps]} START=${WANT[start]}
}
apply_part_flags

choose_parts() {
    $YES && return
    # The parts were given on the command line: no menu.
    [[ -n "$ONLY$SKIP" ]] && return
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
# NixOS has no pacman: its packages come from the Nix config (printed below); everything else is the same.
# ALT Linux installs them with apt-get (Sisyphus: the stable branches have a Hyprland too old for hi-shell).
if $IS_NIXOS; then
    echo "NixOS: packages are not installed here; see the list in the packages step."
elif $IS_ALT; then
    command -v apt-get >/dev/null && command -v rpm >/dev/null || die "ALT Linux without apt-get and rpm?"
elif $IS_DEBIAN; then
    command -v apt-get >/dev/null && command -v dpkg-query >/dev/null || die "Debian without apt-get and dpkg?"
else
    command -v pacman >/dev/null || die "hi-shell targets Arch Linux, ALT Linux, Debian and NixOS (pacman not found)"
fi
choose_parts
$PACKAGED && DEPS=false

# Where update.sh gets updates from; kept in the config (update.channel).
choose_channel() {
    [[ -n "$CHANNEL" ]] && return
    # Installed before: keep the choice made then.
    CHANNEL="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("update", {}).get("channel", ""))' "${XDG_CONFIG_HOME:-$HOME/.config}/hi-shell/config.json" 2>/dev/null || true)"
    [[ "$CHANNEL" == git || "$CHANNEL" == release ]] && return
    CHANNEL=release
    $YES && return
    [[ -r /dev/tty ]] || return
    local reply
    step "How should hi-shell update?"
    echo "  1) release  the latest tagged release: tested, changes less often (default)"
    echo "  2) git      the latest main: the newest features, may break now and then"
    read -r -p "1 or 2, Enter = release (change it later in Settings > About): " reply </dev/tty || return
    [[ "$reply" == 2 || "${reply,,}" == git ]] && CHANNEL=git
}
choose_channel

# The AUR helper's flags: with no questions (--yes, the installer window) paru would still stop to show the
# PKGBUILDs, so it skips that review; yay's --noconfirm already does.
aur_flags() { # aur_flags <helper path>
    AUR_FLAGS=("${NOCONFIRM[@]}")
    ((${#NOCONFIRM[@]})) && [[ "$(basename "$1")" == paru ]] && AUR_FLAGS+=(--skipreview)
    return 0
}

# --- Packages ---
PACMAN_PKGS=(
    matugen python pipewire wireplumber networkmanager bluez upower brightnessctl ddcutil
    libnotify hyprsunset hyprlock cliphist translate-shell grim slurp wl-clipboard hyprpicker
    cava imagemagick curl libqalculate tesseract tesseract-data-eng tesseract-data-rus wf-recorder pacman-contrib git python-fonttools wtype ffmpeg qt6-multimedia-ffmpeg starship
)
AUR_PKGS=(quickshell-git ttf-material-symbols-variable-git)

# NixOS names of the same packages (nixpkgs).
NIX_PKGS=(
    matugen python3 pipewire wireplumber networkmanager bluez upower brightnessctl ddcutil
    libnotify hyprsunset hyprlock cliphist translate-shell grim slurp wl-clipboard hyprpicker
    cava imagemagick curl libqalculate tesseract wf-recorder git python3Packages.fonttools wtype ffmpeg
    quickshell material-symbols
)

# ALT Linux (Sisyphus) names. Material Symbols isn't packaged there: install_symbols_font gets it.
ALT_PKGS=(
    hyprland quickshell matugen python3 pipewire wireplumber NetworkManager bluez upower brightnessctl ddcutil
    libnotify notify-send hyprsunset hyprlock cliphist translate-shell grim slurp wl-clipboard hyprpicker
    cava ImageMagick-tools curl qalculate tesseract tesseract-langpack-en tesseract-langpack-ru wf-recorder git-core
    python3-module-fonttools wtype ffmpeg libqt6-multimedia starship
)
ALT_MIN_HYPRLAND=0.56
SYMBOLS_FAMILY="Material Symbols Rounded"
SYMBOLS_URL="https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"

# sudo apt-get install, after an apt-get update (a stale package list fails on Sisyphus, which changes daily).
alt_install() { # alt_install <package>...
    local yes=()
    ((${#NOCONFIRM[@]})) && yes=(-y)
    sudo apt-get update && sudo apt-get install "${yes[@]}" "$@" && return 0
    warn "apt-get failed. If sudo refused you: ALT turns sudo off by default; as root (su -) run"
    warn "  control sudowheel enabled; gpasswd -a $USER wheel   then log in again and rerun the installer"
    return 1
}

# The icon font from Google's repository into ~/.local/share/fonts/hi-shell, when no package brought it.
install_symbols_font() {
    if fc-list -q "$SYMBOLS_FAMILY" 2>/dev/null; then
        echo "$SYMBOLS_FAMILY is installed."
        return 0
    fi
    local dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/hi-shell"
    local file="$dir/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
    ask "The icon font ($SYMBOLS_FAMILY) isn't packaged here. Should I download it from Google's GitHub (15 MB) to $dir?" || return 0
    mkdir -p "$dir"
    if curl -fL --retry 2 -o "$file.part" "$SYMBOLS_URL"; then
        mv "$file.part" "$file"
        fc-cache -f "$dir" >/dev/null 2>&1 || true
        echo "Installed $file"
    else
        rm -f "$file.part"
        warn "couldn't download the icon font; get it yourself: $SYMBOLS_URL"
    fi
}

# hi-shell's Hyprland files are Lua, which Hyprland reads from 0.56 on; ALT's stable branches have older ones.
alt_check_hyprland() {
    local version
    version="$(rpm -q --qf '%{VERSION}' hyprland 2>/dev/null)" || { warn "Hyprland isn't installed (sudo apt-get install hyprland)"; return 0; }
    if [[ "$(printf '%s\n' "$ALT_MIN_HYPRLAND" "$version" | sort -V | head -1)" != "$ALT_MIN_HYPRLAND" ]]; then
        warn "Hyprland $version is too old: hi-shell needs $ALT_MIN_HYPRLAND+ (the Lua config), which ALT has in Sisyphus;"
        warn "switch to Sisyphus (as root: apt-repo set Sisyphus; apt-get update; apt-get dist-upgrade) or wait for the next stable branch"
    fi
}

# Debian names. Debian 13 (trixie) has Hyprland and Quickshell only in its backports: DEB_HYPR_PKGS come from
# there (apt-get -t trixie-backports), testing and sid have them in the main archive. matugen and the icon font
# aren't packaged: install_matugen and install_symbols_font get them.
DEB_PKGS=(
    python3 pipewire wireplumber network-manager bluez upower brightnessctl ddcutil libnotify-bin
    cliphist translate-shell grim slurp wl-clipboard cava imagemagick curl qalc tesseract-ocr tesseract-ocr-eng
    tesseract-ocr-rus wf-recorder git python3-fonttools wtype ffmpeg qml6-module-qtmultimedia starship
)
DEB_HYPR_PKGS=(hyprland quickshell hyprlock hyprsunset hyprpicker)
# 0.55 already reads the Lua config (trixie-backports has 0.55.2); hi-shell is made and tested on 0.56+.
DEB_MIN_HYPRLAND=0.55
DEB_TESTED_HYPRLAND=0.56
DEB_OS_RELEASE="${HI_SHELL_OS_RELEASE:-/etc/os-release}"
DEB_APT_DIR="${HI_SHELL_APT_DIR:-/etc/apt}"
DEB_YES=()
((${#NOCONFIRM[@]})) && DEB_YES=(-y)
# matugen's own release build (a static-ish x86_64 binary, glibc 2.39+; trixie has 2.41), checked by its sha256.
MATUGEN_VERSION=4.2.0
MATUGEN_SHA256=a2e3b50e49ed6439999ba3c252ed04fabd98ee4e9d12e5e5dff2e66370569751
MATUGEN_URL="https://github.com/InioX/matugen/releases/download/v$MATUGEN_VERSION/matugen-$MATUGEN_VERSION-x86_64.tar.gz"

# The backports suite of a Debian release ("trixie-backports"); nothing on testing and sid (no VERSION_ID there).
deb_backports() {
    local id codename
    id="$(sed -n 's/^VERSION_ID=//p' "$DEB_OS_RELEASE" 2>/dev/null | tr -d '"')"
    codename="$(sed -n 's/^VERSION_CODENAME=//p' "$DEB_OS_RELEASE" 2>/dev/null | tr -d '"')"
    [[ -n "$id" && -n "$codename" ]] && echo "$codename-backports"
    return 0
}
deb_installed() { [[ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null)" == installed ]]; }
deb_available() { apt-cache policy "$1" 2>/dev/null | grep -q 'Candidate: [^(]'; }
# A suite named in apt's sources (one-line or deb822 files; commented lines don't count).
deb_has_suite() { grep -rqsE "^[^#]*[[:space:]]$1([[:space:]]|$)" "$DEB_APT_DIR/sources.list" "$DEB_APT_DIR/sources.list.d"; }

# sudo apt-get <args>; when it fails, how to get sudo (the Debian installer leaves you out of the sudo
# group when you gave root a password).
deb_apt() {
    sudo apt-get "$@" && return 0
    warn "apt-get failed. If sudo refused you: you're not in the sudo group; as root (su -) run"
    warn "  apt-get install sudo; adduser $USER sudo   then log in again and rerun the installer"
    return 1
}

# Adds <suite> (the backports) to apt's sources, asking first; true when it's there.
deb_add_suite() {
    deb_has_suite "$1" && return 0
    local file="$DEB_APT_DIR/sources.list.d/hi-shell-backports.sources"
    ask "Hyprland and Quickshell are in Debian's $1. Should I add it to apt's sources ($file)?" || return 1
    printf 'Types: deb\nURIs: http://deb.debian.org/debian\nSuites: %s\nComponents: main\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\n' "$1" |
        sudo tee "$file" >/dev/null
}

# matugen into ~/.local/bin (run.sh puts that on the shell's PATH), when it isn't installed.
install_matugen() {
    command -v matugen >/dev/null && return 0
    local bin="$HOME/.local/bin" tmp
    if [[ "$(uname -m)" != x86_64 ]]; then
        warn "matugen isn't packaged for Debian and has no release build for $(uname -m): cargo install matugen"
        return 0
    fi
    ask "matugen (the colors from the wallpaper) isn't packaged for Debian. Should I download its release $MATUGEN_VERSION from GitHub to $bin?" || return 0
    tmp="$(mktemp -d)"
    if curl -fL --retry 2 -o "$tmp/matugen.tar.gz" "$MATUGEN_URL" &&
        echo "$MATUGEN_SHA256  $tmp/matugen.tar.gz" | sha256sum -c --status - &&
        tar -xzf "$tmp/matugen.tar.gz" -C "$tmp" matugen; then
        mkdir -p "$bin"
        install -m 755 "$tmp/matugen" "$bin/matugen"
        echo "Installed $bin/matugen"
    else
        warn "couldn't install matugen (the download failed or its checksum didn't match): $MATUGEN_URL"
    fi
    rm -rf "$tmp"
}

deb_check_hyprland() {
    local version
    version="$(dpkg-query -W -f='${Version}' hyprland 2>/dev/null)" || { warn "Hyprland isn't installed"; return 0; }
    version="${version#*:}" version="${version%%[+~-]*}"
    if [[ "$(printf '%s\n' "$DEB_MIN_HYPRLAND" "$version" | sort -V | head -1)" != "$DEB_MIN_HYPRLAND" ]]; then
        warn "Hyprland $version is too old: hi-shell needs $DEB_MIN_HYPRLAND+ (the Lua config); Debian 13 has 0.55 in trixie-backports"
    elif [[ "$(printf '%s\n' "$DEB_TESTED_HYPRLAND" "$version" | sort -V | head -1)" != "$DEB_TESTED_HYPRLAND" ]]; then
        echo "Hyprland $version: hi-shell is made for $DEB_TESTED_HYPRLAND+; $version reads the same Lua config, but a few things may differ."
    fi
}

deb_packages() {
    local backports from=() missing=() hypr_missing=() unavailable=() p
    backports="$(deb_backports)"
    if [[ -n "$backports" ]]; then
        if deb_add_suite "$backports"; then
            from=(-t "$backports")
        else
            warn "without $backports, Debian stable has no Hyprland or Quickshell"
        fi
    fi
    for p in "${DEB_PKGS[@]}"; do deb_installed "$p" || missing+=("$p"); done
    for p in "${DEB_HYPR_PKGS[@]}"; do deb_installed "$p" || hypr_missing+=("$p"); done
    if ((${#missing[@]} + ${#hypr_missing[@]} == 0)); then
        echo "All packages are installed."
        return 0
    fi
    echo "Missing: ${missing[*]} ${hypr_missing[*]}"
    ask "Should I install them with apt-get?" || return 0
    deb_apt update || die "apt-get update failed"
    # What no source of yours has is left out (and named), so the rest still installs.
    local base=() hypr=()
    for p in "${missing[@]}"; do if deb_available "$p"; then base+=("$p"); else unavailable+=("$p"); fi; done
    for p in "${hypr_missing[@]}"; do if deb_available "$p"; then hypr+=("$p"); else unavailable+=("$p"); fi; done
    if ((${#unavailable[@]})); then
        warn "not in your apt sources: ${unavailable[*]}"
        [[ " ${unavailable[*]} " == *" translate-shell "* ]] &&
            warn "translate-shell is in contrib: add contrib to Components in $DEB_APT_DIR/sources.list.d/debian.sources"
    fi
    if ((${#base[@]})); then deb_apt install "${DEB_YES[@]}" "${base[@]}" || die "the packages weren't installed"; fi
    if ((${#hypr[@]})); then deb_apt install "${DEB_YES[@]}" "${from[@]}" "${hypr[@]}" || die "the packages weren't installed"; fi
    return 0
}

if $DEPS && $IS_DEBIAN; then
    step "Packages (Debian)"
    deb_packages
    install_matugen
    install_symbols_font
    deb_check_hyprland
elif $DEPS && $IS_ALT; then
    step "Packages (ALT Linux)"
    missing=()
    for p in "${ALT_PKGS[@]}"; do rpm -q --quiet "$p" 2>/dev/null || missing+=("$p"); done
    if ((${#missing[@]})); then
        echo "Missing: ${missing[*]}"
        if ask "Should I install them with apt-get?"; then
            alt_install "${missing[@]}" || die "the packages weren't installed"
        fi
    else
        echo "All packages are installed."
    fi
    install_symbols_font
    alt_check_hyprland
elif $DEPS && $IS_NIXOS; then
    step "Packages (NixOS)"
    echo "Add these to environment.systemPackages in your NixOS configuration, then nixos-rebuild switch:"
    echo "  ${NIX_PKGS[*]}"
    echo "(or try them first with: nix-shell -p ${NIX_PKGS[*]})"
elif $DEPS; then
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
                aur_flags "$helper"
                "$helper" -S --needed "${AUR_FLAGS[@]}" "${aur_missing[@]}"
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
if $IS_NIXOS; then
    # Optional apps are pacman / AUR packages: on NixOS they go in the Nix config.
    for app in "${APP_PARTS[@]}"; do [[ ${WANT[$app]} == true ]] && warn "$app: add it to your NixOS configuration (not installed here)"; done
    APP_PARTS=()
fi
# ALT Linux: a package of the repository, or "epm:<name>" for an app that `epm play` (eepm) installs.
declare -A ALT_APP_PKG=(
    [zen]="epm:zen-browser" [telegram]="telegram-desktop" [vesktop]="epm:vesktop"
    [osu]="osu-lazer" [steam]="epm:steam" [spotify]="epm:spotify" [neovim]="neovim"
)
if $IS_ALT; then
    alt_repo=() alt_epm=()
    for app in "${APP_PARTS[@]}"; do
        [[ ${WANT[$app]} == true ]] || continue
        p=${ALT_APP_PKG[$app]}
        if [[ "$p" == epm:* ]]; then
            alt_epm+=("${p#epm:}")
        elif ! rpm -q --quiet "$p" 2>/dev/null; then
            alt_repo+=("$p")
        fi
    done
    if ((${#alt_repo[@]} + ${#alt_epm[@]})); then
        step "Optional apps"
        if ((${#alt_repo[@]})); then
            echo "From the repository: ${alt_repo[*]}"
            if ask "Should I install them with apt-get?"; then alt_install "${alt_repo[@]}" || true; fi
        fi
        if ((${#alt_epm[@]})); then
            echo "With epm play: ${alt_epm[*]}"
            if ! command -v epm >/dev/null; then
                warn "epm isn't installed: sudo apt-get install eepm, then epm play ${alt_epm[*]}"
            elif ask "Should I install them with epm play?"; then
                epm_yes=()
                ((${#NOCONFIRM[@]})) && epm_yes=(--auto)
                for p in "${alt_epm[@]}"; do epm play "${epm_yes[@]}" "$p" || warn "epm play $p failed"; done
            fi
        fi
    fi
    APP_PARTS=()
fi
# Debian: a package (on stable from the backports when they're in apt's sources: telegram-desktop is only
# there), or "flatpak:<id>" for an app from Flathub.
declare -A DEB_APP_PKG=(
    [zen]="flatpak:app.zen_browser.zen" [telegram]="telegram-desktop" [vesktop]="flatpak:dev.vencord.Vesktop"
    [osu]="flatpak:sh.ppy.osu" [steam]="flatpak:com.valvesoftware.Steam" [spotify]="flatpak:com.spotify.Client"
    [neovim]="neovim"
)
if $IS_DEBIAN; then
    deb_repo=() deb_flat=() deb_from=()
    backports="$(deb_backports)"
    [[ -n "$backports" ]] && deb_has_suite "$backports" && deb_from=(-t "$backports")
    for app in "${APP_PARTS[@]}"; do
        [[ ${WANT[$app]} == true ]] || continue
        p=${DEB_APP_PKG[$app]}
        if [[ "$p" == flatpak:* ]]; then
            deb_flat+=("${p#flatpak:}")
        elif ! deb_installed "$p"; then
            deb_repo+=("$p")
        fi
    done
    if ((${#deb_repo[@]} + ${#deb_flat[@]})); then
        step "Optional apps"
        if ((${#deb_repo[@]})); then
            echo "From the repository: ${deb_repo[*]}"
            if ask "Should I install them with apt-get?"; then
                deb_apt update && deb_apt install "${DEB_YES[@]}" "${deb_from[@]}" "${deb_repo[@]}" || true
            fi
        fi
        if ((${#deb_flat[@]})); then
            echo "From Flathub: ${deb_flat[*]}"
            if ask "Should I install them with flatpak (for your user)?"; then
                command -v flatpak >/dev/null || deb_apt install "${DEB_YES[@]}" flatpak || true
                flat_yes=()
                ((${#NOCONFIRM[@]})) && flat_yes=(--noninteractive)
                if ! command -v flatpak >/dev/null; then
                    warn "flatpak isn't installed: sudo apt-get install flatpak, then flatpak install flathub ${deb_flat[*]}"
                elif ! flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo ||
                    ! flatpak install --user "${flat_yes[@]}" flathub "${deb_flat[@]}"; then
                    warn "flatpak install failed: flatpak install --user flathub ${deb_flat[*]}"
                fi
            fi
        fi
    fi
    APP_PARTS=()
fi
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
            if ask "Should I install them with $(basename "$helper")?"; then
                aur_flags "$helper"
                "$helper" -S --needed "${AUR_FLAGS[@]}" "${app_aur[@]}"
            fi
        else
            warn "install ${app_aur[*]} from the AUR (no paru or yay found)"
        fi
    fi
fi

if ! command -v qs >/dev/null; then
    if $IS_NIXOS; then
        die "quickshell (qs) is not installed; add quickshell to environment.systemPackages"
    elif $IS_ALT; then
        die "quickshell (qs) is not installed; sudo apt-get install quickshell"
    elif $IS_DEBIAN; then
        die "quickshell (qs) is not installed; sudo apt-get install -t trixie-backports quickshell (Debian 13; testing and sid: without -t)"
    else
        die "quickshell (qs) is not installed; install quickshell-git from the AUR"
    fi
fi

# --- Source ---
step "Source"
# The real folder, symlinks resolved: run as ~/.config/quickshell/hi-shell/install.sh it would otherwise
# take the link for the checkout and point the link at itself ("Too many levels of symbolic links").
if $PACKAGED; then
    REPO="$SCRIPT_DIR"
    echo "Using the pacman package: $REPO (it updates with the system)"
elif [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/shell.qml" && -e "$SCRIPT_DIR/.git" ]]; then
    REPO="$SCRIPT_DIR"
    echo "Using this checkout: $REPO"
elif [[ -d "$CLONE_DIR/.git" ]]; then
    REPO="$CLONE_DIR"
    echo "Using the existing clone: $REPO (update it with update.sh)"
else
    REPO="$CLONE_DIR"
    mkdir -p "$(dirname "$REPO")"
    tag=""
    if [[ "$CHANNEL" == release ]]; then
        tag="$(git ls-remote --tags --refs "$REPO_URL" 'v*' | sed 's#.*refs/tags/##' | sort -V | tail -1)"
        [[ -n "$tag" ]] || warn "no release found, installing the latest main instead"
    fi
    if [[ -n "$tag" ]]; then
        echo "Release $tag"
        git clone --depth 1 --branch "$tag" "$REPO_URL" "$REPO"
    else
        git clone --depth 1 "$REPO_URL" "$REPO"
    fi
fi

# Remember the choice for update.sh (merged into the config the shell keeps).
python3 - "${XDG_CONFIG_HOME:-$HOME/.config}/hi-shell/config.json" "$CHANNEL" <<'PY'
import json, os, sys
path, channel = sys.argv[1:3]
try:
    with open(path) as f:
        data = json.load(f)
except (OSError, ValueError):
    data = {}
data.setdefault("update", {})["channel"] = channel
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
PY
echo "Updates from: $CHANNEL"

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

# The package puts hi in /usr/bin and its completions in the system folders.
if $PACKAGED; then
    echo "hi and its completions come with the package"
else
    # The command line (hi-shell doctor, qr, keybinds, ipc) in ~/.local/bin, if nothing else uses that name.
    cli="$HOME/.local/bin/hi-shell"
    mkdir -p "$HOME/.local/bin"
    if [[ ! -e "$cli" || -L "$cli" ]]; then
        ln -sfn "$REPO/sh/hi-shell" "$cli"
        echo "$cli -> $REPO/sh/hi-shell"
    else
        warn "$cli exists and isn't a link, left alone"
    fi
    # The short name, `hi`, and its fish completions.
    short="$HOME/.local/bin/hi"
    if [[ ! -e "$short" || -L "$short" ]]; then
        ln -sfn "$REPO/sh/hi-shell" "$short"
        echo "$short -> $REPO/sh/hi-shell"
    fi
    # Completions for hi in every shell that's installed (all three ask `hi __complete`).
    data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
    if command -v fish >/dev/null; then
        mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/fish/completions"
        ln -sfn "$REPO/sh/completions/hi.fish" "${XDG_CONFIG_HOME:-$HOME/.config}/fish/completions/hi.fish"
    fi
    if command -v bash >/dev/null; then
        # bash-completion loads these by the command's name.
        mkdir -p "$data_home/bash-completion/completions"
        for n in hi hi-shell; do ln -sfn "$REPO/sh/completions/hi.bash" "$data_home/bash-completion/completions/$n"; done
    fi
    if command -v zsh >/dev/null; then
        zfuncs="$data_home/zsh/site-functions"
        mkdir -p "$zfuncs"
        ln -sfn "$REPO/sh/completions/hi.zsh" "$zfuncs/_hi"
        if ! zsh -ic 'print -l $fpath' 2>/dev/null | grep -qxF "$zfuncs"; then
            echo "zsh: for completions of hi, add this line to ~/.zshrc before compinit: fpath+=($zfuncs)"
        fi
    fi
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) warn "$HOME/.local/bin isn't on your PATH: add it to use the hi command (fish: fish_add_path ~/.local/bin)" ;;
    esac
fi

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
    local src name changed=false keep
    mkdir -p "$HYPR_LUA_DIR"
    # "Keep my Hyprland files on update" (Settings > Hyprland): add only the files you don't have.
    keep="$(python3 -c 'import json,sys; print(str(bool(json.load(open(sys.argv[1])).get("hyprland", {}).get("keepFiles"))).lower())' "${XDG_CONFIG_HOME:-$HOME/.config}/hi-shell/config.json" 2>/dev/null || echo false)"
    if [[ "$keep" == true ]]; then
        for src in "$REPO"/hypr/hi-shell/*.{lua,sh}; do
            [[ -e "$HYPR_LUA_DIR/$(basename "$src")" ]] || cp "$src" "$HYPR_LUA_DIR/"
        done
        echo "Kept your files in $HYPR_LUA_DIR (Settings > Hyprland > Keep my Hyprland files on update)"
        return 0
    fi
    for src in "$REPO"/hypr/hi-shell/*.{lua,sh}; do
        name="$(basename "$src")"
        [[ -f "$HYPR_LUA_DIR/$name" ]] && ! cmp -s "$src" "$HYPR_LUA_DIR/$name" && changed=true
    done
    if $changed && ! ask "Files in $HYPR_LUA_DIR differ from hi-shell's. Replace them (yours are kept as <name>.backup-<date>)?"; then
        # Only the files you don't have yet.
        for src in "$REPO"/hypr/hi-shell/*.{lua,sh}; do
            [[ -e "$HYPR_LUA_DIR/$(basename "$src")" ]] || cp "$src" "$HYPR_LUA_DIR/"
        done
        return 0
    fi
    for src in "$REPO"/hypr/hi-shell/*.{lua,sh}; do
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
