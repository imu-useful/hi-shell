import QtQuick
import qs.common
import qs.common.widgets
import qs.services

// The CPU temperature (and the GPU's when it has a sensor); red from 85 °C. Hidden without a sensor.
BarWidget {
    id: root

    readonly property real hot: 85

    shown: SystemStats.cpuTemp >= 0
    padding: 9
    contentWidth: grid.implicitWidth
    contentHeight: grid.implicitHeight

    Grid {
        id: grid
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        spacing: 4
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        MaterialIcon {
            icon: "thermostat"
            iconSize: 17
            color: SystemStats.cpuTemp >= root.hot ? Colors.m3error : Colors.m3primary
        }
        StyledText {
            text: Math.round(SystemStats.cpuTemp) + "°"
            font.pixelSize: Appearance.font.size.labelMedium + 1
            font.features: { "tnum": 1 }
            color: SystemStats.cpuTemp >= root.hot ? Colors.m3error : Colors.m3onSurface
        }
    }

    StyledPopup {
        target: root
        hovered: root.hovered
        edge: root.popupEdge

        Column {
            spacing: 4
            StyledText {
                text: Translation.tr("CPU %1 °C").arg(Math.round(SystemStats.cpuTemp))
                font.pixelSize: Appearance.font.size.labelMedium
            }
            StyledText {
                visible: SystemStats.gpuTemp >= 0
                text: Translation.tr("GPU %1 °C").arg(Math.round(SystemStats.gpuTemp))
                font.pixelSize: Appearance.font.size.labelMedium
            }
        }
    }
}
