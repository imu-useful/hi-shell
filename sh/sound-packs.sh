#!/bin/sh
# Downloads an event sound pack for the shell: `sound-packs.sh miui`, `samsung` or `iphone`.
# MIUI: p0358/magisk-miui-sounds; Samsung One UI: Magisk-Modules-Repo/OneUISounds;
# iPhone: antoniomalheirs/Sound_And_Emoji_IOS.
# The sounds belong to Xiaomi, Samsung and Apple and have no licence, so they are fetched to the user's
# folder on request (Settings > Sounds) and are not part of this repository. Each pack lands in
# <data>/hi-shell/sounds/<pack>/<event>.ogg (events: services/Sounds.qml); remove the folder to drop a pack.
set -e
pack="$1"
dest="${XDG_DATA_HOME:-$HOME/.local/share}/hi-shell/sounds/$pack"
case "$pack" in
    miui) base="https://raw.githubusercontent.com/p0358/magisk-miui-sounds/master/system/media/audio"
          list="notification=notifications/Fresh urgent=notifications/Reminder timer=notifications/Timer phase=notifications/SMSComplete
                batteryLow=ui/LowBattery batteryCritical=ui/LowBattery plugged=ui/Unlock unplugged=ui/Lock screenshot=ui/camera_click" ;;
    samsung) base="https://raw.githubusercontent.com/Magisk-Modules-Repo/OneUISounds/master/system/media/audio"
          list="notification=notifications/Aurora urgent=notifications/Beep_Once timer=ringtones/Atomic_Bell phase=notifications/Glitter
                batteryLow=ui/LowBattery batteryCritical=ui/TW_Battery_caution plugged=ui/ChargingStarted unplugged=ui/Lock screenshot=ui/Screen_Capture" ;;
    iphone) base="https://raw.githubusercontent.com/antoniomalheirs/Sound_And_Emoji_IOS/main/system/product/media/audio"
          list="notification=notifications/IOSDefaultMessageNotification urgent=notifications/IOSReminderAlert timer=alarms/IOSDefaultAlarm phase=notifications/IOSCalendarAlert
                batteryLow=ui/LowBattery batteryCritical=ui/LowBattery plugged=ui/ChargingStarted unplugged=ui/ChargingStopped screenshot=ui/screenshot" ;;
    *) echo "usage: $0 miui|samsung|iphone" >&2; exit 2 ;;
esac
tmp="$dest.part"
rm -rf "$tmp"; mkdir -p "$tmp"
for item in $list; do
    curl -fsSL "$base/${item#*=}.ogg" -o "$tmp/${item%%=*}.ogg"
done
rm -rf "$dest"; mv "$tmp" "$dest"
