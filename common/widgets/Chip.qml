import QtQuick
import QtQuick.Layouts
import qs.common

// Chip: assist (icon + text), filter (`selected`: the accent edge and a square mark) or input (`closable`).
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool selected: false
    property bool closable: false

    signal clicked
    signal closeClicked

    readonly property color contentColor: selected || layer.containsMouse ? Colors.m3primary : Colors.m3onSurfaceVariant

    implicitHeight: 28
    implicitWidth: row.implicitWidth + 20
    radius: Appearance.shape.chip
    color: selected ? Qt.alpha(Colors.m3primary, 0.12) : "transparent"
    border.width: Appearance.edge
    border.color: selected ? Colors.m3primary : layer.containsMouse ? Colors.m3outline : Colors.m3outlineVariant
    opacity: enabled ? 1 : Appearance.state.disabledContent

    Behavior on color { ColorAnim {} }
    Behavior on border.color { ColorAnim {} }

    scale: layer.pressed ? Appearance.anim.pressScale : 1
    Behavior on scale { enabled: Appearance.anim.speed > 0; SpringAnim { overshoot: 1.4 } }

    StateLayer {
        id: layer
        tint: root.contentColor
        onClicked: root.clicked()
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        // Selected without an icon of its own: a small filled square instead of a check.
        Rectangle {
            visible: root.selected && root.icon === ""
            implicitWidth: 6
            implicitHeight: 6
            radius: 1
            color: root.contentColor
        }

        MaterialIcon {
            visible: root.icon !== ""
            icon: root.icon
            iconSize: 16
            color: root.contentColor
        }

        StyledText {
            text: root.text
            font.pixelSize: Appearance.font.size.labelMedium
            font.weight: Font.Medium
            color: root.contentColor
        }

        MaterialIcon {
            visible: root.closable
            icon: "close"
            iconSize: 14
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
