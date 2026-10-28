#!/usr/bin/env bash
# Update hi-shell and restart the shell.
#
#   ./update.sh            (or ~/.config/quickshell/hi-shell/update.sh)
#
# Where from is the choice made at install (Settings > About, or "update.channel" in the config):
# "git" pulls the latest main with `git pull --ff-only`, "release" moves to the latest tagged
# release. Either way, local edits that conflict stop the update instead of being overwritten.
# Reloads Hyprland when hypr/ changed.
set -euo pipefail

bold=$'\e[1m' green=$'\e[32m' yellow=$'\e[33m' red=$'\e[31m' reset=$'\e[0m'
step() { echo "${bold}${green}::${reset}${bold} $*${reset}"; }
die() { echo "${red}error:${reset} $*" >&2; exit 1; }

[[ "${1:-}" =~ ^(-h|--help)$ ]] && { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

# The repo this script lives in (works through the ~/.config/quickshell symlink too).
REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
[[ -d "$REPO/.git" ]] || die "$REPO is not a git checkout; reinstall with install.sh"
cd "$REPO"

channel="$(python3 -c 'import json,sys; c=json.load(open(sys.argv[1])).get("update", {}).get("channel"); print("release" if c == "release" else "git")' "${XDG_CONFIG_HOME:-$HOME/.config}/hi-shell/config.json" 2>/dev/null || echo git)"

step "Updating $REPO ($channel)"
before=$(git rev-parse HEAD)
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "${yellow}You have local changes:${reset}"
    git status --short
    echo "They're kept; the update stops if they conflict."
fi
if [[ "$channel" == release ]]; then
    latest="$(git ls-remote --tags --refs origin 'v*' | sed 's#.*refs/tags/##' | sort -V | tail -1)"
    [[ -n "$latest" ]] || die "no release found on origin; switch to git in Settings > About, or check your connection"
    if [[ "$(git describe --tags --exact-match 2>/dev/null || true)" == "$latest" ]]; then
        echo "Already on the latest release ($latest)."
        exit 0
    fi
    git fetch --quiet --depth 1 origin "refs/tags/$latest:refs/tags/$latest" || die "couldn't fetch $latest"
    git checkout --quiet "$latest" || die "couldn't switch to $latest (your local changes conflict); resolve them in $REPO and run again"
    echo "Release $latest"
else
    # Back from a release (a detached checkout) to main.
    if ! git symbolic-ref -q HEAD >/dev/null; then
        git fetch --quiet --depth 1 origin main:refs/remotes/origin/main || die "couldn't fetch main"
        git checkout --quiet -B main origin/main || die "couldn't switch to main (your local changes conflict); resolve them in $REPO and run again"
        git branch --quiet --set-upstream-to=origin/main main
    fi
    git pull --ff-only || die "couldn't fast-forward (local commits or conflicting changes); resolve them in $REPO and run again"
fi
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
        # new one waits next to it as <name>.new. Files you don't have yet are added. With
        # "Keep my Hyprland files on update" (Settings > Hyprland) nothing in that folder is touched:
        # the files that changed are only listed.
        hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
        keep="$(python3 -c 'import json,sys; print(str(bool(json.load(open(sys.argv[1])).get("hyprland", {}).get("keepFiles"))).lower())' "${XDG_CONFIG_HOME:-$HOME/.config}/hi-shell/config.json" 2>/dev/null || echo false)"
        reload=true
        if [[ ! -d "$hypr_dir/hi-shell" ]]; then
            echo "${yellow}hi-shell's Hyprland files (keybinds, rules) are a folder now, hypr/hi-shell/. They keep loading from the repo; run ./install.sh to copy them to $hypr_dir/hi-shell, where you can edit them.${reset}"
        elif [[ "$keep" == true ]]; then
            reload=false
            echo "Your Hyprland files in $hypr_dir/hi-shell are kept as they are (Settings > Hyprland). Changed upstream:"
            git diff --name-only "$before" "$after" -- hypr/hi-shell | sed 's#^hypr/hi-shell/#  #'
            echo "  see them with: git -C $REPO diff $before $after -- hypr/hi-shell"
        else
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
        fi
        if $reload; then
            step "Reloading Hyprland (keybinds changed)"
            hyprctl reload >/dev/null || true
        fi
    fi
    step "Restarting hi-shell"
    qs -c hi-shell kill &>/dev/null || true
    "$REPO/run.sh" -d &>/dev/null
fi
echo "Updated to $(git log -1 --format='%h %s')."
