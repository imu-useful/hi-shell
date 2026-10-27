#!/bin/sh
# Back to the normal key binds. Run by systemd whenever Wait Mode's process ends, however it
# ends (Esc x 3, stop, a crash), so a failure can't leave the person without key binds.
hyprctl eval 'hl.dispatch(hl.dsp.submap("reset"))' >/dev/null 2>&1
exit 0
