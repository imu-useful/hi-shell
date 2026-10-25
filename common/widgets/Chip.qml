import QtQuick
import QtQuick.Layouts
import qs.common

// M3 chip: assist (icon + text), filter (`selected`) or input (`closable`).
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool selected: false
    property bool closable: false

    signal clicked
    signal closeClicked

    readonly property color contentColor: selected ? Colors.m3onSecondaryContainer : Colors.m3onSurfaceVariant

    implicitHeight: 32
    implicitWidth: row.implicitWidth + 24
    radius: Appearance.rounding.full
    color: selected ? Colors.m3secondaryContainer : Colors.m3surfaceContainerHigh
    opacity: enabled ? 1 : 0.38

    Behavior on color { ColorAnim {} }

    StateLayer {
        tint: root.contentColor
        onClicked: root.clicked()
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        MaterialIcon {
            visible: root.icon !== "" || root.selected
            icon: root.selected && root.icon === "" ? "check" : root.icon
            iconSize: 18
            color: root.contentColor
        }

        StyledText {
            text: root.text
            font.pixelSize: Appearance.font.size.labelMedium + 1
            font.weight: Font.Medium
            color: root.contentColor
        }

        MaterialIcon {
            visible: root.closable
            icon: "close"
            iconSize: 16
            color: root.contentColor

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeClicked()
            }
        }
    }
}
