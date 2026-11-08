#!/bin/sh
# Downloads an event sound pack for the shell: `sound-packs.sh miui`, `samsung`, `iphone`, `windows` (11), `win7`, `winxp` or `android`.
# MIUI: p0358/magisk-miui-sounds; Samsung One UI: Magisk-Modules-Repo/OneUISounds;
# iPhone: antoniomalheirs/Sound_And_Emoji_IOS; Windows 11: MCPlayer2015/all-windows-sounds (Windows 11, 7 and XP);
# Android: AOSP (aosp-mirror/platform_frameworks_base, Apache-2.0).
# The packs are kept in the repository's sounds/ folder (see sounds/NOTICE.md); this script is how they
# were fetched (events with no file in a pack take the file of a related one, see services/Sounds.qml), and fetches a pack again into ~/.local/share/hi-shell/sounds/<pack>/<event>.<ext>
# (events: services/Sounds.qml) or, with SOUNDS_DIR=<dir> set, into <dir>/<pack>/.
set -e
pack="$1"
dest="${SOUNDS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/hi-shell/sounds}/$pack"
case "$pack" in
    miui) base="https://raw.githubusercontent.com/p0358/magisk-miui-sounds/master/system/media/audio"
          list="notification=notifications/Fresh.ogg urgent=notifications/Reminder.ogg timer=notifications/Timer.ogg phase=notifications/SMSComplete.ogg
                batteryLow=ui/LowBattery.ogg batteryCritical=ui/LowBattery.ogg plugged=ui/Unlock.ogg unplugged=ui/Lock.ogg screenshot=ui/camera_click.ogg volume=ui/Effect_Tick.ogg
                startup=ui/Unlock.ogg lock=ui/Lock.ogg shutdown=ui/SystemTurnOff.ogg" ;;
    samsung) base="https://raw.githubusercontent.com/Magisk-Modules-Repo/OneUISounds/master/system/media/audio"
          list="notification=notifications/Aurora.ogg urgent=notifications/Beep_Once.ogg timer=ringtones/Atomic_Bell.ogg phase=notifications/Glitter.ogg
                batteryLow=ui/LowBattery.ogg batteryCritical=ui/TW_Battery_caution.ogg plugged=ui/ChargingStarted.ogg unplugged=ui/Lock.ogg screenshot=ui/Screen_Capture.ogg volume=ui/TW_Volume_control.ogg
                startup=ui/Unlock_VA_Mode.ogg lock=ui/Lock.ogg shutdown=ui/TW_Call_Disconnect.ogg" ;;
    iphone) base="https://raw.githubusercontent.com/antoniomalheirs/Sound_And_Emoji_IOS/main/system/product/media/audio"
          list="notification=notifications/IOSDefaultMessageNotification.ogg urgent=notifications/IOSReminderAlert.ogg timer=alarms/IOSDefaultAlarm.ogg phase=notifications/IOSCalendarAlert.ogg
                batteryLow=ui/LowBattery.ogg batteryCritical=ui/LowBattery.ogg plugged=ui/ChargingStarted.ogg unplugged=ui/ChargingStopped.ogg screenshot=ui/screenshot.ogg volume=ui/VolumeIncremental.ogg
                startup=ui/Unlock.ogg lock=ui/Lock.ogg" ;;
    windows) base="https://raw.githubusercontent.com/MCPlayer2015/all-windows-sounds/main/(2021)%20Windows%2011"
          list="notification=Windows%20Notify%20System%20Generic.wav urgent=Windows%20Exclamation.wav timer=Alarm01.wav phase=Windows%20Notify%20Calendar.wav
                batteryLow=Windows%20Battery%20Low.wav batteryCritical=Windows%20Battery%20Critical.wav plugged=Windows%20Hardware%20Insert.wav
                unplugged=Windows%20Hardware%20Remove.wav screenshot=Windows%20Ding.wav volume=Windows%20Menu%20Command.wav
                startup=Windows%20Startup.wav lock=Windows%20Logoff%20Sound.wav shutdown=Windows%20Shutdown.wav" ;;
    winxp) base="https://raw.githubusercontent.com/MCPlayer2015/all-windows-sounds/main/(2001)%20Windows%20XP"
          list="notification=Windows%20XP%20Notify.wav urgent=Windows%20XP%20Exclamation.wav timer=Windows%20XP%20Ringin.wav phase=Windows%20XP%20Ding.wav
                batteryLow=Windows%20XP%20Battery%20Low.wav batteryCritical=Windows%20XP%20Battery%20Critical.wav plugged=Windows%20XP%20Hardware%20Insert.wav
                unplugged=Windows%20XP%20Hardware%20Remove.wav screenshot=Windows%20XP%20Minimize.wav volume=Windows%20XP%20Menu%20Command.wav
                startup=Windows%20XP%20Startup.wav lock=Windows%20XP%20Logoff%20Sound.wav shutdown=Windows%20XP%20Shutdown.wav" ;;
    win7) base="https://raw.githubusercontent.com/MCPlayer2015/all-windows-sounds/main/(2009)%20Windows%207"
          list="notification=Windows%20Notify.wav urgent=Windows%20Exclamation.wav timer=Windows%20Ringin.wav phase=Windows%20Ding.wav
                batteryLow=Windows%20Battery%20Low.wav batteryCritical=Windows%20Battery%20Critical.wav plugged=Windows%20Hardware%20Insert.wav
                unplugged=Windows%20Hardware%20Remove.wav screenshot=Windows%20Restore.wav volume=Windows%20Menu%20Command.wav
                startup=Windows%20Startup.wav lock=Windows%20Logoff%20Sound.wav shutdown=Windows%20Shutdown.wav" ;;
    android) base="https://raw.githubusercontent.com/aosp-mirror/platform_frameworks_base/master/data/sounds"
          list="notification=notifications/pixiedust.ogg urgent=notifications/ShortCircuit.ogg timer=Alarm_Beep_01.ogg phase=notifications/TaDa.ogg
                batteryLow=effects/LowBattery.ogg batteryCritical=effects/LowBattery.ogg plugged=effects/ChargingStarted.ogg
                unplugged=effects/Undock.ogg screenshot=effects/camera_click.ogg volume=effects/Effect_Tick.ogg
                startup=effects/Unlock.ogg lock=effects/Lock.ogg" ;;
    *) echo "usage: $0 miui|samsung|iphone|windows|win7|winxp|android" >&2; exit 2 ;;
esac
tmp="$dest.part"
rm -rf "$tmp"; mkdir -p "$tmp"
for item in $list; do
    file="${item#*=}"
    curl -fsSL "$base/$file" -o "$tmp/${item%%=*}.${file##*.}"
done
rm -rf "$dest"; mv "$tmp" "$dest"
