pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The beat of what plays, from cava (the same way hi-shell's visualizers get it). `bass` is
// the low bands, 0..1, and `beat(strength)` fires on each hit: when the bass jumps well above
// its recent average (a kick), at most about five times a second. The cover swells on it. cava
// runs only while the music plays and the cover is up (`playing`) and something counts itself
// in `users`.
Singleton {
    id: root

    readonly property int bands: 24
    property bool playing: false
    property int users: 0
    property real bass: 0

    // strength 0.3..1: how hard the hit was.
    signal beat(real strength)

    // What the bass has been like lately, and when it last hit.
    property real average: 0
    property real previous: 0
    property real lastBeat: 0

    property real last: 0

    Process {
        running: root.users > 0 && root.playing
        // Config from a file (removed once read).
        command: ["sh", "-c", 'cfg=$(mktemp); printf "%b" "$1" > "$cfg"; (sleep 2; rm -f "$cfg") & exec cava -p "$cfg"', "sh",
            `[general]\nbars = ${root.bands}\nframerate = 60\n[input]\nmethod = pipewire\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\nbar_delimiter = 59\n[smoothing]\nmonstercat = 1\nnoise_reduction = 20\n`]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";");
                if (parts.length < 3)
                    return;
                const now = Date.now();
                const dt = root.last ? Math.min(0.1, (now - root.last) / 1000) : 1 / 60;
                root.last = now;
                // The lowest three bands: the kick and the bass line.
                const bass = (parts[0] / 100 + parts[1] / 100 + parts[2] / 100) / 3;
                root.bass = bass;
                // The average follows the bass over about half a second; a hit is a rise well
                // above it (and above a small floor, so quiet noise doesn't count).
                root.average += (bass - root.average) * Math.min(1, dt * 4);
                if (bass - root.average > 0.09 && bass > root.previous && now - root.lastBeat > 300) {
                    root.lastBeat = now;
                    root.beat(Math.max(0.4, Math.min(1, (bass - root.average) * 4)));
                }
                root.previous = bass;
            }
        }
        onRunningChanged: {
            if (!running) {
                root.bass = root.average = root.previous = 0;
                root.last = 0;
            }
        }
    }
}
