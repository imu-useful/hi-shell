import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Top left: processor, memory and disk use as small rings.
Tile {
    implicitWidth: row.implicitWidth + Appearance.space.lg * 2
    implicitHeight: 48

    HoverHandler {
        id: hover
    }

    function gib(v) {
        return `${v.toFixed(1)} ${Translation.tr("GiB")}`;
    }

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

    Detail {
        anchors.top: parent.bottom
        anchors.topMargin: Appearance.space.sm
        anchors.left: parent.left
        pillHovered: hover.hovered

        DetailRow { label: Translation.tr("Processor"); value: `${Math.round(SystemStats.cpuUsage * 100)}%${SystemStats.cpuTemp >= 0 ? ` · ${Math.round(SystemStats.cpuTemp)}°C` : ""}` }
        DetailRow { label: Translation.tr("Memory"); value: `${gib(SystemStats.memUsedGiB)} / ${gib(SystemStats.memTotalGiB)}` }
        DetailRow { visible: SystemStats.swapTotalGiB > 0; label: Translation.tr("Swap"); value: `${gib(SystemStats.swapUsedGiB)} / ${gib(SystemStats.swapTotalGiB)}` }
        DetailRow { label: Translation.tr("Disk"); value: `${gib(SystemStats.diskUsedGiB)} / ${gib(SystemStats.diskTotalGiB)}` }
        DetailRow { visible: SystemStats.gpuUsage >= 0; label: Translation.tr("Graphics"); value: `${Math.round(SystemStats.gpuUsage * 100)}%${SystemStats.gpuTemp >= 0 ? ` · ${Math.round(SystemStats.gpuTemp)}°C` : ""}` }
        DetailRow { label: Translation.tr("Uptime"); value: SystemStats.uptimeText }
    }
}
