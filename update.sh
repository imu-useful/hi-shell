#!/usr/bin/env bash
# Update hi-shell: pull the latest version and restart the shell.
#
#   ./update.sh            (or ~/.config/quickshell/hi-shell/update.sh)
#
# Uses `git pull --ff-only`, so local commits or edits that conflict stop the
# update instead of being overwritten. Reloads Hyprland when hypr/ changed.
set -euo pipefail

bold=$'\e[1m' green=$'\e[32m' yellow=$'\e[33m' red=$'\e[31m' reset=$'\e[0m'
step() { echo "${bold}${green}::${reset}${bold} $*${reset}"; }
die() { echo "${red}error:${reset} $*" >&2; exit 1; }

[[ "${1:-}" =~ ^(-h|--help)$ ]] && { sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

# The repo this script lives in (works through the ~/.config/quickshell symlink too).
REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
[[ -d "$REPO/.git" ]] || die "$REPO is not a git checkout; reinstall with install.sh"
cd "$REPO"

step "Updating $REPO"
before=$(git rev-parse HEAD)
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "${yellow}You have local changes:${reset}"
    git status --short
    echo "They're kept; the update stops if they conflict."
fi
git pull --ff-only || die "couldn't fast-forward (local commits or conflicting changes); resolve them in $REPO and run again"
after=$(git rev-parse HEAD)

if [[ "$before" == "$after" ]]; then
    echo "Already up to date ($(git log -1 --format='%h %s'))."
    exit 0
fi

echo
git log --oneline "$before..$after"
echo

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    if ! git diff --quiet "$before" "$after" -- hypr/; then
        # hypr/hi-shell/ is copied to ~/.config/hypr/hi-shell/, where you may have edited it: a file
        # is replaced only while it's still the version that came with the old release, else the
        # new one waits next to it as <name>.new. Files you don't have yet are added.
        hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
        if [[ -d "$hypr_dir/hi-shell" ]]; then
            for src in "$REPO"/hypr/hi-shell/*.lua; do
                name="$(basename "$src")"
                mine="$hypr_dir/hi-shell/$name"
                if [[ ! -f "$mine" ]]; then
                    cp "$src" "$mine"
                    echo "Added $mine"
                elif cmp -s "$src" "$mine"; then
                    :
                elif git show "$before:hypr/hi-shell/$name" 2>/dev/null | cmp -s - "$mine"; then
                    cp "$src" "$mine"
                    echo "Updated $mine"
                else
                    cp "$src" "$mine.new"
                    echo "${yellow}$mine has your changes: the new version is in $mine.new, merge it by hand.${reset}"
                fi
            done
        else
            echo "${yellow}hi-shell's Hyprland files (keybinds, rules) are a folder now, hypr/hi-shell/. They keep loading from the repo; run ./install.sh to copy them to $hypr_dir/hi-shell, where you can edit them.${reset}"
        fi
        step "Reloading Hyprland (keybinds changed)"
        hyprctl reload >/dev/null || true
    fi
    step "Restarting hi-shell"
    qs -c hi-shell kill &>/dev/null || true
    "$REPO/run.sh" -d &>/dev/null
fi
echo "Updated to $(git log -1 --format='%h %s')."
