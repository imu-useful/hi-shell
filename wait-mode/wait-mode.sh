#!/bin/sh
# Wait Mode: a cover for the person while an AI works on the machine (see shell.qml).
#
#   wait-mode.sh start             cover the screens (a systemd user unit: hi-shell restarts don't touch it)
#   wait-mode.sh stop              end it
#   wait-mode.sh status            locked / bypass, Esc presses, music, whether the key binds are off
#   wait-mode.sh bypass on [secs]  invisible and click-through for secs (30, at most 300), for tests
#   wait-mode.sh bypass off        the cover is back
#
# The person ends it with Esc three times (or Ctrl+Alt+Shift+Esc, the way out if that fails).
dir=$(dirname "$(readlink -f "$0")")
unit=hi-wait-mode
qs=$(command -v qs) || { echo "qs (Quickshell) not found" >&2; exit 1; }

running() {
    systemctl --user is-active --quiet "$unit"
}

case "$1" in
start)
    if running; then
        echo "Wait Mode is already on"
        exit 0
    fi
    exec systemd-run --user --unit="$unit" --collect --quiet \
        --setenv=WAYLAND_DISPLAY --setenv=XDG_RUNTIME_DIR --setenv=HYPRLAND_INSTANCE_SIGNATURE \
        --setenv=XDG_SESSION_TYPE --setenv=PATH \
        -p "ExecStopPost=$dir/reset-binds.sh" \
        "$qs" -p "$dir"
    ;;
stop)
    if running; then
        "$qs" -p "$dir" ipc call waitmode stop >/dev/null 2>&1
        sleep 0.5
        running && systemctl --user stop "$unit"
    fi
    "$dir/reset-binds.sh"
    ;;
status)
    if running; then
        "$qs" -p "$dir" ipc call waitmode status
    else
        echo "off"
    fi
    ;;
bypass)
    running || { echo "Wait Mode is off" >&2; exit 1; }
    case "$2" in
    on) "$qs" -p "$dir" ipc call waitmode bypass true "${3:-30}" ;;
    off) "$qs" -p "$dir" ipc call waitmode bypass false 0 ;;
    *) echo "usage: $0 bypass on [seconds] | off" >&2; exit 2 ;;
    esac
    ;;
*)
    echo "usage: $0 start | stop | status | bypass on [seconds] | off" >&2
    exit 2
    ;;
esac
