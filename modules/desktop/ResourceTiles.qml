import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// CPU / RAM / battery-or-disk tiles.
Row {
    spacing: 10

    Repeater {
        model: [
            { icon: "memory", label: "CPU", value: SystemStats.cpuUsage, shape: "cookie9", tone: 0 },
            { icon: "memory_alt", label: "RAM", value: SystemStats.memUsage, shape: "clover4", tone: 1 },
            Battery.available
                ? { icon: Battery.icon, label: "Battery", value: Battery.percentage, shape: "flower", tone: 2 }
                : { icon: "hard_drive", label: "Disk", value: SystemStats.diskUsage, shape: "flower", tone: 2 }
        ]

        DesktopCard {
            required property var modelData
            readonly property color accent: [Colors.m3primaryContainer, Colors.m3secondaryContainer, Colors.m3tertiaryContainer][modelData.tone]
            readonly property color ink: [Colors.m3onPrimaryContainer, Colors.m3onSecondaryContainer, Colors.m3onTertiaryContainer][modelData.tone]

            width: 116
            height: 116
            baseColor: accent

            Item {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                width: 36
                height: 36
                MaterialShape {
                    anchors.fill: parent
                    shape: modelData.shape
                    color: ink
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    icon: modelData.icon
                    fill: 1
                    iconSize: 18
                    color: accent
                }
            }

            ColumnLayout {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 14
                spacing: -2
                StyledText {
                    text: `${Math.round(modelData.value * 100)}%`
                    font.family: Appearance.font.title
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                    color: ink
                }
                StyledText {
                    text: modelData.label
                    font.pixelSize: Appearance.font.size.labelMedium
                    color: Qt.alpha(ink, 0.8)
                }
            }
        }
    }
}
