import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.common
import qs.common.widgets

// Per-app volume and output / input device selection.
StyledFlickable {
    id: root

    readonly property list<PwNode> nodes: Pipewire.nodes.values.filter(n => n.audio !== null)
    readonly property list<PwNode> streams: nodes.filter(n => n.isStream && n.properties["media.class"] === "Stream/Output/Audio")
    readonly property list<PwNode> sinks: nodes.filter(n => !n.isStream && n.properties["media.class"] === "Audio/Sink")
    readonly property list<PwNode> sources: nodes.filter(n => !n.isStream && n.properties["media.class"] === "Audio/Source")

    function appName(node) {
        const p = node.properties;
        return p["application.name"] || node.description || node.name;
    }
    function appIcon(node) {
        const p = node.properties;
        const name = p["application.icon-name"] || p["application.process.binary"] || "";
        return name ? Quickshell.iconPath(name, true) : "";
    }

    contentHeight: column.implicitHeight

    PwObjectTracker {
        objects: root.nodes
    }

    component Section: StyledText {
        Layout.topMargin: 8
        font.pixelSize: Appearance.font.size.labelMedium
        font.weight: Font.Medium
        color: Colors.m3primary
    }

    component DeviceList: ColumnLayout {
        id: list
        property list<PwNode> devices: []
        property PwNode current: null
        signal picked(PwNode node)
        Layout.fillWidth: true
        spacing: 0

        Repeater {
            model: list.devices

            ListRow {
                required property PwNode modelData
                Layout.fillWidth: true
                implicitHeight: 44
                icon: modelData === list.current ? "radio_button_checked" : "radio_button_unchecked"
                title: modelData.description || modelData.nickname || modelData.name
                clickable: true
                onClicked: list.picked(modelData)
            }
        }
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: 4

        Section { text: "Apps" }
        StyledText {
            visible: root.streams.length === 0
            text: "No apps are playing audio"
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        Repeater {
            model: root.streams

            VolumeRow {
                required property PwNode modelData
                Layout.fillWidth: true
                node: modelData
                label: root.appName(modelData)
                iconSource: root.appIcon(modelData)
                icon: "music_note"
            }
        }

        Section { text: "Output" }
        DeviceList {
            devices: root.sinks
            current: Pipewire.defaultAudioSink
            onPicked: node => Pipewire.preferredDefaultAudioSink = node
        }

        Section { text: "Input" }
        DeviceList {
            devices: root.sources
            current: Pipewire.defaultAudioSource
            onPicked: node => Pipewire.preferredDefaultAudioSource = node
        }
    }
}
