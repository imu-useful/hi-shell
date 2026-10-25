import QtQuick
import QtQuick.Layouts
import qs.common

// Material 3 filled (or tonal) text button with optional leading icon.
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool tonal: false

    signal clicked

    readonly property color contentColor: tonal ? Colors.m3onSecondaryContainer : Colors.m3onPrimary

    implicitWidth: row.implicitWidth + 40
    implicitHeight: 40
    radius: Appearance.rounding.full
    color: {
        const base = tonal ? Colors.m3secondaryContainer : Colors.m3primary;
        return mouse.containsMouse ? Qt.lighter(base, 1.08) : base;
    }
    opacity: enabled ? 1 : 0.38

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Text {
            visible: root.icon !== ""
            text: root.icon
            font.family: Appearance.font.icon
            font.pixelSize: 18
            color: root.contentColor
        }

        Text {
            text: root.text
            font.family: Appearance.font.main
            font.pixelSize: 14
            font.weight: Font.Medium
            color: root.contentColor
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
