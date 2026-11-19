import QtQuick
import qs.common
import qs.common.widgets
import qs.services

// How long the system has been up.
BarWidget {
    id: root

    shown: SystemStats.uptime > 0
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

        MaterialIcon { icon: "schedule"; iconSize: 17; color: Colors.m3primary }
        StyledText {
            text: SystemStats.uptimeText
            font.pixelSize: Appearance.font.size.labelMedium + 1
        }
    }
}
