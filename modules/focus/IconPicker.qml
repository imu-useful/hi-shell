import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// A grid of profile icons; emits picked(icon).
Flow {
    id: root

    property string current: ""
    signal picked(string icon)

    Layout.fillWidth: true
    Layout.margins: 10
    spacing: 6

    Repeater {
        model: Focus.icons

        Rectangle {
            id: cell
            required property string modelData
            readonly property bool selected: root.current === modelData

            implicitWidth: 40
            implicitHeight: 40
            radius: selected ? 12 : 20
            color: selected ? Colors.m3primary : Colors.m3surfaceContainerHighest
            Behavior on radius { SpringAnim {} }
            Behavior on color { ColorAnim {} }

            MaterialIcon {
                anchors.centerIn: parent
                icon: cell.modelData
                iconSize: 20
                fill: cell.selected ? 1 : 0
                color: cell.selected ? Colors.m3onPrimary : Colors.m3onSurfaceVariant
            }
            StateLayer {
                onClicked: root.picked(cell.modelData)
            }
        }
    }
}
