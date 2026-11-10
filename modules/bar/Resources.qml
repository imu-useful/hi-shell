import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Resource readouts (bar.resources.shown: cpu, ram, swap, gpu, disk): a short uppercase name, the
// percentage in monospace and a thin level bar under it; a details popup on hover.
BarWidget {
    id: root

    readonly property var all: ({
        cpu: { label: "CPU", value: SystemStats.cpuUsage },
        ram: { label: "RAM", value: SystemStats.memUsage },
        swap: { label: "SWP", value: SystemStats.swapUsage },
        gpu: { label: "GPU", value: Math.max(0, SystemStats.gpuUsage) },
        disk: { label: "DSK", value: SystemStats.diskUsage }
    })
    // Keys only: a model holding the values would recreate the readouts on every update.
    readonly property var keys: pick("shown", Config.options.bar.resources.shown).filter(k => ["cpu", "ram", "swap", "gpu", "disk"].includes(k))

    padding: 8
    contentWidth: grid.implicitWidth
    contentHeight: grid.implicitHeight

    Grid {
        id: grid
        anchors.centerIn: parent
        columns: root.vertical ? 1 : root.keys.length
        spacing: root.vertical ? 8 : 12

        Repeater {
            model: root.keys

            Item {
                id: item
                required property string modelData
                readonly property var info: root.all[modelData]
                readonly property bool high: info.value > 0.9
                // The number counts to the new value along with the bar.
                property real shown: info.value
                Behavior on shown { EffectAnim { duration: Appearance.anim.slow } }

                implicitWidth: readout.implicitWidth
                implicitHeight: readout.implicitHeight + 5

                Grid {
                    id: readout
                    columns: root.vertical ? 1 : 2
                    spacing: root.vertical ? 0 : 5
                    horizontalItemAlignment: Grid.AlignHCenter
                    verticalItemAlignment: Grid.AlignVCenter

                    MonoLabel {
                        text: item.info.label
                        font.pixelSize: Appearance.font.size.labelSmall - 1
                    }
                    StyledText {
                        // Two figures wide, so the readout doesn't jump between 9 and 10.
                        width: root.vertical ? implicitWidth : Math.max(implicitWidth, digits.advanceWidth)
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(item.shown * 100)
                        font.family: Appearance.font.mono
                        font.pixelSize: Appearance.font.size.labelMedium
                        font.weight: Font.DemiBold
                        color: item.high ? Colors.m3error : Colors.m3onSurface

                        TextMetrics {
                            id: digits
                            font.family: Appearance.font.mono
                            font.pixelSize: Appearance.font.size.labelMedium
                            font.weight: Font.DemiBold
                            text: "00"
                        }
                    }
                }

                // Level: a hairline track with the used part in the accent.
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 2
                    color: Colors.m3outlineVariant

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, item.shown))
                        height: parent.height
                        color: item.high ? Colors.m3error : Colors.m3primary
                    }
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
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.font.size.labelMedium
                    color: Colors.m3onSurfaceVariant
                }
            }
            Rectangle {
                visible: fraction >= 0
                Layout.fillWidth: true
                implicitHeight: 3
                color: Colors.m3outlineVariant
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, fraction))
                    height: parent.height
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
