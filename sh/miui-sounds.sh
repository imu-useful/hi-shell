#!/bin/sh
# Downloads a few MIUI system sounds (p0358/magisk-miui-sounds) for the shell's event sounds.
# The sounds belong to Xiaomi and have no licence, so they are fetched to the user's folder
# on request and are not part of this repository. Remove the folder to go back to the default theme.
set -e
dest="${XDG_DATA_HOME:-$HOME/.local/share}/hi-shell/sounds"
base="https://raw.githubusercontent.com/p0358/magisk-miui-sounds/master/system/media/audio"
mkdir -p "$dest"
get() { curl -fsSL "$base/$1" -o "$dest/$2.ogg" && echo "$2"; }
get notifications/Fresh.ogg notification
get notifications/Reminder.ogg urgent
get notifications/Timer.ogg timer
get notifications/SMSComplete.ogg phase
get ui/LowBattery.ogg batteryLow
get ui/LowBattery.ogg batteryCritical
get ui/Unlock.ogg plugged
get ui/Lock.ogg unplugged
get ui/camera_click.ogg screenshot
