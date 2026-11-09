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

    property real angle: 0
    property real arcsOpacity: 0
    property real arcsPush: 0

    implicitWidth: size
    implicitHeight: 160 * unit

    function wave(): void {
        swing.restart();
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
            transform: Rotation {
                origin.x: 165 * root.unit
                origin.y: 172 * root.unit
                angle: root.angle
            }
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
}
