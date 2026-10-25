import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Resource rings (bar.resources.shown: cpu, ram, swap, gpu, disk) with a
// details popup.
BarWidget {
    id: root

    readonly property var all: ({
        cpu: { icon: "memory", value: SystemStats.cpuUsage },
        ram: { icon: "memory_alt", value: SystemStats.memUsage },
        swap: { icon: "swap_horiz", value: SystemStats.swapUsage },
        gpu: { icon: "developer_board", value: Math.max(0, SystemStats.gpuUsage) },
        disk: { icon: "hard_drive", value: SystemStats.diskUsage }
    })
    // Keys only: a model holding the values would recreate the rings on every update.
    readonly property var keys: Config.options.bar.resources.shown.filter(k => ["cpu", "ram", "swap", "gpu", "disk"].includes(k))

    padding: 8
    contentWidth: grid.implicitWidth
    contentHeight: grid.implicitHeight

    Grid {
        id: grid
        anchors.centerIn: parent
        columns: root.vertical ? 1 : root.keys.length
        spacing: root.vertical ? 6 : 10

        Repeater {
            model: root.keys

            Grid {
                id: item
                required property string modelData
                readonly property var info: root.all[modelData]
                columns: root.vertical ? 1 : 2
                spacing: 4
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter

                CircularProgress {
                    implicitWidth: 20
                    implicitHeight: 20
                    value: item.info.value
                    animated: false
                    color: item.info.value > 0.9 ? Colors.m3error : Colors.m3primary

                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: item.info.icon
                        iconSize: 12
                        fill: 1
                        color: Colors.m3onSurface
                    }
                }

                StyledText {
                    text: Math.round(item.info.value * 100)
                    font.pixelSize: Appearance.font.size.labelMedium
                    font.features: { "tnum": 1 }
                }
            }
        }
    }

    component StatRow: RowLayout {
        id: statRow
        property string icon
        property string label
        property string value
        property real fraction: -1

        Layout.fillWidth: true
        spacing: 10

        MaterialIcon {
            icon: statRow.icon
            iconSize: 18
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            RowLayout {
                StyledText {
                    Layout.fillWidth: true
                    text: label
                    font.pixelSize: Appearance.font.size.bodyMedium
                }
                StyledText {
                    text: value
                    font.pixelSize: Appearance.font.size.labelMedium
                    color: Colors.m3onSurfaceVariant
                }
            }
            Rectangle {
                visible: fraction >= 0
                Layout.fillWidth: true
                implicitHeight: 4
                radius: 2
                color: Colors.m3secondaryContainer
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, fraction))
                    height: parent.height
                    radius: 2
                    color: fraction > 0.9 ? Colors.m3error : Colors.m3primary
                    Behavior on width { EffectAnim {} }
                }
            }
        }
    }

    function temp(t) {
        return t >= 0 ? ` · ${Math.round(t)}°C` : "";
    }

    StyledPopup {
        target: root
        hovered: root.hovered
        edge: root.popupEdge

        ColumnLayout {
            width: 280
            spacing: 12

            StyledText {
                text: SystemStats.cpuModel || Translation.tr("System")
                font.pixelSize: Appearance.font.size.titleMedium
                font.weight: Font.Medium
            }
            StatRow {
                icon: "memory"
                label: "CPU" + (SystemStats.cpuCores ? " · " + Translation.trn("%1 thread", "%1 threads", SystemStats.cpuCores) : "")
                value: `${Math.round(SystemStats.cpuUsage * 100)}%${root.temp(SystemStats.cpuTemp)}`
                fraction: SystemStats.cpuUsage
            }
            StatRow {
                icon: "memory_alt"
                label: Translation.tr("Memory")
                value: `${SystemStats.memUsedGiB.toFixed(1)} / ${SystemStats.memTotalGiB.toFixed(1)} GiB`
                fraction: SystemStats.memUsage
            }
            StatRow {
                visible: SystemStats.swapTotalGiB > 0
                icon: "swap_horiz"
                label: Translation.tr("Swap")
                value: `${SystemStats.swapUsedGiB.toFixed(1)} / ${SystemStats.swapTotalGiB.toFixed(1)} GiB`
                fraction: SystemStats.swapUsage
            }
            StatRow {
                icon: "hard_drive"
                label: Translation.tr("Disk ( / )")
                value: `${Math.round(SystemStats.diskUsedGiB)} / ${Math.round(SystemStats.diskTotalGiB)} GiB`
                fraction: SystemStats.diskUsage
            }
            StatRow {
                visible: SystemStats.gpuUsage >= 0
                icon: "developer_board"
                label: "GPU"
                value: `${Math.round(SystemStats.gpuUsage * 100)}%${root.temp(SystemStats.gpuTemp)}`
                fraction: SystemStats.gpuUsage
            }
            StatRow {
                icon: "schedule"
                label: Translation.tr("Uptime")
                value: SystemStats.uptimeText
            }
        }
    }
}
