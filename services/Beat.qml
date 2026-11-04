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
    // The tempo clock: finds the tempo of the music and ticks on the beat. The bass's onset strength (how fast
    // it rises, per frame) of the last 15 s is autocorrelated for the period (70..180 BPM, a tempo near 110
    // preferred when it is a toss-up between double and half); the beat's place in it is where most of the strength
    // lands. `locked` once four estimates in a row agree (about 10 s into a track); then `tick` comes on every
    // beat, `lead` ms early, for whatever it moves to get there on time. A new track starts the search again.
    property real period: 0 // ms, 0 = not known yet
    property real offset: 0 // ms: the beats fall at offset + n * period (since the epoch)
    readonly property real bpm: period > 0 ? 60000 / period : 0
    property bool locked: false
    readonly property int lead: 70
    // Beats between the changes of things that move to the beat: not faster than every 600 ms.
    readonly property int stride: period > 0 ? Math.max(1, Math.ceil(600 / period)) : 1
    // `count`: the beats ticked since the clock locked (0, 1, 2, ...).
    signal tick(int count)

    readonly property int fluxFrames: 450
    property var flux: []
    property var fluxTimes: []
    property var recent: []
    property real lastN: 0 // the number of the last beat since the epoch (too big for an int)
    property int counted: 0
    property int disagreeing: 0

    function resetClock() {
        flux = [];
        fluxTimes = [];
        bufferTrack = Mpris.title;
        recent = [];
        period = 0;
        locked = false;
        disagreeing = 0;
        grid.stop();
        counted = 0;
    }

    // Autocorrelation of `x` at a lag in frames.
    function autocorr(x, n, lag) {
        let sum = 0;
        for (let i = 0; i < n - lag; i++)
            sum += x[i] * x[i + lag];
        return sum / (n - lag);
    }

    // The period (ms) of the last frames, or 0 when there is nothing to tell (silence).
    function tempo() {
        const x = flux, n = x.length;
        const dt = (fluxTimes[n - 1] - fluxTimes[0]) / (n - 1);
        let energy = 0;
        for (let i = 0; i < n; i++)
            energy += x[i] * x[i];
        if (energy < 0.01)
            return 0;
        let best = 0, bestLag = 0;
        for (let lag = Math.floor(333 / dt); lag <= Math.ceil(857 / dt); lag++) {
            const preference = Math.exp(-0.5 * Math.pow(Math.log2(lag * dt / 545) / 0.9, 2));
            const score = (autocorr(x, n, lag) + 0.5 * autocorr(x, n, 2 * lag) + 0.25 * autocorr(x, n, 3 * lag)) * preference;
            if (score > best) {
                best = score;
                bestLag = lag;
            }
        }
        if (bestLag === 0)
            return 0;
        // A parabola through the peak and its neighbours: finer than one frame.
        const a = autocorr(x, n, bestLag - 1), b = autocorr(x, n, bestLag), c = autocorr(x, n, bestLag + 1);
        const den = a - 2 * b + c;
        const shift = den !== 0 ? 0.5 * (a - c) / den : 0;
        return (bestLag + (Math.abs(shift) < 1 ? shift : 0)) * dt;
    }

    // Where the beats fall: the offset (within one period) at which the most onset strength lands on the grid.
    function phase(p) {
        const sigma = p * 0.06;
        const n = flux.length;
        let best = 0, bestScore = -1;
        for (let ph = 0; ph < p; ph += 10) {
            let score = 0;
            for (let i = 0; i < n; i++) {
                if (flux[i] === 0)
                    continue;
                let d = ((fluxTimes[i] - ph) % p + p) % p;
                if (d > p / 2)
                    d -= p;
                score += flux[i] * Math.exp(-(d * d) / (2 * sigma * sigma));
            }
            if (score > bestScore) {
                bestScore = score;
                best = ph;
            }
        }
        return best;
    }

    // Once a second: a new estimate; lock when four agree, follow slow drifts, start over when ten in a row disagree (a new tempo).
    function analyse() {
        if (flux.length < 240)
            return;
        const p = tempo();
        if (p <= 0)
            return;
        if (!locked) {
            recent = [...recent.slice(-3), p];
            if (recent.length === 4 && Math.max(...recent) / Math.min(...recent) < 1.05) {
                period = recent.reduce((acc, v) => acc + v, 0) / 4;
                locked = true;
            } else {
                return;
            }
        } else if (Math.abs(p - period) < period * 0.06) {
            period = period * 0.8 + p * 0.2;
            disagreeing = 0;
        } else if (Math.abs(p / period - 2) < 0.1 || Math.abs(p / period - 0.5) < 0.05) {
            // Double or half of the tempo it has: the same music, counted another way; keep ours.
            disagreeing = 0;
        } else if (++disagreeing >= 10) {
            resetClock();
            return;
        }
        // The phase moves a quarter of the way to the new one: single estimates jump about.
        const target = phase(period);
        let d = ((target - offset) % period + period) % period;
        if (d > period / 2)
            d -= period;
        offset = locked && offset !== 0 ? ((offset + d * 0.25) % period + period) % period : target;
        schedule();
    }

    // Arm the timer for the next tick (the beat's time minus `lead`).
    function schedule() {
        if (!locked || period <= 0)
            return;
        const now = Date.now();
        const n = Math.max(lastN + 1, Math.ceil((now + lead - offset) / period));
        grid.pendingN = n;
        grid.interval = Math.max(1, offset + n * period - lead - now);
        grid.restart();
    }

    Timer {
        id: grid
        property real pendingN: 0
        onTriggered: {
            root.lastN = pendingN;
            root.tick(root.counted++);
            root.schedule();
        }
    }
    Timer {
        interval: 1000
        running: root.users > 0
        repeat: true
        onTriggered: root.analyse()
    }

    // A new track, a new tempo. The title flickers while a track loads, so it has to hold for a moment.
    property string bufferTrack: ""
    Connections {
        target: Mpris
        function onTitleChanged() { newTrack.restart(); }
    }
    Timer {
        id: newTrack
        interval: 1200
        onTriggered: {
            if (Mpris.title !== root.bufferTrack) {
                root.resetClock();
                root.bufferTrack = Mpris.title;
            }
        }
    }

    property real prevBass: 0

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
                // Onset strength for the tempo clock: how much the bass rose since the last frame.
                const rise = Math.max(0, root.bass - root.prevBass);
                const f = root.flux.length >= root.fluxFrames ? root.flux.slice(1) : root.flux.slice();
                const ft = root.fluxTimes.length >= root.fluxFrames ? root.fluxTimes.slice(1) : root.fluxTimes.slice();
                f.push(rise);
                ft.push(now);
                root.flux = f;
                root.fluxTimes = ft;
                root.prevBass = root.bass;
                root.frame(dt);
            }
        }
        onRunningChanged: {
            if (!running) {
                root.levels = [];
                root.bass = root.level = 0;
                root.last = 0;
                root.prevBass = 0;
                root.resetClock();
            }
        }
    }
}
