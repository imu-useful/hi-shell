import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.common
import qs.common.widgets
import qs.services

// Volume, brightness (focused screen) and microphone sliders.
ColumnLayout {
    id: root

    signal openPage(string page)

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property var screen: Brightness.focused

    spacing: 2

    RowLayout {
        Layout.fillWidth: true
        spacing: 0

        VolumeRow {
            Layout.fillWidth: true
            node: root.sink
            icon: "volume_up"
        }
        IconButton {
            icon: "tune"
            tooltip: Translation.tr("Apps and devices")
            onClicked: root.openPage("audio")
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.screen?.available ?? false
        spacing: 8

        IconButton {
            icon: "brightness_medium"
            enabled: false
            opacity: 1
        }
        M3Slider {
            Layout.fillWidth: true
            value: root.screen?.brightness ?? 0
            onMoved: value => root.screen.set(value)
        }
        StyledText {
            Layout.preferredWidth: 38
            Layout.rightMargin: 40
            horizontalAlignment: Text.AlignRight
            text: `${Math.round((root.screen?.brightness ?? 0) * 100)}%`
            font.pixelSize: Appearance.font.size.labelMedium
            font.features: { "tnum": 1 }
            color: Colors.m3onSurfaceVariant
        }
    }

    VolumeRow {
        Layout.fillWidth: true
        Layout.rightMargin: 40
        visible: root.source !== null
        node: root.source
        icon: "mic"
    }
}
