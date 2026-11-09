import QtQuick
import qs.common

// Key "nyan": the pixel cat flies over a starfield trailing a rainbow, with a chiptune loop.
Canvas {
    id: root

    required property bool revealed
    property int frame: 0
    readonly property int unit: Math.max(4, Math.floor(Math.min(width / 70, height / 34)))
    readonly property var rainbow: ["#ff0000", "#ff9900", "#ffff00", "#33ff00", "#0099ff", "#6633ff"]
    property var stars: []

    MusicLoop { file: "nyan.ogg"; playing: root.revealed }

    Rectangle { anchors.fill: parent; z: -1; color: "#003366" }

    Timer {
        interval: 100
        running: root.revealed
        repeat: true
        onTriggered: {
            root.frame++;
            root.requestPaint();
        }
    }

    function box(ctx, x, y, w, h, color) {
        ctx.fillStyle = color;
        ctx.fillRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h));
    }

    onPaint: {
        const ctx = getContext("2d");
        const u = unit;
        ctx.clearRect(0, 0, width, height);
        if (stars.length === 0)
            stars = Array.from({ length: 40 }, () => ({ x: Math.random() * width, y: Math.random() * height, s: 1 + Math.floor(Math.random() * 2), v: 1 + Math.floor(Math.random() * 3) }));
        for (const s of stars) {
            s.x -= s.v * u * 0.8;
            if (s.x < 0) { s.x = width; s.y = Math.random() * height; }
            const tw = (frame + Math.floor(s.y)) % 6 < 3;
            box(ctx, s.x, s.y, u * s.s, u * s.s, tw ? "white" : "#99ccff");
        }

        const bob = (frame % 8) < 4 ? 0 : u;
        const cx = Math.round(width / 2 - 14 * u);
        const cy = Math.round(height / 2 - 9 * u) + bob;

        // Rainbow: from the left edge to the body, each 2-unit column hops up and down
        const bodyLeft = cx + 3 * u;
        const cols = Math.ceil(bodyLeft / (3 * u));
        for (let i = 0; i < cols; i++) {
            const x = bodyLeft - (i + 1) * 3 * u;
            const hop = ((i + Math.floor(frame / 2)) % 2) * u;
            for (let b = 0; b < 6; b++)
                box(ctx, x, cy + 3 * u + b * 2 * u + hop - bob * 0, 3 * u, 2 * u, rainbow[b]);
        }

        // Pop-tart body
        box(ctx, cx + 3 * u, cy + 2 * u, 18 * u, 14 * u, "black");
        box(ctx, cx + 4 * u, cy + 3 * u, 16 * u, 12 * u, "#ffcc99");
        box(ctx, cx + 5 * u, cy + 4 * u, 14 * u, 10 * u, "#ff99ff");
        const sprinkles = [[7, 6], [11, 5], [15, 7], [8, 9], [13, 10], [17, 11], [10, 12], [6, 11], [16, 5], [12, 8]];
        sprinkles.forEach(([sx, sy], i) => box(ctx, cx + sx * u, cy + sy * u, u, u, (i + Math.floor(frame / 3)) % 3 === 0 ? "#ff3399" : "#ff0066"));

        // Tail, feet
        const wag = (frame % 4) < 2 ? 0 : u;
        box(ctx, cx, cy + 10 * u + wag, 4 * u, 3 * u, "black");
        box(ctx, cx + u, cy + 11 * u + wag, 3 * u, u, "#999999");
        const step = (frame % 4) < 2 ? 0 : u;
        for (const fx of [5, 9, 18, 22]) {
            box(ctx, cx + fx * u, cy + 16 * u, 4 * u, 3 * u, "black");
            box(ctx, cx + (fx + 1) * u, cy + 16 * u, 2 * u + step, 2 * u, "#999999");
        }

        // Head with ears, eyes, cheeks, mouth
        const hx = cx + 16 * u, hy = cy + 6 * u;
        box(ctx, hx, hy, 12 * u, 11 * u, "black");
        box(ctx, hx + u, hy + u, 10 * u, 9 * u, "#999999");
        box(ctx, hx + u, hy - 2 * u, 3 * u, 3 * u, "black");
        box(ctx, hx + 8 * u, hy - 2 * u, 3 * u, 3 * u, "black");
        box(ctx, hx + 2 * u, hy - u, u, 2 * u, "#999999");
        box(ctx, hx + 9 * u, hy - u, u, 2 * u, "#999999");
        box(ctx, hx + 2 * u, hy + 3 * u, 2 * u, 2 * u, "black");
        box(ctx, hx + 7 * u, hy + 3 * u, 2 * u, 2 * u, "black");
        box(ctx, hx + 2 * u, hy + 3 * u, u, u, "white");
        box(ctx, hx + 7 * u, hy + 3 * u, u, u, "white");
        box(ctx, hx + u, hy + 6 * u, 2 * u, 2 * u, "#ff9999");
        box(ctx, hx + 8 * u, hy + 6 * u, 2 * u, 2 * u, "#ff9999");
        box(ctx, hx + 4 * u, hy + 6 * u, 3 * u, u, "black");
    }
}
