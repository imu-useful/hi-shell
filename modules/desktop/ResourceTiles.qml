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
        // Keys only: a model holding the values would recreate the tiles on every update.
        model: ["cpu", "ram", Battery.available ? "battery" : "disk"]

        DesktopCard {
            id: tile
            required property string modelData
            readonly property var info: ({
                cpu: { icon: "memory", label: Translation.tr("CPU"), value: SystemStats.cpuUsage, shape: "cookie9", tone: 0 },
                ram: { icon: "memory_alt", label: Translation.tr("RAM"), value: SystemStats.memUsage, shape: "clover4", tone: 1 },
                battery: { icon: Battery.icon, label: Translation.tr("Battery"), value: Battery.percentage, shape: "flower", tone: 2 },
                disk: { icon: "hard_drive", label: Translation.tr("Disk"), value: SystemStats.diskUsage, shape: "flower", tone: 2 }
            })[modelData]
            property real shown: info.value
            Behavior on shown { EffectAnim { duration: Appearance.anim.slow } }
            readonly property color accent: [Colors.m3primaryContainer, Colors.m3secondaryContainer, Colors.m3tertiaryContainer][tile.info.tone]
            readonly property color ink: [Colors.m3onPrimaryContainer, Colors.m3onSecondaryContainer, Colors.m3onTertiaryContainer][tile.info.tone]

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
                    shape: tile.info.shape
                    color: ink
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    icon: tile.info.icon
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
                    text: `${Math.round(tile.shown * 100)}%`
                    font.family: Appearance.font.title
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                    color: ink
                }
                StyledText {
                    text: tile.info.label
                    font.pixelSize: Appearance.font.size.labelMedium
                    color: Qt.alpha(ink, 0.8)
                }
            }
        }
    }
}
