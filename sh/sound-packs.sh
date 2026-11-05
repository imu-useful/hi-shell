#!/bin/sh
# Downloads an event sound pack for the shell: `sound-packs.sh miui`, `samsung`, `iphone`, `windows` (11) or `winxp`.
# MIUI: p0358/magisk-miui-sounds; Samsung One UI: Magisk-Modules-Repo/OneUISounds;
# iPhone: antoniomalheirs/Sound_And_Emoji_IOS; Windows 11: MCPlayer2015/all-windows-sounds (Windows 11 and XP).
# The sounds belong to Xiaomi, Samsung, Apple and Microsoft and have no licence, so they are fetched to the user's
# folder on request (Settings > Sounds) and are not part of this repository. Each pack lands in
# <data>/hi-shell/sounds/<pack>/<event>.<ext> (events: services/Sounds.qml); remove the folder to drop a pack.
set -e
pack="$1"
dest="${XDG_DATA_HOME:-$HOME/.local/share}/hi-shell/sounds/$pack"
case "$pack" in
    miui) base="https://raw.githubusercontent.com/p0358/magisk-miui-sounds/master/system/media/audio"
          list="notification=notifications/Fresh.ogg urgent=notifications/Reminder.ogg timer=notifications/Timer.ogg phase=notifications/SMSComplete.ogg
                batteryLow=ui/LowBattery.ogg batteryCritical=ui/LowBattery.ogg plugged=ui/Unlock.ogg unplugged=ui/Lock.ogg screenshot=ui/camera_click.ogg" ;;
    samsung) base="https://raw.githubusercontent.com/Magisk-Modules-Repo/OneUISounds/master/system/media/audio"
          list="notification=notifications/Aurora.ogg urgent=notifications/Beep_Once.ogg timer=ringtones/Atomic_Bell.ogg phase=notifications/Glitter.ogg
                batteryLow=ui/LowBattery.ogg batteryCritical=ui/TW_Battery_caution.ogg plugged=ui/ChargingStarted.ogg unplugged=ui/Lock.ogg screenshot=ui/Screen_Capture.ogg" ;;
    iphone) base="https://raw.githubusercontent.com/antoniomalheirs/Sound_And_Emoji_IOS/main/system/product/media/audio"
          list="notification=notifications/IOSDefaultMessageNotification.ogg urgent=notifications/IOSReminderAlert.ogg timer=alarms/IOSDefaultAlarm.ogg phase=notifications/IOSCalendarAlert.ogg
                batteryLow=ui/LowBattery.ogg batteryCritical=ui/LowBattery.ogg plugged=ui/ChargingStarted.ogg unplugged=ui/ChargingStopped.ogg screenshot=ui/screenshot.ogg" ;;
    windows) base="https://raw.githubusercontent.com/MCPlayer2015/all-windows-sounds/main/(2021)%20Windows%2011"
          list="notification=Windows%20Notify%20System%20Generic.wav urgent=Windows%20Exclamation.wav timer=Alarm01.wav phase=Windows%20Notify%20Calendar.wav
                batteryLow=Windows%20Battery%20Low.wav batteryCritical=Windows%20Battery%20Critical.wav plugged=Windows%20Hardware%20Insert.wav
                unplugged=Windows%20Hardware%20Remove.wav screenshot=Windows%20Ding.wav" ;;
    winxp) base="https://raw.githubusercontent.com/MCPlayer2015/all-windows-sounds/main/(2001)%20Windows%20XP"
          list="notification=Windows%20XP%20Notify.wav urgent=Windows%20XP%20Exclamation.wav timer=Windows%20XP%20Ringin.wav phase=Windows%20XP%20Ding.wav
                batteryLow=Windows%20XP%20Battery%20Low.wav batteryCritical=Windows%20XP%20Battery%20Critical.wav plugged=Windows%20XP%20Hardware%20Insert.wav
                unplugged=Windows%20XP%20Hardware%20Remove.wav screenshot=Windows%20XP%20Minimize.wav" ;;
    *) echo "usage: $0 miui|samsung|iphone|windows|winxp" >&2; exit 2 ;;
esac
tmp="$dest.part"
rm -rf "$tmp"; mkdir -p "$tmp"
for item in $list; do
    file="${item#*=}"
    curl -fsSL "$base/$file" -o "$tmp/${item%%=*}.${file##*.}"
done
rm -rf "$dest"; mv "$tmp" "$dest"
