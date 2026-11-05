pragma Singleton

import QtQuick
import Quickshell
import qs.common

// Event sounds of the shell, played through PipeWire (pw-play): a file named after the event in
// ~/.local/share/hi-shell/sounds/ (sh/miui-sounds.sh fills it with MIUI sounds; any .ogg named like
// the events below works), else the freedesktop sound theme.
// Everything that makes a sound asks for it by event here, so one switch and one volume
// (Settings > Interface > Sounds) rule them all. Missing sound files or no pw-play: silence.
Singleton {
    id: root

    readonly property var options: Config.options.sounds
    readonly property string dir: "/usr/share/sounds/freedesktop/stereo/"
    readonly property string userDir: `${Paths.home}/.local/share/hi-shell/sounds/`

    // event -> [the file in the theme, the option group that switches it]
    readonly property var events: ({
        notification: ["message-new-instant", "notifications"],
        urgent: ["dialog-warning", "notifications"],
        timer: ["alarm-clock-elapsed", "timers"],
        phase: ["complete", "timers"],
        batteryLow: ["dialog-warning", "battery"],
        batteryCritical: ["dialog-error", "battery"],
        plugged: ["power-plug", "battery"],
        unplugged: ["power-unplug", "battery"],
        screenshot: ["screen-capture", "capture"]
    })

    function play(event) {
        const e = events[event];
        if (!options.enabled || !e || !options[e[1]])
            return;
        Quickshell.execDetached(["sh", "-c", 'f="$1"; [ -f "$f" ] || f="$2"; exec pw-play --volume "$3" "$f"', "sh",
            `${userDir}${event}.ogg`, `${dir}${e[0]}.oga`, String(options.volume)]);
    }
}
