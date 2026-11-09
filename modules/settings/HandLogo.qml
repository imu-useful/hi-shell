import QtQuick
import QtQuick.Effects
import Quickshell
import qs.common

// The hi-shell hand, tinted from the palette (it follows the wallpaper like everything else), with
// the arcs that pulse as it waves. wave() swings the hand out and back a few times, settling down.
// `size` is the width of the hand and arcs together.
Item {
    id: root

    property real size: 60
    property color color: Colors.m3onPrimaryContainer
    property color arcColor: Colors.m3tertiary

    // The logo layers are 360x327 pictures on one canvas; the hand and the arcs occupy x 85..285,
    // y 18..178 of it, and the wrist (what the hand turns around) is at (165, 172).
    readonly property real unit: size / 200
    readonly property real layerW: 360 * unit
    readonly property real layerH: 327 * unit

    property real angle: 0 // the hand turned about the wrist (waving, the shaka)
    property real spin: 0 // a whole turn about its middle
    property real flip: 0 // 0..180 turns it over: the back of the hand (the reversed hand)
    property real lift: 0 // how high it is off the ground (in 1/200ths of its width)
    property real squash: 1 // < 1: squashed on landing, stretched in the air
    property real arcsOpacity: 0
    property real arcsPush: 0

    implicitWidth: size
    implicitHeight: 160 * unit

    function wave(): void {
        swing.restart();
    }

    readonly property var gestures: ["wave", "shaka", "flip", "jump", "spin"]

    // A gesture by name: wave, shaka (tilted and shaken, "call me"), flip (turned over to show the
    // back of the hand), jump (a hop with a squash on landing), spin (a full turn)
    function play(name: string): void {
        if (name === "wave") {
            swing.restart();
            return;
        }
        arcsFlash.restart();
        ({ shaka: shakaAnim, flip: flipAnim, jump: jumpAnim, spin: spinAnim })[name]?.restart();
    }

    // One swing of the hand to `target`; the arcs flash to `flash` and slide out when it swings right.
    component Swing: ParallelAnimation {
        id: one
        property real target: 0
        property real flash: 1
        NumberAnimation { target: root; property: "angle"; to: one.target; duration: 240; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "arcsOpacity"; to: one.flash; duration: 240; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "arcsPush"; to: one.target > 0 ? 8 : 0; duration: 240; easing.type: Easing.OutCubic }
    }

    Image {
        id: handImage
        visible: false
        source: Quickshell.shellPath("common/icons/logo-hand.png")
        sourceSize: Qt.size(root.layerW * 2, root.layerH * 2)
        smooth: true
    }

    Image {
        id: arcsImage
        visible: false
        source: Quickshell.shellPath("common/icons/logo-arcs.png")
        sourceSize: Qt.size(root.layerW * 2, root.layerH * 2)
        smooth: true
    }

    // Both layers share the canvas, so they are placed by the same offset
    Item {
        anchors.centerIn: parent
        width: 200 * root.unit
        height: 160 * root.unit

        MultiEffect {
            x: -85 * root.unit
            y: -18 * root.unit
            width: root.layerW
            height: root.layerH
            source: arcsImage
            colorization: 1
            colorizationColor: root.arcColor
            opacity: root.arcsOpacity
            transform: Translate { x: root.arcsPush * root.unit }
        }

        MultiEffect {
            x: -85 * root.unit
            y: -18 * root.unit
            width: root.layerW
            height: root.layerH
            source: handImage
            colorization: 1
            colorizationColor: root.color
            transform: [
                Rotation {
                    origin.x: 165 * root.unit
                    origin.y: 172 * root.unit
                    angle: root.angle
                },
                Rotation {
                    origin.x: 162 * root.unit
                    origin.y: 98 * root.unit
                    angle: root.spin
                },
                Rotation {
                    origin.x: 162 * root.unit
                    origin.y: 98 * root.unit
                    axis { x: 0; y: 1; z: 0 }
                    angle: root.flip
                },
                Scale {
                    origin.x: 162 * root.unit
                    origin.y: 176 * root.unit
                    xScale: 2 - root.squash
                    yScale: root.squash
                },
                Translate { y: -root.lift * root.unit }
            ]
        }
    }

    SequentialAnimation {
        id: swing
        Swing { target: 16; flash: 1 }
        Swing { target: -9; flash: 0.7 }
        Swing { target: 13; flash: 1 }
        Swing { target: -6; flash: 0.6 }
        Swing { target: 8; flash: 0.8 }
        Swing { target: 0; flash: 0 }
    }

    // The arcs flash once for the gestures that don't drive them themselves
    SequentialAnimation {
        id: arcsFlash
        NumberAnimation { target: root; property: "arcsOpacity"; to: 1; duration: 150; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "arcsOpacity"; to: 0; duration: 650; easing.type: Easing.InOutCubic }
    }

    // 🤙: tips over, shakes from side to side, settles back
    SequentialAnimation {
        id: shakaAnim
        NumberAnimation { target: root; property: "angle"; to: -38; duration: 220; easing.type: Easing.OutBack }
        SequentialAnimation {
            loops: 3
            NumberAnimation { target: root; property: "angle"; to: -56; duration: 85; easing.type: Easing.InOutSine }
            NumberAnimation { target: root; property: "angle"; to: -20; duration: 85; easing.type: Easing.InOutSine }
        }
        PauseAnimation { duration: 80 }
        NumberAnimation { target: root; property: "angle"; to: 0; duration: 320; easing.type: Easing.OutBack }
    }

    // 🖑: turns over to show the back of the hand, holds, turns back
    SequentialAnimation {
        id: flipAnim
        NumberAnimation { target: root; property: "flip"; to: 180; duration: 420; easing.type: Easing.OutBack }
        PauseAnimation { duration: 650 }
        NumberAnimation { target: root; property: "flip"; to: 360; duration: 420; easing.type: Easing.InOutCubic }
        ScriptAction { script: root.flip = 0 }
    }

    // A hop: stretches going up, squashes on landing and springs back
    SequentialAnimation {
        id: jumpAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "lift"; to: 26; duration: 230; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "squash"; to: 1.12; duration: 230; easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "lift"; to: 0; duration: 220; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "squash"; to: 1; duration: 220 }
        }
        NumberAnimation { target: root; property: "squash"; to: 0.78; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "squash"; to: 1; duration: 380; easing.type: Easing.OutElastic; easing.amplitude: 1.2; easing.period: 0.4 }
    }

    // A whole turn
    SequentialAnimation {
        id: spinAnim
        NumberAnimation { target: root; property: "spin"; from: 0; to: 360; duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        ScriptAction { script: root.spin = 0 }
    }
}
