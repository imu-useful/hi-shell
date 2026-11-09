import QtQuick
import qs.common

// Key "disco": a dark club. A lit dance floor in perspective pulses on the beat, soft spotlights
// sweep through the haze, and a faceted mirror ball throws specks of light over the room.
Canvas {
    id: root

    required property bool revealed
    readonly property real bpm: 120
    // Seconds since the show began; everything below is a function of it
    property real time: 0
    readonly property real beatPos: time * bpm / 60
    readonly property real pulse: Math.exp(-(beatPos % 1) * 3.5)

    readonly property real horizon: 0.56
    readonly property int floorCols: 14
    readonly property int floorRows: 9
    readonly property int latBands: 11
    readonly property int lonFacets: 26

    MusicLoop { file: "disco.ogg"; playing: root.revealed }

    FrameAnimation {
        running: root.revealed
        onTriggered: {
            root.time += frameTime;
            root.requestPaint();
        }
    }

    function hsl(h, s, l, a) {
        return `hsla(${Math.round((((h % 1) + 1) % 1) * 360)}, ${Math.round(s * 100)}%, ${Math.round(l * 100)}%, ${a})`;
    }

    // Cheap deterministic noise for the twinkling facets
    function hash(a, b, c) {
        const x = Math.sin(a * 127.1 + b * 311.7 + c * 74.7) * 43758.5453;
        return x - Math.floor(x);
    }

    function paintBackdrop(ctx, w, h) {
        const g = ctx.createLinearGradient(0, 0, 0, h);
        g.addColorStop(0, "#07000f");
        g.addColorStop(root.horizon, "#1a0830");
        g.addColorStop(1, "#05000a");
        ctx.globalCompositeOperation = "source-over";
        ctx.fillStyle = g;
        ctx.fillRect(0, 0, w, h);
    }

    // Tiles drawn as trapezoids that shrink towards the horizon; each one lights up in a rolling wave
    function paintFloor(ctx, w, h) {
        const top = h * horizon, span = h - top;
        const depth = r => top + span * Math.pow(r / floorRows, 1.7);
        const hue = time * 0.05;
        for (let r = floorRows - 1; r >= 0; r--) {
            const y0 = depth(r), y1 = depth(r + 1);
            const hw0 = w * (0.28 + 0.9 * (y0 - top) / span), hw1 = w * (0.28 + 0.9 * (y1 - top) / span);
            for (let c = 0; c < floorCols; c++) {
                const a0 = c / floorCols, a1 = (c + 1) / floorCols;
                const x00 = w / 2 + (a0 * 2 - 1) * hw0, x01 = w / 2 + (a1 * 2 - 1) * hw0;
                const x10 = w / 2 + (a0 * 2 - 1) * hw1, x11 = w / 2 + (a1 * 2 - 1) * hw1;
                const wave = Math.sin(beatPos * Math.PI + (c * 0.55 + r * 0.8));
                const lit = Math.max(0, wave) * (0.35 + 0.65 * pulse) + ((c + r) % 2 ? 0.08 : 0);
                const gap = 0.012 * (y1 - y0);
                ctx.beginPath();
                ctx.moveTo(x00 + 1.5, y0 + gap);
                ctx.lineTo(x01 - 1.5, y0 + gap);
                ctx.lineTo(x11 - 2.5, y1 - gap);
                ctx.lineTo(x10 + 2.5, y1 - gap);
                ctx.closePath();
                ctx.fillStyle = hsl(hue + c / floorCols * 0.7 + r * 0.02, 0.9, 0.12 + 0.46 * lit, 0.55 + 0.4 * lit);
                ctx.fill();
            }
        }
        // Haze where the floor meets the wall
        const fog = ctx.createLinearGradient(0, top - h * 0.06, 0, top + h * 0.12);
        fog.addColorStop(0, "rgba(120, 60, 200, 0)");
        fog.addColorStop(0.5, hsl(hue + 0.7, 0.8, 0.5, 0.18 + 0.12 * pulse));
        fog.addColorStop(1, "rgba(0, 0, 0, 0)");
        ctx.fillStyle = fog;
        ctx.fillRect(0, top - h * 0.06, w, h * 0.18);
    }

    // A soft cone: bright at the lamp, fading with distance; additive, so crossing beams glow brighter
    function paintBeam(ctx, x, y, angle, length, spread, color, alpha) {
        const tx = x + Math.sin(angle) * length, ty = y + Math.cos(angle) * length;
        const g = ctx.createLinearGradient(x, y, tx, ty);
        g.addColorStop(0, color.replace("ALPHA", alpha));
        g.addColorStop(1, color.replace("ALPHA", 0));
        const nx = Math.cos(angle), ny = -Math.sin(angle);
        ctx.beginPath();
        ctx.moveTo(x - nx * 3, y - ny * 3);
        ctx.lineTo(x + nx * 3, y + ny * 3);
        ctx.lineTo(tx + nx * spread, ty + ny * spread);
        ctx.lineTo(tx - nx * spread, ty - ny * spread);
        ctx.closePath();
        ctx.fillStyle = g;
        ctx.fill();
    }

    function paintBeams(ctx, w, h) {
        ctx.globalCompositeOperation = "lighter";
        const count = 7;
        for (let i = 0; i < count; i++) {
            const fromX = w * (0.08 + i / (count - 1) * 0.84);
            const swing = Math.sin(time * (0.7 + i * 0.13) + i * 1.7) * 0.55;
            const hue = time * 0.06 + i / count;
            const color = hsl(hue, 1, 0.6, "ALPHA");
            paintBeam(ctx, fromX, -10, swing * (fromX < w / 2 ? -1 : 1) * 0.6 + (w / 2 - fromX) / w * 0.5, h * 1.25, h * (0.08 + 0.05 * pulse), color, 0.28 + 0.25 * pulse);
        }
    }

    // The ball: facets on a sphere, lit from the side and flashing as they catch a lamp
    function paintBall(ctx, w, h) {
        const R = Math.min(w, h) * 0.13;
        const cx = w / 2, cy = h * 0.2 + Math.sin(time * 1.4) * 3;
        ctx.globalCompositeOperation = "source-over";
        ctx.strokeStyle = "rgba(200, 200, 220, 0.5)";
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(cx, 0);
        ctx.lineTo(cx, cy - R);
        ctx.stroke();

        // Glow around the ball
        ctx.globalCompositeOperation = "lighter";
        const glow = ctx.createRadialGradient(cx, cy, R * 0.8, cx, cy, R * (2.6 + pulse));
        glow.addColorStop(0, hsl(time * 0.06, 0.9, 0.6, 0.35 + 0.25 * pulse));
        glow.addColorStop(1, "rgba(0, 0, 0, 0)");
        ctx.fillStyle = glow;
        ctx.fillRect(cx - R * 4, cy - R * 4, R * 8, R * 8);

        ctx.globalCompositeOperation = "source-over";
        ctx.save();
        ctx.beginPath();
        ctx.arc(cx, cy, R, 0, Math.PI * 2);
        ctx.clip();
        ctx.fillStyle = "#14101f";
        ctx.fillRect(cx - R, cy - R, R * 2, R * 2);
        const rot = time * 0.6;
        const dLat = Math.PI / latBands, dLon = Math.PI * 2 / lonFacets;
        for (let i = 0; i < latBands; i++) {
            const lat = -Math.PI / 2 + (i + 0.5) * dLat;
            for (let j = 0; j < lonFacets; j++) {
                const lon = j * dLon + rot;
                const facing = Math.cos(lon);
                if (facing <= 0.02)
                    continue;
                const x = cx + R * Math.cos(lat) * Math.sin(lon);
                const y = cy - R * Math.sin(lat);
                const fw = R * dLon * Math.cos(lat) * facing * 0.92, fh = R * dLat * 0.92;
                // Base shade: brighter towards the upper left, darker at the rim
                const shade = 0.22 + 0.4 * facing * (0.6 + 0.4 * Math.cos(lat - 0.5)) + 0.12 * Math.sin(lon + 1.2);
                const spark = hash(i, j, Math.floor(time * 6)) > 0.93 ? 1 : 0;
                const tint = hash(i, j, 3);
                ctx.fillStyle = spark ? "#ffffff" : hsl(0.6 + tint * 0.15, 0.25, Math.min(0.9, shade + 0.15 * tint), 1);
                ctx.fillRect(x - fw / 2, y - fh / 2, Math.max(1, fw), fh);
            }
        }
        ctx.restore();
        // Round off the silhouette with a rim shadow
        const rim = ctx.createRadialGradient(cx, cy, R * 0.6, cx, cy, R * 1.02);
        rim.addColorStop(0, "rgba(0, 0, 0, 0)");
        rim.addColorStop(1, "rgba(5, 0, 15, 0.75)");
        ctx.fillStyle = rim;
        ctx.beginPath();
        ctx.arc(cx, cy, R, 0, Math.PI * 2);
        ctx.fill();

        paintSpecks(ctx, w, h, cx, cy, R);
    }

    // The ball's reflections: bright dots drifting around the room, riding on the rotation
    function paintSpecks(ctx, w, h, cx, cy, R) {
        ctx.globalCompositeOperation = "lighter";
        const count = 46;
        for (let k = 0; k < count; k++) {
            const seed = hash(k, 1, 7);
            const a = seed * Math.PI * 2 + time * (0.25 + hash(k, 2, 7) * 0.3) * (k % 2 ? 1 : -1);
            const dist = (0.3 + hash(k, 3, 7) * 0.9) * Math.max(w, h) * 0.62;
            const x = cx + Math.cos(a) * dist, y = cy + Math.sin(a) * dist * 0.62;
            if (x < -40 || x > w + 40 || y < -40 || y > h + 40)
                continue;
            const size = (7 + hash(k, 4, 7) * 14) * (1 + 0.5 * pulse);
            const tw = 0.55 + 0.45 * Math.sin(time * 6 + k * 2.3);
            const g = ctx.createRadialGradient(x, y, 0, x, y, size);
            g.addColorStop(0, hsl(time * 0.05 + seed, 0.7, 0.85, 0.9 * tw));
            g.addColorStop(0.35, hsl(time * 0.05 + seed, 0.9, 0.6, 0.35 * tw));
            g.addColorStop(1, "rgba(0, 0, 0, 0)");
            ctx.fillStyle = g;
            ctx.fillRect(x - size, y - size, size * 2, size * 2);
        }
    }

    onPaint: {
        const ctx = getContext("2d");
        const w = width, h = height;
        paintBackdrop(ctx, w, h);
        paintFloor(ctx, w, h);
        paintBeams(ctx, w, h);
        paintBall(ctx, w, h);
        // A faint flash on every kick
        ctx.globalCompositeOperation = "lighter";
        ctx.fillStyle = `rgba(255, 255, 255, ${0.05 * pulse})`;
        ctx.fillRect(0, 0, w, h);
    }
}
