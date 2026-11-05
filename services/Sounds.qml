pragma Singleton

import QtQuick
import Quickshell
import qs.common

// Event sounds of the shell: the freedesktop sound theme played through PipeWire (pw-play).
// Everything that makes a sound asks for it by event here, so one switch and one volume
// (Settings > Interface > Sounds) rule them all. Missing sound files or no pw-play: silence.
Singleton {
    id: root

    readonly property var options: Config.options.sounds
    readonly property string dir: "/usr/share/sounds/freedesktop/stereo/"

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
        Quickshell.execDetached(["pw-play", "--volume", String(options.volume), `${dir}${e[0]}.oga`]);
    }
}
