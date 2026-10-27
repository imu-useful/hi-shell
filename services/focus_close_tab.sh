#!/bin/sh
# Closes the current tab of the window $1 (Ctrl+W), for Focus Mode's blocked sites
# (services/FocusBlocker.qml). Hyprland's send_shortcut doesn't reach Firefox, so the
# window is focused for a moment and the keys go in with wtype; focus goes back to the
# window that had it. Nothing else is touched.
# Without a window there is nothing to close; never send the keys to whatever is focused.
[ -n "$1" ] || exit 1
prev=$(hyprctl activewindow -j | tr -d '\n' | sed -E 's/^.*"address": *"([^"]*)".*$/\1/')
focus() {
    hyprctl eval "hl.dispatch(hl.dsp.focus({ window = \"address:$1\" }))" >/dev/null
}
focus "$1"
sleep 0.2
wtype -M ctrl w -m ctrl
sleep 0.2
[ -n "$prev" ] && [ "$prev" != "$1" ] && focus "$prev"
exit 0
