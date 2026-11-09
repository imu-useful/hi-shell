import QtQuick
import qs.common
import qs.common.widgets

// Keys "undertale" and "story": a short picture-book intro in the manner of old pixel RPGs, with
// a story of its own (a little shell wakes up in a city whose lights went out). Pixel scenes in a
// frame, the text typed out below; a click moves on, the last click closes.
Item {
    id: root

    required property bool revealed
    signal finished()

    readonly property var lines: [
        Translation.tr("Long ago, the desktop was a quiet place."),
        Translation.tr("Windows lived there, and every window kept a little light on."),
        Translation.tr("Then came the Great Freeze. One by one, the lights went out."),
        Translation.tr("But in the dark, a tiny shell woke up."),
        Translation.tr("It didn't know much. It only knew one word."),
        Translation.tr("\"hi.\"")
    ]
    property int panel: 0
    property int typed: 0
    property real clock: 0
    readonly property string line: lines[panel]
    readonly property bool lineDone: typed >= line.length
    readonly property bool last: panel === lines.length - 1

    MusicLoop { file: "story.ogg"; playing: root.revealed }

    function next() {
        if (!lineDone) {
            typed = line.length;
            return;
        }
        if (last) {
            finished();
            return;
        }
        panel++;
        typed = 0;
        clock = 0;
    }

    Timer {
        interval: 55
        running: root.revealed && !root.lineDone
        repeat: true
        onTriggered: root.typed++
    }

    // After a line is complete, the story moves on by itself (not past the last panel)
    Timer {
        interval: 2600
        running: root.revealed && root.lineDone && !root.last
        onTriggered: root.next()
    }

    FrameAnimation {
        running: root.revealed
        onTriggered: {
            root.clock += frameTime;
            scene.requestPaint();
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.next()
    }

    Item {
        id: stage
        readonly property real frameW: Math.min(root.width * 0.8, root.height * 0.62 * 4 / 3)
        width: frameW
        height: frameW * 3 / 4
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.08

        Rectangle {
            anchors.fill: parent
            anchors.margins: -8
            color: "transparent"
            border.color: "white"
            border.width: 6
        }

        Canvas {
            id: scene
            anchors.fill: parent
            readonly property real u: width / 64
            property int shown: -1
            property real fade: 0

            function px(ctx, x, y, w, h, color) {
                ctx.fillStyle = color;
                ctx.fillRect(Math.round(x * u), Math.round(y * u), Math.ceil(w * u), Math.ceil(h * u));
            }

            // Stable pseudo-random numbers so the stars don't jump around
            function rnd(n) {
                const x = Math.sin(n * 91.3458) * 47453.5453;
                return x - Math.floor(x);
            }

            function sky(ctx, top, bottom) {
                for (let y = 0; y < 48; y += 2) {
                    const t = y / 48;
                    const mix = (a, b) => Math.round(a + (b - a) * t);
                    px(ctx, 0, y, 64, 2, `rgb(${mix(top[0], bottom[0])}, ${mix(top[1], bottom[1])}, ${mix(top[2], bottom[2])})`);
                }
            }

            function stars(ctx, count, tw) {
                for (let i = 0; i < count; i++) {
                    const on = tw ? (Math.floor(root.clock * 3 + i) % 4 !== 0) : true;
                    px(ctx, Math.floor(rnd(i) * 64), Math.floor(rnd(i + 99) * 26), 1, 1, on ? "#ffffff" : "#8899bb");
                }
            }

            // A city of windows: `lit` is how many of the 28 lights still burn
            function city(ctx, lit) {
                const widths = [7, 9, 6, 10, 8, 7, 9, 8];
                const heights = [18, 26, 14, 30, 22, 16, 28, 20];
                let x = 0, n = 0;
                for (let b = 0; b < widths.length; b++) {
                    const w = widths[b], h = heights[b];
                    px(ctx, x, 48 - h, w - 1, h, "#1b1535");
                    for (let wy = 48 - h + 2; wy < 46; wy += 4) {
                        for (let wx = x + 1; wx < x + w - 2; wx += 3) {
                            const on = (n % 28) < lit;
                            ctx.fillStyle = on ? "#ffd75e" : "#2a2250";
                            ctx.fillRect(Math.round(wx * u), Math.round(wy * u), Math.ceil(2 * u), Math.ceil(2 * u));
                            n++;
                        }
                    }
                    x += w;
                }
            }

            function shell(ctx, cx, cy, wave, glow) {
                if (glow > 0) {
                    const g = ctx.createRadialGradient(cx * u, cy * u, 0, cx * u, cy * u, 22 * u);
                    g.addColorStop(0, `rgba(255, 220, 140, ${0.55 * glow})`);
                    g.addColorStop(1, "rgba(255, 220, 140, 0)");
                    ctx.fillStyle = g;
                    ctx.fillRect(0, 0, width, height);
                }
                // Spiral shell: a round body in rings of lighter and darker sand
                const rings = ["#8a5a3c", "#d9a066", "#f2d2a0", "#d9a066", "#f2d2a0", "#8a5a3c"];
                for (let r = 0; r < rings.length; r++) {
                    const rad = 7 - r * 1.1;
                    for (let dy = -rad; dy <= rad; dy++) {
                        const half = Math.floor(Math.sqrt(Math.max(0, rad * rad - dy * dy)));
                        px(ctx, cx - half - 2, cy + dy - 2, half * 2 + 1, 1, rings[r]);
                    }
                }
                // The soft body peeking out from under it, with two eyes
                px(ctx, cx - 9, cy + 3, 9, 4, "#ffb7a8");
                px(ctx, cx - 8, cy + 3, 1, 2, "#2b1a1a");
                px(ctx, cx - 5, cy + 3, 1, 2, "#2b1a1a");
                // One little arm; it waves when `wave` is on
                const swing = wave ? Math.floor(Math.sin(root.clock * 9) * 2) : 0;
                px(ctx, cx - 11, cy + 2 + swing - (wave ? 3 : 0), 2, 3, "#ffb7a8");
            }

            onPaint: {
                const ctx = getContext("2d");
                const p = root.panel;
                ctx.clearRect(0, 0, width, height);
                if (p === 0) {
                    sky(ctx, [10, 8, 40], [60, 30, 80]);
                    stars(ctx, 48, true);
                    px(ctx, 46, 6, 6, 6, "#f4eed0");
                    px(ctx, 48, 5, 2, 8, "#f4eed0");
                    px(ctx, 45, 8, 8, 2, "#f4eed0");
                    // Far hills
                    for (let x = 0; x < 64; x++) {
                        const h = 8 + Math.floor(6 * Math.sin(x / 7) + 3 * Math.sin(x / 3));
                        px(ctx, x, 48 - h, 1, h, "#150f2a");
                    }
                } else if (p === 1) {
                    sky(ctx, [20, 14, 60], [200, 110, 90]);
                    stars(ctx, 16, true);
                    city(ctx, 28);
                } else if (p === 2) {
                    sky(ctx, [8, 6, 24], [40, 24, 50]);
                    // The lights go out one by one over the time of the line
                    const lit = Math.max(0, 28 - Math.floor(root.clock * 5));
                    // The freeze: pale cracks spreading from the top
                    for (let c = 0; c < 6; c++) {
                        let x = 8 + c * 10, y = 0;
                        for (let s = 0; s < 14; s++) {
                            if (s > root.clock * 8)
                                break;
                            px(ctx, x, y, 1, 2, "#bfe6ff");
                            x += Math.floor(rnd(c * 20 + s) * 3) - 1;
                            y += 2;
                        }
                    }
                    city(ctx, lit);
                } else if (p === 3) {
                    px(ctx, 0, 0, 64, 48, "#07050f");
                    // Distant cold city, all dark
                    city(ctx, 0);
                    px(ctx, 0, 0, 64, 48, "rgba(7, 5, 15, 0.7)");
                    shell(ctx, 34, 30, false, Math.min(1, root.clock / 2));
                } else if (p === 4) {
                    px(ctx, 0, 0, 64, 48, "#0b0818");
                    shell(ctx, 34, 28, false, 1);
                    // A thought bubble that fills with dots
                    const dots = Math.min(3, Math.floor(root.clock * 1.5));
                    for (let d = 0; d < dots; d++)
                        px(ctx, 44 + d * 4, 14 - d * 2, 2, 2, "#ffffff");
                } else {
                    // Dawn
                    sky(ctx, [30, 20, 70], [255, 170, 110]);
                    stars(ctx, 10, false);
                    city(ctx, Math.min(28, Math.floor(root.clock * 6)));
                    shell(ctx, 34, 34, true, 1);
                    // The word, as a pixel speech bubble
                    if (root.clock > 0.6) {
                        px(ctx, 24, 12, 18, 9, "#ffffff");
                        px(ctx, 30, 21, 3, 3, "#ffffff");
                        ctx.fillStyle = "#1b1535";
                        ctx.font = `bold ${Math.round(6 * u)}px ${Appearance.font.mono}`;
                        ctx.textAlign = "center";
                        ctx.fillText("hi", 33 * u, 19 * u);
                    }
                }
            }
        }
    }

    StyledText {
        anchors.top: stage.bottom
        anchors.topMargin: 36
        anchors.horizontalCenter: parent.horizontalCenter
        width: stage.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        font.family: Appearance.font.mono
        font.pixelSize: Math.max(18, Math.min(34, root.width / 48))
        color: "white"
        text: root.line.slice(0, root.typed)
    }

    StyledText {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: root.lineDone ? 0.5 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        text: root.last ? Translation.tr("Click to end") : Translation.tr("Click to go on")
        font.family: Appearance.font.mono
        color: "white"
    }
}
