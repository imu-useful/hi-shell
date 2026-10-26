pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// The one cava for everything that moves to the music: the bar and desktop
// visualizers (Spectrum) and the dancing wallpaper frame. A single process and a
// single parse per frame, and every consumer updates on the same frame. Runs only
// while something counts itself in `users`.
// `levels`: 64 bands, 0..1, bass first; `bass` / `level`: 0..1; frame(dt) per frame.
Singleton {
    id: root

    readonly property int bands: 64
    property int users: 0
    property list<real> levels: []
    property real bass: 0
    property real level: 0
    signal frame(real dt)

    property real last: 0

    Process {
        running: root.users > 0 && Appearance.anim.speed > 0
        // Config from a file (removed once read).
        command: ["sh", "-c", 'cfg=$(mktemp); printf "%b" "$1" > "$cfg"; (sleep 2; rm -f "$cfg") & exec cava -p "$cfg"', "sh",
            `[general]\nbars = ${root.bands}\nframerate = 30\n[input]\nmethod = pipewire\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\nbar_delimiter = 59\n[smoothing]\nmonstercat = 1\nnoise_reduction = 70\n`]
        stdout: SplitParser {
            // 30 times a second: one plain loop, no closures or intermediate arrays.
            onRead: line => {
                const parts = line.split(";");
                if (parts.length < root.bands)
                    return;
                const v = new Array(root.bands);
                let sum = 0;
                for (let i = 0; i < root.bands; i++) {
                    const x = parts[i] / 100;
                    v[i] = x;
                    sum += x;
                }
                root.levels = v;
                root.bass = (v[0] + v[1] + v[2] + v[3]) / 4;
                root.level = sum / root.bands;
                const now = Date.now();
                const dt = root.last ? Math.min(0.1, (now - root.last) / 1000) : 1 / 30;
                root.last = now;
                root.frame(dt);
            }
        }
        onRunningChanged: {
            if (!running) {
                root.levels = [];
                root.bass = root.level = 0;
                root.last = 0;
            }
        }
    }
}
