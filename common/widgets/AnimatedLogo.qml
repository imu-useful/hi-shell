import QtQuick
import Quickshell

// The hi-shell logo (light version, for dark backgrounds) in three layers: the name comes in,
// the hand fades in and waves, the blue arcs pulse with each wave. `playing` starts it.
Item {
    id: root

    property bool playing: false
    // When >= 0, the animation follows this clock (seconds since it began playing) instead of running
    // on its own: for rendering it frame by frame (the keynote video)
    property real clock: -1
    readonly property bool driven: clock >= 0

    // The wave as keyframes: [hand angle, arcs flash], a swing every 0.26 s after a 0.45 s pause
    readonly property var swings: [[16, 1], [-9, 0.7], [13, 1], [-6, 0.6], [8, 0.8], [0, 0.4]]

    function out(x: real): real {
        const c = Math.max(0, Math.min(1, x));
        return 1 - Math.pow(1 - c, 3);
    }

    // [angle, flash, push] of the wave at `clock`
    function waveAt(c: real): var {
        const i = Math.floor((c - 0.45) / 0.26);
        if (i < 0)
            return [0, 0, 0];
        if (i >= swings.length)
            return [0, 0.4, 0];
        const f = (c - 0.45 - i * 0.26) / 0.26;
        const from = i > 0 ? swings[i - 1] : [0, 0];
        const to = swings[i];
        const sine = 0.5 - 0.5 * Math.cos(Math.PI * f);
        const pushFrom = from[0] > 0 ? 8 : 0, pushTo = to[0] > 0 ? 8 : 0;
        return [from[0] + (to[0] - from[0]) * sine, from[1] + (to[1] - from[1]) * out(f), pushFrom + (pushTo - pushFrom) * out(f)];
    }
    readonly property var waveNow: driven ? waveAt(clock) : [0, 0, 0]

    // The layers are 360x327 images with the same canvas; this is that size scaled to `height`.
    readonly property real sourceWidth: 360
    readonly property real sourceHeight: 327
    readonly property real unit: height / sourceHeight
    // Where the wrist is, the hand turns around it (source pixels)
    readonly property point wrist: Qt.point(165, 172)

    implicitHeight: 150
    width: sourceWidth * unit

    component Layer: Image {
        required property string name
        anchors.fill: parent
        source: Quickshell.shellPath(`common/icons/logo-${name}.png`)
        sourceSize: Qt.size(root.sourceWidth * root.unit * 2, root.height * 2)
        smooth: true
    }

    Layer {
        name: "word"
        opacity: root.driven ? root.out(root.clock / 0.6) : root.playing ? 1 : 0
        y: root.driven ? (1 - root.out(root.clock / 0.7)) * 14 * root.unit : root.playing ? 0 : 14 * root.unit
        Behavior on opacity { enabled: !root.driven; NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: !root.driven; NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    }

    Layer {
        id: hand
        name: "hand"
        opacity: root.driven ? root.out(root.clock / 0.5) : root.playing ? 1 : 0
        Behavior on opacity { enabled: !root.driven; NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        transform: Rotation {
            id: wave
            origin.x: root.wrist.x * root.unit
            origin.y: root.wrist.y * root.unit
            angle: root.driven ? root.waveNow[0] : 0
        }
    }

    Layer {
        id: arcs
        name: "arcs"
        opacity: root.driven ? root.waveNow[1] : 0
        property real push: root.driven ? root.waveNow[2] : 0
        transform: Translate { x: arcs.push * root.unit }
    }

    // One swing of the hand to `angle`; the arcs flash to `flash` and slide out when it swings right.
    component Swing: ParallelAnimation {
        property real angle: 0
        property real flash: 1
        NumberAnimation {
            target: wave; property: "angle"; to: angle
            duration: 260; easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: arcs; property: "opacity"; to: flash
            duration: 260; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: arcs; property: "push"; to: angle > 0 ? 8 : 0
            duration: 260; easing.type: Easing.OutCubic
        }
    }

    // Wave: the hand swings out and back a few times, settling down.
    SequentialAnimation {
        running: root.playing && !root.driven
        PauseAnimation { duration: 450 }
        Swing { angle: 16; flash: 1 }
        Swing { angle: -9; flash: 0.7 }
        Swing { angle: 13; flash: 1 }
        Swing { angle: -6; flash: 0.6 }
        Swing { angle: 8; flash: 0.8 }
        Swing { angle: 0; flash: 0.4 }
    }
}
