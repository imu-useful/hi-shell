import QtQuick
import Quickshell

// The hi-shell logo (light version, for dark backgrounds) in three layers: the name comes in,
// the hand fades in and waves, the blue arcs pulse with each wave. `playing` starts it.
Item {
    id: root

    property bool playing: false

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
        opacity: root.playing ? 1 : 0
        y: root.playing ? 0 : 14 * root.unit
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    }

    Layer {
        id: hand
        name: "hand"
        opacity: root.playing ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        transform: Rotation {
            id: wave
            origin.x: root.wrist.x * root.unit
            origin.y: root.wrist.y * root.unit
            angle: 0
        }
    }

    Layer {
        id: arcs
        name: "arcs"
        opacity: 0
        property real push: 0
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
        running: root.playing
        PauseAnimation { duration: 450 }
        Swing { angle: 16; flash: 1 }
        Swing { angle: -9; flash: 0.7 }
        Swing { angle: 13; flash: 1 }
        Swing { angle: -6; flash: 0.6 }
        Swing { angle: 8; flash: 0.8 }
        Swing { angle: 0; flash: 0.4 }
    }
}
