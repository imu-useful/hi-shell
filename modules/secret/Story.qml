import QtQuick
import qs.common
import qs.common.widgets

// Keys "undertale" and "story": a short picture-book intro in the manner of old pixel RPGs, with
// a story of its own (a little comet slows down and learns to say hi). Pixel scenes in a
// frame, the text typed out below; a click moves on, the last click closes.
Item {
    id: root

    required property bool revealed
    signal finished()

    readonly property var lines: [
        Translation.tr("Far above the desktop, a little comet drifted alone."),
        Translation.tr("It was the fastest thing in the sky, and nobody ever noticed it."),
        Translation.tr("One night it passed an old star, who said: \"Slow down.\""),
        Translation.tr("So the comet slowed down, and for the first time it saw the city below."),
        Translation.tr("In one window, a child looked up and made a wish."),
        Translation.tr("The comet stayed. And every night since, it says \"hi.\"")
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

            // A comet: bright head, a tail of fading sparks behind it (up and to the left)
            function comet(ctx, cx, cy, tail, glow) {
                if (glow > 0) {
                    const g = ctx.createRadialGradient(cx * u, cy * u, 0, cx * u, cy * u, 14 * u);
                    g.addColorStop(0, `rgba(255, 230, 160, ${0.6 * glow})`);
                    g.addColorStop(1, "rgba(255, 230, 160, 0)");
                    ctx.fillStyle = g;
                    ctx.fillRect(0, 0, width, height);
                }
                for (let i = tail; i > 0; i--) {
                    const t = 1 - i / tail;
                    const col = t > 0.6 ? "#fff1c4" : (t > 0.3 ? "#ffc96b" : "#b5683c");
                    px(ctx, cx - i, cy - i * 0.35, 2, 2, col);
                    if (i % 3 === 0)
                        px(ctx, cx - i, cy - i * 0.35 + 3 + Math.floor(rnd(i) * 2), 1, 1, col);
                }
                px(ctx, cx - 1, cy - 1, 4, 4, "#ffb347");
                px(ctx, cx, cy, 2, 2, "#ffffff");
            }

            // An old star with a cross of light
            function bigStar(ctx, cx, cy, pulse) {
                const r = 3 + Math.round(pulse);
                px(ctx, cx - 1, cy - r, 3, r * 2 + 1, "#fff6d8");
                px(ctx, cx - r, cy - 1, r * 2 + 1, 3, "#fff6d8");
                px(ctx, cx - 2, cy - 2, 5, 5, "#ffffff");
            }

            onPaint: {
                const ctx = getContext("2d");
                const p = root.panel;
                const c = root.clock;
                ctx.clearRect(0, 0, width, height);
                if (p === 0) {
                    sky(ctx, [8, 6, 36], [50, 28, 76]);
                    stars(ctx, 44, true);
                    comet(ctx, 12 + c * 3, 20 - c * 0.6, 10, 0.7);
                } else if (p === 1) {
                    sky(ctx, [6, 8, 40], [30, 40, 90]);
                    stars(ctx, 30, true);
                    // It races across again and again; nobody is looking
                    const x = (c * 38) % 96 - 16;
                    comet(ctx, x, 10 + x * 0.25, 26, 0.8);
                    city(ctx, 6);
                } else if (p === 2) {
                    sky(ctx, [10, 8, 44], [54, 30, 84]);
                    stars(ctx, 36, true);
                    bigStar(ctx, 46, 14, Math.sin(c * 3));
                    // It arrives fast and eases to a stop beside the star
                    const e = Math.min(1, c / 3.5);
                    const x = -10 + 40 * (1 - Math.pow(1 - e, 3));
                    comet(ctx, x, 22 - 6 * e, Math.round(24 - 18 * e), 0.8);
                } else if (p === 3) {
                    sky(ctx, [14, 10, 56], [150, 90, 110]);
                    stars(ctx, 20, true);
                    comet(ctx, 30 + Math.sin(c * 1.2) * 2, 14 + Math.sin(c * 2) * 1, 6, 1);
                    // The windows light up one by one as it looks
                    city(ctx, Math.min(28, Math.floor(c * 5)));
                } else if (p === 4) {
                    sky(ctx, [10, 8, 44], [60, 34, 84]);
                    stars(ctx, 30, false);
                    comet(ctx, 40, 12, 5, 1);
                    // A big window, a warm room, a child at the glass
                    px(ctx, 14, 22, 30, 26, "#1b1535");
                    px(ctx, 16, 24, 26, 22, "#ffd75e");
                    px(ctx, 28, 24, 2, 22, "#1b1535");
                    px(ctx, 16, 34, 26, 2, "#1b1535");
                    px(ctx, 20, 38, 6, 8, "#3a2a5a");
                    px(ctx, 21, 31, 4, 4, "#f2d2a0");
                    px(ctx, 22, 32, 1, 1, "#2b1a1a");
                    px(ctx, 24, 32, 1, 1, "#2b1a1a");
                    // The wish rises as sparkles
                    const n = Math.min(5, Math.floor(c * 1.5));
                    for (let i = 0; i < n; i++)
                        px(ctx, 26 + i * 3, 20 - i * 3, 1, 1, i % 2 ? "#ffffff" : "#ffd75e");
                } else {
                    sky(ctx, [30, 20, 70], [255, 170, 110]);
                    stars(ctx, 10, false);
                    city(ctx, Math.min(28, Math.floor(c * 6)));
                    comet(ctx, 34, 24, 4, 1);
                    // The word, as a pixel speech bubble
                    if (c > 0.6) {
                        px(ctx, 36, 10, 18, 9, "#ffffff");
                        px(ctx, 38, 19, 3, 3, "#ffffff");
                        ctx.fillStyle = "#1b1535";
                        ctx.font = `bold ${Math.round(6 * u)}px ${Appearance.font.mono}`;
                        ctx.textAlign = "center";
                        ctx.fillText("hi", 45 * u, 17 * u);
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
