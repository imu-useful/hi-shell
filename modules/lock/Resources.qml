import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// Processor, memory and disk use, each a Material shape with its percentage.
Tile {
    id: root

    implicitHeight: row.implicitHeight + Appearance.space.xl * 2

    RowLayout {
        id: row
        anchors.centerIn: parent
        width: parent.width - Appearance.space.xl * 2
        spacing: Appearance.space.lg

        Repeater {
            model: [
                { icon: "memory", shape: "cookie9", value: "cpu", tone: 0 },
                { icon: "memory_alt", shape: "clover4", value: "mem", tone: 1 },
                { icon: "hard_drive", shape: "flower", value: "disk", tone: 2 }
            ]

            Item {
                id: tile
                required property var modelData
                readonly property real used: modelData.value === "cpu" ? SystemStats.cpuUsage
                    : modelData.value === "mem" ? SystemStats.memUsage : SystemStats.diskUsage
                readonly property color fill: [Colors.m3primaryContainer, Colors.m3secondaryContainer, Colors.m3tertiaryContainer][modelData.tone]
                readonly property color ink: [Colors.m3onPrimaryContainer, Colors.m3onSecondaryContainer, Colors.m3onTertiaryContainer][modelData.tone]

                Layout.fillWidth: true
                implicitHeight: width

                MaterialShape {
                    anchors.fill: parent
                    shape: tile.modelData.shape
                    color: tile.fill
                }
                Column {
                    anchors.centerIn: parent
                    spacing: -2
                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        icon: tile.modelData.icon
                        iconSize: Math.max(16, tile.width * 0.22)
                        color: tile.ink
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: `${Math.round(tile.used * 100)}%`
                        color: tile.ink
                        font.family: Appearance.font.title
                        font.pixelSize: Math.max(12, tile.width * 0.24)
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }
}
