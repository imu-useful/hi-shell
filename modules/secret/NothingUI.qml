import QtQuick
import qs.common
import qs.common.widgets

// Keys "nothing", "nothing os", "nothingos", "nothing ui", "nothingui", "ndot": a silent show in the
// manner of dot-matrix interfaces: black, white dots on one grid, a single red accent. Four scenes
// (a ripple, glyph rings, a dial counting up, an equalizer) with the caption set in a 5x7 dot font
// whose dots flip on one after another and leave in the same order. Everything is dots: the scene
// is worked out as one pixel per cell of a tiny texture, and nothing.frag draws the dots from it.
Item {
    id: root

    required property bool revealed
    property real time: 0
    property real sinceFrame: 0

    readonly property real sceneLength: 7
    readonly property real cycle: sceneLength * 4
    readonly property int sceneIndex: Math.floor((time % cycle) / sceneLength)
    readonly property real sceneTime: (time % cycle) - sceneIndex * sceneLength
    readonly property var captions: ["NOTHING", "DOT MATRIX", "GLYPH", "HI"]
    readonly property var subtitles: [Translation.tr("Everything in dots"), Translation.tr("Light as a signal"), Translation.tr("Progress, plainly"), Translation.tr("Made for you")]

    readonly property int cols: 64
    readonly property real cell: width / cols
    readonly property int rows: Math.max(1, Math.ceil(height / cell))
    readonly property string red: "#d71921"

    // 5x7 dot font: one string per row, # is a lit dot
    readonly property var glyphs: ({
        "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
        "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
        "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
        "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
        "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
        "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
        "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
        "J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
        "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
        "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
        "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
        "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
        "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
        "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
        "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
        "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
        "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
        "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
        "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
        "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
        "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
        "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
        "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
        "6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
        "%": ["##..#", "##..#", "...#.", "..#..", ".#...", "#..##", "#..##"]
    })

    FrameAnimation {
        running: root.revealed
        onTriggered: {
            root.time += frameTime;
            root.sinceFrame += frameTime;
            if (root.sinceFrame >= 0.0155) { // about 60 fps whatever the display rate
                root.sinceFrame = 0;
                gridCanvas.requestPaint();
            }
        }
    }

    function clamp(x) {
        return Math.max(0, Math.min(1, x));
    }

    function spring(p) {
        const x = clamp(p);
        return 1 - Math.exp(-7 * x) * Math.cos(13 * x);
    }

    // Deterministic pseudo-random 0..1
    function rnd(a, b) {
        const x = Math.sin(a * 127.1 + b * 311.7) * 43758.5453;
        return x - Math.floor(x);
    }

    // The lit dots of a string, as [column, row] cells counted from (gx, gy); letters are 5 wide and
    // sit 6 apart, a space is 4
    function textCells(str, gx, gy) {
        const out = [];
        let x = gx;
        for (const ch of str) {
            const g = glyphs[ch];
            if (g) {
                for (let r = 0; r < 7; r++)
                    for (let c = 0; c < 5; c++)
                        if (g[r][c] === "#")
                            out.push([x + c, gy + r]);
            }
            x += g ? 6 : 4;
        }
        return out;
    }

    function textWidth(str) {
        let x = 0;
        for (const ch of str)
            x += glyphs[ch] ? 6 : 4;
        return x - 2;
    }

    // Works one frame out into three layers, a value per cell: W the grid dot's brightness, B the
    // size of a white text dot, G the size of a red dot
    function fill(W, G, B) {
        const cols = root.cols, rows = root.rows, t = time;
        const at = (gx, gy) => (gx < 0 || gx >= cols || gy < 0 || gy >= rows) ? -1 : Math.round(gy) * cols + Math.round(gx);
        const white = (gx, gy, lv) => { const i = at(Math.round(gx), Math.round(gy)); if (i >= 0) W[i] = Math.max(W[i], lv); };
        const redDot = (gx, gy, k) => { const i = at(Math.round(gx), Math.round(gy)); if (i >= 0) G[i] = Math.max(G[i], k); };

        const cx = (cols - 1) / 2, cy = rows * 0.36;
        const captionY = Math.round(rows * 0.66);
        const fade = clamp(sceneTime / 0.5) * clamp((sceneLength - sceneTime) / 0.5);
        const si = sceneIndex;
        const base = 0.1;

        for (let i = 0; i < cols * rows; i++)
            W[i] = base;

        if (si === 0) {
            // A ripple spreading from the middle
            for (let gy = 0; gy < rows; gy++) {
                for (let gx = 0; gx < cols; gx++) {
                    const d = Math.hypot(gx - cx, gy - cy);
                    const wave = Math.max(0, Math.sin(d * 0.5 - t * 3.2));
                    const reach = clamp(1 - d / 44) * clamp((captionY - 1 - gy) / 4 + 0.4);
                    W[gy * cols + gx] = base + 0.85 * wave * wave * reach * fade;
                }
            }
            const dr = (t * 10) % 30, ang = t * 1.4;
            redDot(cx + Math.cos(ang) * dr, cy + Math.sin(ang) * dr * 0.7, 1.6 * fade);
        } else if (si === 1) {
            // Rings of dots with a bright arc sweeping round each, like a strip of LEDs
            for (let k = 0; k < 5; k++) {
                const radius = 3 + k * 2.3, n = 18 + k * 8, speed = (k % 2 ? -1 : 1) * (1.2 + k * 0.35);
                for (let i = 0; i < n; i++) {
                    const a = i / n * Math.PI * 2;
                    const lit = Math.pow(Math.max(0, Math.cos(a - t * speed)), 5);
                    const x = cx + Math.cos(a) * radius, y = cy + Math.sin(a) * radius;
                    white(x, y, base + (0.15 + 0.75 * lit) * fade);
                    if (k === 4 && lit > 0.93)
                        redDot(x, y, 1.5 * fade);
                }
            }
        } else if (si === 2) {
            // A dial counting up to 100, a red dot at its front
            const eased = 1 - Math.pow(1 - clamp(sceneTime / 5), 3);
            const n = 56, radius = 9, front = Math.floor(eased * n);
            for (let i = 0; i < n; i++) {
                const a = -Math.PI / 2 + i / n * Math.PI * 2;
                const x = cx + Math.cos(a) * radius, y = cy + Math.sin(a) * radius;
                if (i < front)
                    white(x, y, Math.max(base, fade));
                else if (i === front && eased < 1)
                    redDot(x, y, 1.7 * fade);
                else
                    white(x, y, 0.2);
            }
            const number = Math.round(eased * 100) + "%";
            for (const [gx, gy] of textCells(number, Math.round(cx - textWidth(number) / 2), Math.round(cy - 3)))
                white(gx, gy, Math.max(base, fade));
        } else {
            // An equalizer: columns of dots rising and falling, a red cap running along them
            const colsN = 30, baseline = Math.round(cy + 8);
            const hot = Math.floor((t * 7) % colsN);
            for (let k = 0; k < colsN; k++) {
                const gx = Math.round(cx - 29 + k * 2);
                const height = 1 + Math.floor(13 * (0.5 + 0.5 * Math.sin(t * 3 + k * 0.45)) * (0.55 + 0.45 * Math.sin(t * 1.3 + k * 0.17)) * fade);
                for (let j = 0; j < height; j++)
                    white(gx, baseline - j, j === height - 1 ? 1 : 0.55);
                if (k === hot)
                    redDot(gx, baseline - height - 1, 1.5 * fade);
            }
        }

        // The caption: its dots flip on left to right with a little scatter, and off in the same order
        const caption = captions[si];
        const x0 = Math.round(cx - textWidth(caption) / 2);
        for (const [gx, gy] of textCells(caption, x0, captionY)) {
            const jitter = rnd(gx, gy) * 0.22;
            const inP = spring((sceneTime - 0.2 - (gx - x0) * 0.022 - jitter) / 0.4);
            const outP = clamp((sceneLength - sceneTime - (gx - x0) * 0.012 - jitter * 0.5) / 0.3);
            const i = at(gx, gy);
            if (i >= 0)
                B[i] = Math.max(0, inP) * outP;
        }

        // A red dot blinking where the next letter would go
        const done = clamp((sceneTime - 0.2 - textWidth(caption) * 0.022 - 0.6) / 0.2) * clamp((sceneLength - sceneTime) / 0.3);
        if (done > 0 && Math.floor(t * 2) % 2 === 0)
            redDot(x0 + textWidth(caption) + 3, captionY + 6, 1.3 * done);
    }

    // The tiny texture: one pixel a cell (R, G, B carry the three layers)
    Canvas {
        id: gridCanvas
        width: root.cols
        height: root.rows

        onPaint: {
            const ctx = getContext("2d");
            const n = root.cols * root.rows;
            const W = new Float32Array(n), G = new Float32Array(n), B = new Float32Array(n);
            root.fill(W, G, B);
            const cols = root.cols;
            for (let i = 0; i < n; i++) {
                const r = Math.round(Math.min(1, W[i]) * 255);
                const g = Math.round(Math.min(1, G[i] / 2) * 255);
                const b = Math.round(Math.min(1, B[i] / 1.5) * 255);
                ctx.fillStyle = `rgb(${r}, ${g}, ${b})`;
                ctx.fillRect(i % cols, Math.floor(i / cols), 1, 1);
            }
        }
    }

    ShaderEffectSource {
        id: gridTexture
        sourceItem: gridCanvas
        hideSource: true
        live: true
        smooth: false
        textureSize: Qt.size(root.cols, root.rows)
    }

    ShaderEffect {
        anchors.fill: parent
        property variant grid: gridTexture
        property vector2d res: Qt.vector2d(width, height)
        property real cols: root.cols
        property real rows: root.rows
        fragmentShader: Qt.resolvedUrl("nothing.frag.qsb")
    }

    // ---- the small print -------------------------------------------------------------------------

    Row {
        x: root.cell * 2
        y: root.cell * 1.6
        spacing: 12
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: root.cell * 0.9
            height: width
            radius: width / 2
            color: root.red
            opacity: Math.floor(root.time * 1.5) % 2 === 0 ? 1 : 0.25
        }
        StyledText {
            text: "hi-shell · ndot"
            font.family: Appearance.font.mono
            font.pixelSize: Math.max(12, root.cell * 0.9)
            color: "white"
            opacity: 0.7
        }
    }

    StyledText {
        anchors.right: parent.right
        anchors.rightMargin: root.cell * 2
        y: root.cell * 1.4
        text: String(Math.floor(root.time / 60)).padStart(2, "0") + ":" + String(Math.floor(root.time % 60)).padStart(2, "0")
        font.family: Appearance.font.mono
        font.pixelSize: Math.max(12, root.cell * 0.9)
        color: "white"
        opacity: 0.7
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.cell * 1.6
        text: root.subtitles[root.sceneIndex].toUpperCase()
        font.family: Appearance.font.mono
        font.pixelSize: Math.max(12, root.cell * 0.9)
        font.letterSpacing: 3
        color: "white"
        opacity: 0.55 * root.clamp(root.sceneTime / 0.6) * root.clamp((root.sceneLength - root.sceneTime) / 0.4)
    }
}
