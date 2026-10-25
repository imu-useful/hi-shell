import QtQuick
import qs.common

// Material 3 icon button (standard or filled) using Material Symbols.
Rectangle {
    id: root

    property string icon: ""
    property bool filled: false
    property color iconColor: filled ? Colors.m3onPrimary : Colors.m3onSurfaceVariant
    property string tooltip: ""

    signal clicked

    implicitWidth: 40
    implicitHeight: 40
    radius: Appearance.rounding.full
    color: filled ? (mouse.containsMouse ? Qt.lighter(Colors.m3primary, 1.08) : Colors.m3primary)
                  : (mouse.containsMouse ? Colors.m3surfaceContainerHighest : "transparent")
    opacity: enabled ? 1 : 0.38

    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        anchors.centerIn: parent
        text: root.icon
        font.family: Appearance.font.icon
        font.pixelSize: 22
        color: root.iconColor
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
