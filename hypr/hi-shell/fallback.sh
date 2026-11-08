#!/bin/sh
# The keys of hi-shell when its shell isn't running (it crashed, or it's off): the same job, done with
# programs that don't need the shell. The keybinds call it as `sh fallback.sh <job>`:
#   launcher   the app launcher             (fuzzel)
#   region     a screenshot of a region     (slurp + grim, to the clipboard and ~/Pictures/Screenshots)
#   screen     a screenshot of the screen   (grim, to the clipboard and ~/Pictures/Screenshots)
#   lock       the lock screen              (the shell's own; hyprlock, with hi-shell's config, when the shell is down)
#   session    the power menu               (wlogout)
# A job first asks the shell (qs -c hi-shell ipc call ...); the program runs only when that fails.

shell_call() {
    pgrep -f 'qs -c hi-shell' >/dev/null 2>&1 && qs -c hi-shell ipc call "$@" >/dev/null 2>&1
}

shot() {
    dir="$HOME/Pictures/Screenshots"
    mkdir -p "$dir"
    file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
    grim "$@" "$file" && wl-copy < "$file" && notify-send -a hi-shell -i camera-photo "Screenshot saved" "$file"
}

case "$1" in
    launcher)
        shell_call launcher toggle || fuzzel
        ;;
    region)
        shell_call region screenshot || { geometry=$(slurp) && [ -n "$geometry" ] && shot -g "$geometry"; }
        ;;
    screen)
        shell_call region fullscreen || shot
        ;;
    lock)
        shell_call session lock && exit 0
        if [ -f "$HOME/.config/hi-shell/hyprlock.conf" ]; then
            pidof hyprlock >/dev/null 2>&1 || hyprlock -c "$HOME/.config/hi-shell/hyprlock.conf"
        else
            pidof hyprlock >/dev/null 2>&1 || hyprlock
        fi
        ;;
    session)
        shell_call session toggleScreen || { pkill wlogout 2>/dev/null || wlogout -p layer-shell; }
        ;;
    *)
        echo "usage: fallback.sh launcher|region|screen|lock|session" >&2
        exit 2
        ;;
esac
