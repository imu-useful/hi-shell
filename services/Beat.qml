pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Music energy from cava for things that move to the beat (the wallpaper frame).
// Runs only while something counts itself in `users`. `bass` and `level` are 0..1;
// `frame(dt)` fires for every cava frame (dt in seconds).
Singleton {
    id: root

    property int users: 0
    property real bass: 0
    property real level: 0
    signal frame(real dt)

    property real last: 0

    Process {
        running: root.users > 0 && Appearance.anim.speed > 0
        // Config from a file (removed once read); 8 bands, bass first.
        command: ["sh", "-c", 'cfg=$(mktemp); printf "%b" "$1" > "$cfg"; (sleep 2; rm -f "$cfg") & exec cava -p "$cfg"', "sh",
            "[general]\nbars = 8\nframerate = 30\n[input]\nmethod = pipewire\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\nbar_delimiter = 59\n[smoothing]\nnoise_reduction = 60\n"]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";").filter(s => s !== "").map(s => Number(s) / 100);
                if (v.length < 8)
                    return;
                root.bass = (v[0] + v[1]) / 2;
                root.level = v.reduce((a, b) => a + b, 0) / v.length;
                const now = Date.now();
                const dt = root.last ? Math.min(0.1, (now - root.last) / 1000) : 1 / 30;
                root.last = now;
                root.frame(dt);
            }
        }
        onRunningChanged: {
            if (!running) {
                root.bass = root.level = 0;
                root.last = 0;
            }
        }
    }
}
