import QtQuick
import QtQuick.Effects
import qs.common

// A keynote headline: white text, or (with `colors`) text filled with a gradient that slowly
// slides along the line. `shown` (0..1) fades it in while it rises and settles from a slight zoom;
// `kick` makes it pop on the beat, `shine` sweeps a band of light across it.
Item {
    id: root

    property string text: ""
    property real size: 64
    property int weight: Font.Bold
    property color color: "white"
    // Two or more colors turn the gradient fill on
    property var colors: []
    property real shown: 1
    property real time: 0
    property real letterSpacing: -size * 0.02
    // 0..1 on the music's beat: the line pops a little
    property real kick: 0
    // A band of light sweeping across the letters as it goes 0 -> 1 (outside 0..1: none)
    property real shine: -1

    readonly property bool shining: shine > 0 && shine < 1

    readonly property bool gradient: colors.length > 1

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    opacity: shown
    transform: Translate { y: (1 - root.shown) * root.size * 0.45 }
    scale: (1.04 - 0.04 * root.shown) * (1 + 0.045 * root.kick)

    Text {
        id: label
        text: root.text
        color: root.color
        font.family: Appearance.font.title
        font.pixelSize: root.size
        font.weight: root.weight
        font.letterSpacing: root.letterSpacing
        horizontalAlignment: Text.AlignHCenter
        visible: !root.gradient
        layer.enabled: root.gradient || root.shining
    }

    Rectangle {
        id: fill
        anchors.fill: label
        visible: false
        layer.enabled: root.gradient
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.colors[0] ?? "white" }
            GradientStop { position: 0.5 + 0.35 * Math.sin(root.time * 0.6); color: root.colors[1] ?? "white" }
            GradientStop { position: 1; color: root.colors[2] ?? root.colors[0] ?? "white" }
        }
    }

    MultiEffect {
        anchors.fill: label
        visible: root.gradient
        source: fill
        maskEnabled: true
        maskSource: label
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    Item {
        id: band
        anchors.fill: label
        visible: false
        layer.enabled: root.shining

        Rectangle {
            width: parent.width * 0.28
            height: parent.height * 2
            anchors.verticalCenter: parent.verticalCenter
            x: -width + (parent.width + width * 2) * root.shine
            rotation: 18
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: "white" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }

    MultiEffect {
        anchors.fill: label
        visible: root.shining
        source: band
        maskEnabled: true
        maskSource: label
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
        brightness: 0.3
    }
}
