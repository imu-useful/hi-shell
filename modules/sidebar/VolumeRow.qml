import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs.common
import qs.common.widgets

// Slider row for a PipeWire node: mute button (or app icon), slider, percent.
RowLayout {
    id: root

    required property PwNode node
    property string icon: "volume_up"
    property string iconSource: ""
    property string label: ""

    readonly property var audio: node?.audio ?? null

    spacing: 8

    PwObjectTracker {
        objects: [root.node]
    }

    IconButton {
        visible: root.iconSource === ""
        icon: root.audio?.muted ? (root.icon.startsWith("mic") ? "mic_off" : "volume_off") : root.icon
        onClicked: if (root.audio) root.audio.muted = !root.audio.muted
    }
    IconImage {
        visible: root.iconSource !== ""
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        implicitSize: 24
        source: root.iconSource
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        StyledText {
            visible: root.label !== ""
            Layout.fillWidth: true
            text: root.label
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        M3Slider {
            Layout.fillWidth: true
            implicitHeight: root.label ? 28 : 40
            value: root.audio ? Math.min(1, root.audio.volume) : 0
            opacity: root.audio?.muted ? 0.5 : 1
            onMoved: value => {
                if (root.audio) {
                    root.audio.volume = value;
                    root.audio.muted = false;
                }
            }
        }
    }

    StyledText {
        Layout.preferredWidth: 38
        horizontalAlignment: Text.AlignRight
        text: root.audio ? `${Math.round(root.audio.volume * 100)}%` : ""
        font.pixelSize: Appearance.font.size.labelMedium
        font.features: { "tnum": 1 }
        color: Colors.m3onSurfaceVariant
    }
}
