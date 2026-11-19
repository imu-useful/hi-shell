import QtQuick
import qs.common
import qs.common.widgets
import qs.services

// Today's screen time ("2 h 5 min"); the popup lists the most used apps.
BarWidget {
    id: root

    readonly property var apps: ScreenTime.totals(ScreenTime.today)
    readonly property real seconds: apps.reduce((sum, a) => sum + a.seconds, 0)

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

        MaterialIcon { icon: "hourglass_empty"; iconSize: 17; color: Colors.m3primary }
        StyledText {
            text: root.vertical ? Math.floor(root.seconds / 3600) + ":" + String(Math.floor(root.seconds / 60) % 60).padStart(2, "0") : ScreenTime.duration(root.seconds)
            font.pixelSize: Appearance.font.size.labelMedium + 1
        }
    }

    StyledPopup {
        target: root
        hovered: root.hovered && root.apps.length > 0
        edge: root.popupEdge

        Column {
            spacing: 4

            StyledText {
                text: Translation.tr("Screen time")
                font.pixelSize: Appearance.font.size.titleMedium
                font.weight: Font.Medium
            }
            Repeater {
                model: root.apps.slice(0, 6)

                StyledText {
                    required property var modelData
                    text: `${modelData.app}  ${ScreenTime.duration(modelData.seconds)}`
                    font.pixelSize: Appearance.font.size.labelMedium
                    color: Colors.m3onSurfaceVariant
                }
            }
        }
    }
}
