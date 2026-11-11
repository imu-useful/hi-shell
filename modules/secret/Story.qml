import QtQuick
import qs.common
import qs.common.widgets

// Keys "undertale" and "story": a short picture-book intro in the manner of old pixel RPGs, with
// a story of its own (a seed on a lifeless planet waits for rain and grows into the first tree). Pixel scenes in a
// frame, the text typed out below; a click moves on, the last click closes.
Item {
    id: root

    required property bool revealed
    signal finished()

    readonly property var lines: [
        Translation.tr("On a far, quiet planet, nothing had grown for a thousand years."),
        Translation.tr("One day the wind dropped a tiny seed into the sand."),
        Translation.tr("It waited for rain. It waited a very long time."),
        Translation.tr("Then a single cloud came, and the seed woke up."),
        Translation.tr("It grew and grew, and the first bird in a thousand years came to sit on it."),
        Translation.tr("The tree looked around and said \"hi.\"")
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

            // The sand surface: gentle dunes
            function sy(x) {
                return 38 + Math.round(Math.sin(x / 6));
            }

            function ground(ctx) {
                for (let x = 0; x < 64; x++) {
                    const y = sy(x);
                    px(ctx, x, y, 1, 48 - y, "#c98f52");
                    px(ctx, x, y + 6, 1, 48 - y - 6, "#a8703a");
                }
                for (let i = 0; i < 6; i++)
                    px(ctx, Math.floor(rnd(i + 7) * 62), 42 + Math.floor(rnd(i + 3) * 5), 2, 1, "#8a5a2c");
            }

            function sun(ctx, x, y) {
                px(ctx, x - 3, y - 4, 6, 8, "#ffe08a");
                px(ctx, x - 4, y - 3, 8, 6, "#ffe08a");
            }

            function cloud(ctx, x, y) {
                px(ctx, x - 9, y + 2, 18, 3, "#8a93a8");
                px(ctx, x - 7, y, 14, 3, "#a9b2c6");
                px(ctx, x - 4, y - 2, 9, 3, "#c4ccdc");
            }

            function rain(ctx, x, y, w) {
                for (let i = 0; i < 16; i++) {
                    const dropX = x - w / 2 + rnd(i + 31) * w;
                    const fall = (root.clock * 22 + rnd(i) * 30) % 30;
                    const top = y + fall;
                    if (top < sy(dropX) - 1)
                        px(ctx, dropX, top, 1, 2, "#8fd0ff");
                }
            }

            // A plant of growth g (0..1): sprout with two leaves, then trunk and round crown
            function plant(ctx, x, g, face) {
                const base = sy(x);
                if (g < 0.3) {
                    const h = Math.max(1, Math.round(g / 0.3 * 5));
                    px(ctx, x, base - h, 1, h, "#6bd05a");
                    if (h > 2) {
                        px(ctx, x - 2, base - h, 2, 1, "#8be070");
                        px(ctx, x + 1, base - h + 1, 2, 1, "#8be070");
                    }
                    return;
                }
                const t = (g - 0.3) / 0.7;
                const h = 5 + Math.round(t * 13);
                px(ctx, x - 1, base - h, 2, h, "#6b4423");
                const r = Math.round(2 + t * 8);
                for (let dy = -r; dy <= r; dy++) {
                    const half = Math.floor(Math.sqrt(r * r - dy * dy));
                    px(ctx, x - half, base - h + dy - 2, half * 2 + 1, 1, dy < -r / 3 ? "#7bd36a" : "#4caf50");
                }
                if (face && r >= 6) {
                    const fy = base - h - 2;
                    const eye = blinking() ? 1 : 2;
                    px(ctx, x - 3, fy - 1, 1, eye, "#1b1535");
                    px(ctx, x + 2, fy - 1, 1, eye, "#1b1535");
                    px(ctx, x - 1, fy + 2, 3, 1, "#1b1535");
                    px(ctx, x - 2, fy + 1, 1, 1, "#1b1535");
                    px(ctx, x + 2, fy + 1, 1, 1, "#1b1535");
                    px(ctx, x - 5, fy + 1, 2, 1, "#ff9aa8");
                    px(ctx, x + 4, fy + 1, 2, 1, "#ff9aa8");
                }
            }

            function blinking() {
                return Math.floor(root.clock * 1.4) % 5 === 0 && (root.clock * 1.4) % 1 < 0.25;
            }

            function butterfly(ctx, x, y, color) {
                const open = Math.floor(root.clock * 7) % 2 === 0;
                px(ctx, x, y, 1, 2, "#2b1a1a");
                px(ctx, x - (open ? 2 : 1), y - 1, open ? 2 : 1, 2, color);
                px(ctx, x + 1, y - 1, open ? 2 : 1, 2, color);
            }

            function rainbow(ctx, grow) {
                const colors = ["#ff5a5a", "#ffb04a", "#ffe24a", "#6bd05a", "#4aa8ff", "#8a6bff"];
                for (let i = 0; i < colors.length; i++) {
                    const r = 30 - i * 1.5;
                    for (let a = 0; a <= grow * 180; a += 3) {
                        const rad = a * Math.PI / 180;
                        px(ctx, 32 - Math.cos(rad) * r, 40 - Math.sin(rad) * r, 2, 2, colors[i]);
                    }
                }
            }

            function note(ctx, x, y, color) {
                px(ctx, x, y, 2, 2, color);
                px(ctx, x + 1, y - 4, 1, 4, color);
                px(ctx, x + 2, y - 4, 2, 1, color);
            }

            function bird(ctx, x, y, flap) {
                px(ctx, x, y, 3, 2, "#e8594a");
                px(ctx, x + 3, y - 1, 2, 2, "#e8594a");
                px(ctx, x + 5, y, 1, 1, "#ffb347");
                px(ctx, x + 3, y, 1, 1, "#ffffff");
                if (flap)
                    px(ctx, x, y - 2, 3, 1, "#c0392b");
            }

            onPaint: {
                const ctx = getContext("2d");
                const p = root.panel;
                const c = root.clock;
                ctx.clearRect(0, 0, width, height);
                if (p === 0) {
                    sky(ctx, [90, 110, 180], [250, 195, 140]);
                    sun(ctx, 46, 12);
                    ground(ctx);
                    // Dust drifting over empty sand
                    for (let i = 0; i < 8; i++)
                        px(ctx, (rnd(i) * 64 + c * (4 + i)) % 64, 30 + rnd(i + 5) * 8, 2, 1, "#e6c08a");
                    // A little worm pops out of the sand, looks around and hides again
                    const w = Math.sin(c * 1.6);
                    if (w > 0) {
                        const h = Math.round(w * 4);
                        const look = Math.sin(c * 4) > 0 ? 1 : 0;
                        px(ctx, 14, sy(14) - h + 1, 2, h, "#e89aa0");
                        px(ctx, 14 + look, sy(14) - h + 1, 1, 1, "#1b1535");
                    }
                } else if (p === 1) {
                    sky(ctx, [90, 110, 180], [250, 195, 140]);
                    sun(ctx, 46, 12);
                    ground(ctx);
                    // Wind streaks, and the seed carried on them until it lands
                    for (let i = 0; i < 6; i++)
                        px(ctx, (rnd(i + 11) * 80 + c * 40) % 80 - 8, 8 + rnd(i + 17) * 26, 6, 1, "#ffffff");
                    const e = Math.min(1, c / 3);
                    const x = 4 + 28 * e;
                    const y = Math.min(sy(x) - 1, 4 + 40 * e * e);
                    px(ctx, x, y, 2, 2, "#4a3020");
                    px(ctx, x, y, 1, 1, "#7a5535");
                } else if (p === 2) {
                    // Days and nights go by over the waiting seed
                    const t = c / 5;
                    const night = Math.sin(t * Math.PI * 2) < 0;
                    if (night) {
                        sky(ctx, [8, 8, 30], [40, 30, 70]);
                        stars(ctx, 36, true);
                        px(ctx, 12, 8, 5, 5, "#f4eed0");
                    } else {
                        sky(ctx, [90, 110, 180], [250, 195, 140]);
                        sun(ctx, 8 + (t * 2 % 1) * 48, 20 - Math.sin((t * 2 % 1) * Math.PI) * 14);
                    }
                    ground(ctx);
                    if (night) {
                        const m = (c * 0.9) % 1;
                        if (m < 0.35) {
                            const k = m / 0.35;
                            for (let i = 0; i < 6; i++)
                                px(ctx, 50 - k * 36 + i, 4 + k * 12 - i * 0.5, 1, 1, i === 5 ? "#ffffff" : "#8899cc");
                        }
                    }
                    px(ctx, 31, sy(32) - 3, 3, 3, "#4a3020");
                    if (!blinking()) {
                        px(ctx, 31, sy(32) - 2, 1, 1, "#ffffff");
                        px(ctx, 33, sy(32) - 2, 1, 1, "#ffffff");
                    }
                } else if (p === 3) {
                    sky(ctx, [60, 70, 100], [150, 150, 170]);
                    ground(ctx);
                    cloud(ctx, 32, 8);
                    if (c < 3.5)
                        rain(ctx, 32, 12, 20);
                    else
                        rainbow(ctx, Math.min(1, (c - 3.5) / 1.2));
                    plant(ctx, 32, Math.min(0.3, c * 0.1));
                } else if (p === 4) {
                    sky(ctx, [80, 150, 230], [250, 210, 160]);
                    sun(ctx, 52, 8);
                    ground(ctx);
                    plant(ctx, 32, Math.min(1, 0.3 + c * 0.2), true);
                    if (c > 3) {
                        butterfly(ctx, 12 + Math.sin(c * 2) * 6, 26 + Math.cos(c * 3) * 3, "#ff8fb1");
                        butterfly(ctx, 50 + Math.cos(c * 1.7) * 5, 24 + Math.sin(c * 2.4) * 3, "#ffe14a");
                    }
                    // The first bird flies in and lands on the crown
                    if (c > 2.5) {
                        const e = Math.min(1, (c - 2.5) / 1.5);
                        bird(ctx, 62 - 26 * e, 6 + 2 * e, e < 1 && Math.floor(c * 8) % 2 === 0);
                    }
                } else {
                    sky(ctx, [70, 140, 225], [255, 215, 160]);
                    sun(ctx, 52, 8);
                    ground(ctx);
                    // A few flowers around the tree
                    for (let i = 0; i < 5; i++) {
                        const fx = 12 + i * 10 + (i % 2) * 3;
                        if (c > 0.4 + i * 0.2) {
                            px(ctx, fx, sy(fx) - 2, 1, 2, "#4caf50");
                            px(ctx, fx - 1, sy(fx) - 3, 3, 1, i % 2 ? "#ff8fb1" : "#ffe14a");
                        }
                    }
                    plant(ctx, 32, 1, true);
                    bird(ctx, 36, 17, false);
                    butterfly(ctx, 14 + Math.sin(c * 2) * 6, 26 + Math.cos(c * 3) * 3, "#ff8fb1");
                    butterfly(ctx, 52 + Math.cos(c * 1.7) * 5, 24 + Math.sin(c * 2.4) * 3, "#ffe14a");
                    // The bird sings
                    for (let i = 0; i < 3; i++) {
                        const k = (c * 0.8 + i / 3) % 1;
                        note(ctx, 42 + k * 8 + Math.sin(k * 9) * 1.5, 16 - k * 10, i % 2 ? "#ffffff" : "#ffe14a");
                    }
                    // The word, as a pixel speech bubble
                    if (c > 0.6) {
                        px(ctx, 6, 8, 18, 9, "#ffffff");
                        px(ctx, 22, 17, 3, 3, "#ffffff");
                        ctx.fillStyle = "#1b1535";
                        ctx.font = `bold ${Math.round(6 * u)}px ${Appearance.font.mono}`;
                        ctx.textAlign = "center";
                        ctx.fillText("hi", 15 * u, 15 * u);
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
