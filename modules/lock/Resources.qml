import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Top left: processor, memory and disk use as small rings.
Tile {
    implicitWidth: row.implicitWidth + Appearance.space.lg * 2
    implicitHeight: 48

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Appearance.space.lg

        Repeater {
            model: [
                { icon: "memory", key: "cpu" },
                { icon: "memory_alt", key: "mem" },
                { icon: "hard_drive", key: "disk" }
            ]

            Row {
                id: item
                required property var modelData
                spacing: Appearance.space.sm
                readonly property real used: modelData.key === "cpu" ? SystemStats.cpuUsage
                    : modelData.key === "mem" ? SystemStats.memUsage : SystemStats.diskUsage

                CircularProgress {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 28
                    implicitHeight: 28
                    lineWidth: 3
                    value: parent.used
                    MaterialIcon { anchors.centerIn: parent; icon: item.modelData.icon; iconSize: 14; color: Colors.m3primary }
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${Math.round(parent.used * 100)}%`
                    font.pixelSize: Appearance.font.size.labelMedium
                }
            }
        }
    }
}
