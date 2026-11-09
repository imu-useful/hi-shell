import QtQuick
import qs.common
import qs.common.widgets

// Keys "liquid glass", "liquid", "glass", "lg": a silent show of liquid glass. A vivid scene (drifting
// color, a fine grid, the animated caption) sits behind a pane of glass made of eight droplets that
// merge and part as they move; glass.frag bends the scene through them. Four scenes flow into one
// another: orbiting drops, a lens snaking over the words, drops rising, a pulsing ring.
Item {
    id: root

    required property bool revealed
    property real time: 0

    readonly property real sceneLength: 7
    readonly property real blendLength: 1.2
    readonly property real cycle: sceneLength * 4
    readonly property int sceneIndex: Math.floor((time % cycle) / sceneLength)
    readonly property real sceneTime: (time % cycle) - sceneIndex * sceneLength
    readonly property var captions: [Translation.tr("Liquid Glass"), Translation.tr("Refraction"), Translation.tr("Fluid motion"), Translation.tr("Made for you")]
    property real baseHue: 0.6
    readonly property real hue: baseHue + time * 0.03

    property vector4d b0; property vector4d b1; property vector4d b2; property vector4d b3
    property vector4d b4; property vector4d b5; property vector4d b6; property vector4d b7

    Component.onCompleted: {
        const h = Colors.m3primary.hslHue;
        baseHue = h >= 0 ? h : 0.6;
    }

    FrameAnimation {
        running: root.revealed
        onTriggered: {
            root.time += frameTime;
            root.layoutBlobs();
        }
    }

    function clamp(x) {
        return Math.max(0, Math.min(1, x));
    }

    function smooth(x) {
        const t = clamp(x);
        return t * t * (3 - 2 * t);
    }

    // ---- the droplets: [x, y, radius] each, 8 per layout --------------------------------------

    function orbit(w, h, u, t) {
        const out = [[w / 2, h / 2, u * (0.15 + 0.02 * Math.sin(t * 1.6))]];
        for (let k = 1; k < 8; k++) {
            const ang = t * 0.5 + k * 0.9;
            const ring = u * 0.3 * (0.65 + 0.35 * Math.sin(t * 0.7 + k * 1.3));
            out.push([w / 2 + Math.cos(ang) * ring * 1.35, h / 2 + Math.sin(ang) * ring, u * (0.05 + 0.03 * ((k * 7) % 3) / 2)]);
        }
        return out;
    }

    function snake(w, h, u, t) {
        const out = [];
        for (let k = 0; k < 8; k++) {
            const tt = t - k * 0.17;
            out.push([w / 2 + w * 0.36 * Math.sin(tt * 0.55), h / 2 + h * 0.2 * Math.sin(tt * 0.95 + 1), u * (0.15 - k * 0.013)]);
        }
        return out;
    }

    function rain(w, h, u, t) {
        const out = [];
        for (let k = 0; k < 8; k++) {
            const speed = 0.07 + (k % 3) * 0.025;
            const rise = ((t * speed + k * 0.137) % 1.25);
            out.push([w * (0.12 + k * 0.108) + Math.sin(t * 1.3 + k) * u * 0.05, h * (1.12 - rise), u * (0.055 + 0.04 * ((k * 5) % 4) / 3)]);
        }
        return out;
    }

    function ring(w, h, u, t) {
        const pulse = 1 + 0.14 * Math.sin(t * 2);
        const out = [[w / 2, h / 2, u * (0.08 + 0.03 * Math.sin(t * 2 + 1))]];
        for (let k = 1; k < 8; k++) {
            const ang = t * 0.4 + k / 7 * Math.PI * 2;
            out.push([w / 2 + Math.cos(ang) * u * 0.3 * pulse * 1.3, h / 2 + Math.sin(ang) * u * 0.3 * pulse, u * 0.075]);
        }
        return out;
    }

    function layoutBlobs() {
        const w = width, h = height;
        if (w <= 0)
            return;
        const u = Math.min(w, h), t = time;
        const layouts = [orbit, snake, rain, ring];
        const a = layouts[sceneIndex](w, h, u, t);
        // In the last moments of a scene the drops glide into the next layout
        const mix = smooth((sceneTime - (sceneLength - blendLength)) / blendLength);
        const b = mix > 0 ? layouts[(sceneIndex + 1) % 4](w, h, u, t) : a;
        const v = a.map((p, i) => Qt.vector4d(p[0] + (b[i][0] - p[0]) * mix, p[1] + (b[i][1] - p[1]) * mix, p[2] + (b[i][2] - p[2]) * mix, 0));
        b0 = v[0]; b1 = v[1]; b2 = v[2]; b3 = v[3]; b4 = v[4]; b5 = v[5]; b6 = v[6]; b7 = v[7];
    }

    // ---- what the glass sits on ------------------------------------------------------------------

    Item {
        id: scene
        anchors.fill: parent

        Canvas {
            id: backdrop
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject
            renderStrategy: Canvas.Threaded
            property real sinceFrame: 0

            Connections {
                target: root
                function onTimeChanged() {
                    // About 60 fps whatever the display rate
                    if (root.time - backdrop.sinceFrame >= 0.0155) {
                        backdrop.sinceFrame = root.time;
                        backdrop.requestPaint();
                    }
                }
            }

            onPaint: {
                const ctx = getContext("2d");
                const w = width, h = height, u = Math.min(w, h), t = root.time;
                const hsl = (o, s, l, a) => `hsla(${Math.round((((root.hue + o) % 1) + 1) % 1 * 360)}, ${s}%, ${l}%, ${a})`;
                ctx.globalCompositeOperation = "source-over";
                ctx.fillStyle = hsl(0, 45, 9, 1);
                ctx.fillRect(0, 0, w, h);
                // Big saturated lights drifting about
                for (let k = 0; k < 6; k++) {
                    const x = w * (0.5 + 0.42 * Math.sin(t * 0.17 + k * 1.9));
                    const y = h * (0.5 + 0.4 * Math.cos(t * 0.13 + k * 2.3));
                    const r = u * (0.5 + 0.12 * Math.sin(t * 0.4 + k));
                    const g = ctx.createRadialGradient(x, y, 0, x, y, r);
                    g.addColorStop(0, hsl(k * 0.17, 95, 58, 0.95));
                    g.addColorStop(1, hsl(k * 0.17, 95, 50, 0));
                    ctx.fillStyle = g;
                    ctx.fillRect(0, 0, w, h);
                }
                // A fine grid and dots: they make the bending of the glass easy to see
                ctx.strokeStyle = "rgba(255, 255, 255, 0.16)";
                ctx.lineWidth = 2;
                const cell = u / 12;
                ctx.beginPath();
                for (let x = (t * 6) % cell; x < w; x += cell) {
                    ctx.moveTo(x, 0);
                    ctx.lineTo(x, h);
                }
                for (let y = 0; y < h; y += cell) {
                    ctx.moveTo(0, y);
                    ctx.lineTo(w, y);
                }
                ctx.stroke();
                ctx.fillStyle = "rgba(255, 255, 255, 0.5)";
                for (let x = (t * 6) % cell; x < w; x += cell)
                    for (let y = 0; y < h; y += cell)
                        ctx.fillRect(x - 2, y - 2, 4, 4);
            }
        }

        LetterCaption {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height * 0.5 - height * 0.5
            text: root.captions[root.sceneIndex]
            time: root.time
            sceneTime: root.sceneTime
            sceneLength: root.sceneLength
            hue: root.hue
            fontSize: Math.min(130, root.height / 8)
        }
    }

    ShaderEffectSource {
        id: sceneTexture
        sourceItem: scene
        hideSource: true
        live: true
        smooth: true
    }

    ShaderEffect {
        anchors.fill: parent
        property variant src: sceneTexture
        property vector2d res: Qt.vector2d(width, height)
        property vector4d b0: root.b0
        property vector4d b1: root.b1
        property vector4d b2: root.b2
        property vector4d b3: root.b3
        property vector4d b4: root.b4
        property vector4d b5: root.b5
        property vector4d b6: root.b6
        property vector4d b7: root.b7
        fragmentShader: Qt.resolvedUrl("glass.frag.qsb")
    }
}
