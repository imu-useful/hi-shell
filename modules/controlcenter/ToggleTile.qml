import QtQuick
import QtQuick.Layouts
import qs.common

// Quick-settings toggle tile (icon, label, status line).
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property string subtitle: ""
    property bool active: false

    signal clicked

    implicitHeight: 72
    radius: 20
    color: active ? Colors.m3primaryContainer : mouse.containsMouse ? Colors.m3surfaceContainerHighest : Colors.m3surfaceContainerHigh
    opacity: enabled ? 1 : 0.5

    Behavior on color { ColorAnimation { duration: 150 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 12

        Rectangle {
            implicitWidth: 40
            implicitHeight: 40
            radius: Appearance.rounding.full
            color: root.active ? Colors.m3primary : Colors.m3surfaceContainerHighest

            Text {
                anchors.centerIn: parent
                text: root.icon
                font.family: Appearance.font.icon
                font.pixelSize: 22
                color: root.active ? Colors.m3onPrimary : Colors.m3onSurfaceVariant
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.label
                elide: Text.ElideRight
                font.family: Appearance.font.main
                font.pixelSize: 14
                font.weight: Font.Medium
                color: root.active ? Colors.m3onPrimaryContainer : Colors.m3onSurface
            }

            Text {
                Layout.fillWidth: true
                text: root.subtitle
                elide: Text.ElideRight
                font.family: Appearance.font.main
                font.pixelSize: 12
                color: root.active ? Colors.m3onPrimaryContainer : Colors.m3onSurfaceVariant
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
