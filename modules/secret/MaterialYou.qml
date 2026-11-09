import QtQuick
import qs.common
import qs.common.widgets
import "../../common/shapes/Shapes.js" as Shapes

// Keys "material", "material you", "m3", "expressive": a silent show of Material 3 Expressive.
// Four scenes flow into one another (shapes morphing on a spring, orbiting, rippling, blooming)
// while the palette re-derives itself from a drifting seed color, the way it does when the
// wallpaper changes. The outlines are the shell's own (Shapes.js); everything is drawn on one canvas.
Canvas {
    id: root

    required property bool revealed
    property real time: 0
    // Painted on the GPU and off the GUI thread: the default (a CPU image) can't keep up at 1080p
    renderTarget: Canvas.FramebufferObject
    renderStrategy: Canvas.Threaded
    property real sinceFrame: 0
    readonly property real minFrame: 0.0155 // cap at about 60 fps, whatever the display rate

    readonly property real sceneLength: 7
    readonly property real overlap: 0.6
    readonly property var captions: [Translation.tr("Material You"), Translation.tr("Dynamic color"), Translation.tr("Expressive shapes"), Translation.tr("Made for you")]
    readonly property var names: ["circle", "cookie6", "clover4", "sunny", "flower", "star", "burst", "softBurst", "puffy", "pill", "diamond", "hexagon", "cookie12", "clover8", "boom", "blob", "square", "triangle", "verySunny", "cookie9"]
    // lods[level][shape]: level 0 = all 144 outline points (big shapes), 1 = every 2nd, 2 = every 4th
    property var lods: []
    property real baseHue: 0.6
    readonly property real cycle: sceneLength * 4
    readonly property int sceneIndex: Math.floor((time % cycle) / sceneLength)
    readonly property real sceneTime: (time % cycle) - sceneIndex * sceneLength
    readonly property string caption: captions[sceneIndex]

    Component.onCompleted: {
        const flat = (name, stride) => {
            const p = Shapes.points(name, 0), out = [];
            for (let i = 0; i < p.length; i += stride)
                out.push(p[i][0], p[i][1]);
            return out;
        };
        lods = [1, 2, 4].map(st => names.map(n => flat(n, st)));
        const h = Colors.m3primary.hslHue;
        baseHue = h >= 0 ? h : 0.6;
    }

    FrameAnimation {
        running: root.revealed
        onTriggered: {
            root.time += frameTime;
            root.sinceFrame += frameTime;
            if (root.sinceFrame >= root.minFrame) {
                root.sinceFrame = 0;
                root.requestPaint();
            }
        }
    }

    // ---- helpers ----------------------------------------------------------------------------

    function clamp(x) {
        return Math.max(0, Math.min(1, x));
    }

    // A spring: 0 -> 1 with an overshoot, like the shell's own morph curve
    function spring(p) {
        const x = clamp(p);
        return 1 - Math.exp(-7 * x) * Math.cos(13 * x);
    }

    function hue() {
        return baseHue + time * 0.03;
    }

    // Six tonal roles derived from the seed: primary, secondary, tertiary and their containers
    function tone(i, alpha) {
        const h = hue();
        const roles = [[0, 0.9, 0.62], [0.11, 0.6, 0.72], [0.28, 0.75, 0.68], [0, 0.5, 0.3], [0.28, 0.5, 0.32], [0.11, 0.45, 0.86]];
        const r = roles[((i % 6) + 6) % 6];
        return `hsla(${Math.round((((h + r[0]) % 1) + 1) % 1 * 360)}, ${Math.round(r[1] * 100)}%, ${Math.round(r[2] * 100)}%, ${alpha ?? 1})`;
    }

    function lod(r) {
        return r > 90 ? 0 : r > 28 ? 1 : 2;
    }

    function shape(ctx, a, b, mix, cx, cy, r, rot, color) {
        const cs = Math.cos(rot) * r, sn = Math.sin(rot) * r;
        const n = a.length;
        ctx.beginPath();
        for (let i = 0; i < n; i += 2) {
            let x = a[i], y = a[i + 1];
            if (mix !== 0) {
                x += (b[i] - x) * mix;
                y += (b[i + 1] - y) * mix;
            }
            const px = cx + x * cs - y * sn, py = cy + x * sn + y * cs;
            if (i === 0)
                ctx.moveTo(px, py);
            else
                ctx.lineTo(px, py);
        }
        ctx.closePath();
        ctx.fillStyle = color;
        ctx.fill();
    }

    // Morph through the shape list: `p` counts shapes passed; the change itself takes the first
    // 45% of each step (a spring), the rest is a rest.
    function morph(ctx, p, cx, cy, r, rot, color) {
        const n = names.length, set = lods[lod(r)];
        const i = Math.floor(p), f = p - i;
        shape(ctx, set[((i % n) + n) % n], set[(((i + 1) % n) + n) % n], spring(f / 0.45), cx, cy, r, rot, color);
    }

    // ---- backdrop ----------------------------------------------------------------------------

    function backdrop(ctx, w, h) {
        const hh = Math.round((hue() % 1) * 360);
        ctx.globalCompositeOperation = "source-over";
        ctx.fillStyle = `hsl(${hh}, 38%, 7%)`;
        ctx.fillRect(0, 0, w, h);
        // Slow colored light drifting behind everything
        for (let k = 0; k < 3; k++) {
            const x = w * (0.5 + 0.38 * Math.sin(time * 0.21 + k * 2.1));
            const y = h * (0.5 + 0.34 * Math.cos(time * 0.17 + k * 1.7));
            const r = Math.max(w, h) * (0.45 + 0.08 * Math.sin(time * 0.5 + k));
            const g = ctx.createRadialGradient(x, y, 0, x, y, r);
            g.addColorStop(0, tone(k === 1 ? 2 : k === 2 ? 1 : 0, 0.22));
            g.addColorStop(1, "rgba(0, 0, 0, 0)");
            ctx.fillStyle = g;
            ctx.fillRect(0, 0, w, h);
        }
        // Tiny shapes drifting upward, far behind
        const u = Math.min(w, h);
        for (let k = 0; k < 20; k++) {
            const seed = k * 12.9898;
            const sx = (Math.sin(seed) * 43758.5453) % 1;
            const sy = (Math.sin(seed * 1.7) * 24634.6345) % 1;
            const size = u * (0.008 + Math.abs(sx * 2 % 1) * 0.02);
            const x = (Math.abs(sx) * w + Math.sin(time * 0.4 + k) * 30) % w;
            const y = h - ((Math.abs(sy) * h + time * (14 + k % 9 * 5)) % (h + 80)) + 40;
            const a = lods[2][k % names.length];
            shape(ctx, a, a, 0, x, y, size, time * 0.3 + k, tone(k, 0.16));
        }
        // Ripples leaving the middle
        for (let k = 0; k < 3; k++) {
            const age = ((time + k * 0.8) % 2.4) / 2.4;
            ctx.beginPath();
            ctx.arc(w / 2, h / 2, age * Math.max(w, h) * 0.55, 0, Math.PI * 2);
            ctx.strokeStyle = tone(k, 0.35 * (1 - age));
            ctx.lineWidth = 2 + 6 * (1 - age);
            ctx.stroke();
        }
    }

    // ---- scenes ------------------------------------------------------------------------------
    // `tl` is the time in the scene (negative while it is still arriving); `e` the arrival spring.

    function hero(ctx, w, h, tl, u) {
        const glow = ctx.createRadialGradient(w / 2, h / 2, u * 0.1, w / 2, h / 2, u * 0.5);
        glow.addColorStop(0, tone(0, 0.35));
        glow.addColorStop(1, "rgba(0, 0, 0, 0)");
        ctx.fillStyle = glow;
        ctx.fillRect(w / 2 - u * 0.5, h / 2 - u * 0.5, u, u);
        const rs = [0.3, 0.21, 0.12];
        for (let k = 0; k < 3; k++) {
            const breathe = 1 + 0.04 * Math.sin(time * 4 + k);
            morph(ctx, tl * 1.25 + k * 3.3, w / 2, h / 2, u * rs[k] * breathe, time * (k % 2 ? -0.7 : 0.5) + k, tone([0, 4, 2][k]));
        }
    }

    function orbit(ctx, w, h, tl, u) {
        const cx = w / 2, cy = h / 2;
        const rings = [[8, 0.25, 0.075, 1], [14, 0.4, 0.052, -1]];
        for (const [count, radius, size, dir] of rings) {
            for (let k = 0; k < count; k++) {
                const ang = k / count * Math.PI * 2 + time * 0.45 * dir;
                const pulse = 1 + 0.35 * Math.sin(time * 3 - k * 0.7);
                morph(ctx, k * 0.7 + time * 0.7 * dir, cx + Math.cos(ang) * radius * u, cy + Math.sin(ang) * radius * u, u * size * pulse, time * dir + k, tone(k + (dir > 0 ? 0 : 3)));
            }
        }
        morph(ctx, tl * 1.2 + 4, cx, cy, u * (0.13 + 0.015 * Math.sin(time * 5)), -time * 0.8, tone(5));
    }

    function grid(ctx, w, h, tl, u) {
        const cols = 11, rows = 6, cell = u * 0.138;
        for (let r = 0; r < rows; r++) {
            for (let c = 0; c < cols; c++) {
                const dx = c - (cols - 1) / 2, dy = r - (rows - 1) / 2;
                const dist = Math.sqrt(dx * dx + dy * dy);
                const phase = dist * 0.5 - tl * 1.1;
                const size = cell * 0.5 * (0.5 + 0.5 * (0.55 + 0.45 * Math.sin(phase * 2.1)));
                const n = names.length, set = lods[lod(size * 1.7)];
                const i = Math.floor(phase), f = phase - i;
                shape(ctx, set[((i % n) + n) % n], set[(((i + 1) % n) + n) % n], spring(f), w / 2 + dx * cell, h / 2 + dy * cell, size * 1.7, phase * 0.6, tone(Math.floor(dist * 0.7 - tl)));
            }
        }
    }

    function bloom(ctx, w, h, tl, u) {
        const count = 72, golden = 2.39996323;
        for (let k = 0; k < count; k++) {
            const grow = spring((tl - k * 0.015) / 0.9);
            if (grow <= 0)
                continue;
            const t = k / count;
            const ang = k * golden + time * 0.15;
            const rad = Math.sqrt(t) * u * 0.5 * (1 + 0.04 * Math.sin(time * 2 - k * 0.1));
            const size = u * (0.012 + 0.05 * Math.sqrt(t)) * grow;
            morph(ctx, k / 7 + time * 0.5, w / 2 + Math.cos(ang) * rad, h / 2 + Math.sin(ang) * rad, size, ang + time * 0.4, tone(k));
        }
    }

    function scene(i, ctx, w, h, tl, u) {
        ctx.save();
        const arrive = spring((tl + overlap) / 1.2);
        const leave = clamp((sceneLength - tl) / overlap);
        const s = (0.55 + 0.45 * arrive) * (0.9 + 0.1 * leave);
        ctx.globalAlpha = clamp((tl + overlap) / 0.6) * leave;
        ctx.translate(w / 2, h / 2);
        ctx.scale(s, s);
        ctx.translate(-w / 2, -h / 2);
        [hero, orbit, grid, bloom][i % 4](ctx, w, h, tl, u);
        ctx.restore();
    }

    onPaint: {
        const ctx = getContext("2d");
        const w = width, h = height, u = Math.min(w, h);
        if (lods.length === 0)
            return;
        backdrop(ctx, w, h);
        const cycle = sceneLength * 4;
        const s = time % cycle;
        const i = Math.floor(s / sceneLength), tl = s - i * sceneLength;
        scene(i, ctx, w, h, tl, u);
        if (tl > sceneLength - overlap)
            scene(i + 1, ctx, w, h, tl - sceneLength, u);
    }

    LetterCaption {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.height * 0.07
        text: root.caption
        time: root.time
        sceneTime: root.sceneTime
        sceneLength: root.sceneLength
        hue: root.hue()
        fontSize: Math.min(88, root.height / 12)
    }
}
