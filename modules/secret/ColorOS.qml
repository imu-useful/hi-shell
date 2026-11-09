import QtQuick
import qs.common
import qs.common.widgets

// Keys "coloros", "color os", "oppo" and "aquamorphic": a silent show in an airy, water-like style.
// One shader (coloros.frag) draws a flowing pastel gradient, rings of ripples, rising water and
// glossy drops that bend what is behind them; this file sets the scenes (which of those show, and
// where the drops are) and blends from one to the next. The caption is the same letter-by-letter one.
Item {
    id: root

    required property bool revealed
    property real time: 0

    readonly property real sceneLength: 7
    readonly property real blendLength: 1.2
    readonly property real cycle: sceneLength * 4
    readonly property int sceneIndex: Math.floor((time % cycle) / sceneLength)
    readonly property real sceneTime: (time % cycle) - sceneIndex * sceneLength
    readonly property var captions: ["ColorOS", Translation.tr("Aquamorphic"), Translation.tr("Smooth as water"), Translation.tr("Made for you")]
    // What each scene shows: ripples, water
    readonly property var rippleAmount: [1, 0.3, 0.5, 0.8]
    readonly property var waterAmount: [0, 0, 1, 0.1]

    property real baseHue: 0.55
    readonly property real hue: baseHue + time * 0.02
    property real ripples: 1
    property real waves: 0
    property vector4d b0; property vector4d b1; property vector4d b2; property vector4d b3
    property vector4d b4; property vector4d b5; property vector4d b6; property vector4d b7

    Component.onCompleted: {
        const h = Colors.m3primary.hslHue;
        baseHue = h >= 0 ? h : 0.55;
    }

    FrameAnimation {
        running: root.revealed
        onTriggered: {
            root.time += frameTime;
            root.layout();
        }
    }

    function clamp(x) {
        return Math.max(0, Math.min(1, x));
    }

    function smooth(x) {
        const t = clamp(x);
        return t * t * (3 - 2 * t);
    }

    // ---- the drops, 8 per layout as [x, y, radius]; a radius of 0 hides one -----------------------

    function pad(list) {
        const last = list[list.length - 1];
        while (list.length < 8)
            list.push([last[0], last[1], 0]);
        return list;
    }

    function floating(w, h, u, t) {
        return pad([0, 1, 2].map(k => {
            const a = t * 0.25 + k * 2.1;
            return [w / 2 + Math.cos(a) * u * 0.55, h * 0.45 + Math.sin(a) * u * 0.3, u * (0.07 + 0.02 * k)];
        }));
    }

    function rising(w, h, u, t) {
        const out = [];
        for (let k = 0; k < 8; k++) {
            const speed = 0.06 + (k % 3) * 0.012;
            out.push([w * (0.1 + ((k * 0.37) % 1) * 0.8) + Math.sin(t * 0.9 + k) * u * 0.04, h * (1.12 - ((t * speed + k * 0.13) % 1.25)), u * (0.05 + 0.045 * ((k * 5) % 4) / 3)]);
        }
        return out;
    }

    function bobbing(w, h, u, t) {
        return pad([0, 1, 2, 3].map(k => [w * (0.2 + k * 0.2), h / 2 + u * 0.14 + Math.sin(t * 1.3 + k * 1.7) * u * 0.05, u * 0.06]));
    }

    function ring(w, h, u, t) {
        const out = [];
        for (let k = 0; k < 8; k++) {
            const a = t * 0.35 + k / 8 * Math.PI * 2;
            const pulse = 1 + 0.1 * Math.sin(t * 2);
            out.push([w / 2 + Math.cos(a) * u * 0.34 * pulse * 1.25, h * 0.46 + Math.sin(a) * u * 0.34 * pulse, u * 0.07]);
        }
        return out;
    }

    function layout() {
        const w = width, h = height;
        if (w <= 0)
            return;
        const u = Math.min(w, h), t = time, i = sceneIndex;
        const layouts = [floating, rising, bobbing, ring];
        const a = layouts[i](w, h, u, t);
        // In the last moments of a scene everything glides into the next one
        const mix = smooth((sceneTime - (sceneLength - blendLength)) / blendLength);
        const n = (i + 1) % 4;
        const b = mix > 0 ? layouts[n](w, h, u, t) : a;
        const v = a.map((p, k) => Qt.vector4d(p[0] + (b[k][0] - p[0]) * mix, p[1] + (b[k][1] - p[1]) * mix, p[2] + (b[k][2] - p[2]) * mix, 0));
        b0 = v[0]; b1 = v[1]; b2 = v[2]; b3 = v[3]; b4 = v[4]; b5 = v[5]; b6 = v[6]; b7 = v[7];
        ripples = rippleAmount[i] + (rippleAmount[n] - rippleAmount[i]) * mix;
        waves = waterAmount[i] + (waterAmount[n] - waterAmount[i]) * mix;
    }

    ShaderEffect {
        anchors.fill: parent
        property vector2d res: Qt.vector2d(width, height)
        property real time: root.time
        property real ripples: root.ripples
        property real waves: root.waves
        property color c0: Qt.hsla(root.hue % 1, 0.7, 0.8, 1)
        property color c1: Qt.hsla((root.hue + 0.08) % 1, 0.65, 0.84, 1)
        property color c2: Qt.hsla((root.hue + 0.38) % 1, 0.6, 0.86, 1)
        property vector4d b0: root.b0
        property vector4d b1: root.b1
        property vector4d b2: root.b2
        property vector4d b3: root.b3
        property vector4d b4: root.b4
        property vector4d b5: root.b5
        property vector4d b6: root.b6
        property vector4d b7: root.b7
        fragmentShader: Qt.resolvedUrl("coloros.frag.qsb")
    }

    LetterCaption {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.4 - height * 0.5
        text: root.captions[root.sceneIndex]
        time: root.time
        sceneTime: root.sceneTime
        sceneLength: root.sceneLength
        hue: root.hue
        fontSize: Math.min(130, root.height / 8)
        saturation: 0.7
        lightness: 0.27
    }
}
