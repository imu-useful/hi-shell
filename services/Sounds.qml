pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Event sounds of the shell, played through PipeWire (pw-play). Everything that makes a sound asks
// for it by event here, so one switch, one pack and one volume (Settings > Sounds) rule them all.
// Packs: "freedesktop" (the system theme, always there), the ones shipped in the repository's sounds/
// folder, and any folder of files named like the events (ogg, wav, flac, mp3) in
// ~/.local/share/hi-shell/sounds/<pack>/ (that one wins over a shipped pack of the same name;
// sh/sound-packs.sh fetches a pack there again).
// A pack without a file for an event falls back to the system theme; no pw-play: silence.
Singleton {
    id: root

    readonly property var options: Config.options.sounds
    readonly property string dir: "/usr/share/sounds/freedesktop/stereo/"
    readonly property string userDir: `${Paths.home}/.local/share/hi-shell/sounds/`
    readonly property string bundledDir: `${Quickshell.shellDir}/sounds/`

    // event -> [the file in the system theme, the option that switches it, a title for Settings]
    readonly property var events: ({
        notification: ["message-new-instant", "notifications", "Notification"],
        urgent: ["dialog-warning", "notifications", "Urgent notification"],
        timer: ["alarm-clock-elapsed", "timers", "Timer finished"],
        phase: ["complete", "timers", "Focus or break begins"],
        batteryLow: ["dialog-warning", "battery", "Battery low"],
        batteryCritical: ["dialog-error", "battery", "Battery critical"],
        plugged: ["power-plug", "battery", "Charger plugged in"],
        unplugged: ["power-unplug", "battery", "Charger unplugged"],
        screenshot: ["screen-capture", "capture", "Screenshot"],
        volume: ["audio-volume-change", "volumeTick", "Volume change"]
    })
    // Packs shipped with the shell (besides the system theme).
    readonly property var downloadable: ["miui", "samsung", "iphone", "windows", "win7", "winxp", "android"]
    // Packs found in the sounds folders (the shipped ones and the user's).
    property list<string> installed: []
    property string installing: ""
    property bool failed: false

    // The volume tick comes at most this often, so dragging a slider doesn't machine-gun it.
    readonly property int tickGap: 120
    property real lastTick: 0

    function play(event, force) {
        const e = events[event];
        if (!e || !options.enabled || (!force && !options[e[1]]))
            return;
        if (event === "volume") {
            const now = Date.now();
            if (now - lastTick < tickGap)
                return;
            lastTick = now;
        }
        // The pack's file (the user's folder, then the shipped one) in any format pw-play reads, else the system theme's.
        Quickshell.execDetached(["sh", "-c", 'for f in "$1".* "$2".* "$3"; do [ -f "$f" ] && exec pw-play --volume "$4" "$f"; done',
            "sh", `${userDir}${options.pack}/${event}`, `${bundledDir}${options.pack}/${event}`, `${dir}${e[0]}.oga`, String(options.volume)]);
    }

    function install(pack) {
        if (installing !== "")
            return;
        failed = false;
        installing = pack;
        installer.command = ["sh", `${Quickshell.shellDir}/sh/sound-packs.sh`, pack];
        installer.running = true;
    }

    function refresh() {
        lister.running = true;
    }

    Process {
        id: lister
        command: ["sh", "-c", 'for d in "$1"*/ "$2"*/; do [ -d "$d" ] && basename "$d"; done | sort -u', "sh", root.bundledDir, root.userDir]
        stdout: StdioCollector {
            onStreamFinished: root.installed = text.split("\n").filter(l => l)
        }
    }

    Process {
        id: installer
        onExited: code => {
            const pack = root.installing;
            root.installing = "";
            root.failed = code !== 0;
            root.refresh();
            if (code === 0) {
                root.options.pack = pack;
                root.play("notification", true);
            }
        }
    }

    Component.onCompleted: refresh()
}
