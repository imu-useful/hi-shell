import QtQuick
import QtQuick.Layouts
import qs.common

// Labelled linear progress bar for a usage value (0..1).
ColumnLayout {
    id: root

    property string icon: ""
    property string label: ""
    property string detail: ""
    property real value: 0

    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: root.icon
            font.family: Appearance.font.icon
            font.pixelSize: 18
            color: Colors.m3onSurfaceVariant
        }

        Text {
            Layout.fillWidth: true
            text: root.label
            font.family: Appearance.font.main
            font.pixelSize: 13
            font.weight: Font.Medium
            color: Colors.m3onSurface
        }

        Text {
            text: root.detail
            font.family: Appearance.font.main
            font.pixelSize: 12
            color: Colors.m3onSurfaceVariant
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 8
        radius: 4
        color: Colors.m3secondaryContainer

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            radius: 4
            color: root.value > 0.85 ? Colors.m3error : Colors.m3primary
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
    }
}
