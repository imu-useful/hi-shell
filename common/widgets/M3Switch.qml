import QtQuick
import qs.common

// Switch: an outlined box with a square thumb; on, the box fills with the accent.
Rectangle {
    id: root

    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: 40
    implicitHeight: 22
    radius: Appearance.rounding.small
    color: checked ? Colors.m3primary : "transparent"
    border.width: checked ? 0 : Math.max(1, Appearance.edge)
    border.color: mouse.containsMouse ? Colors.m3onSurfaceVariant : Colors.m3outline
    opacity: enabled ? 1 : Appearance.state.disabledContent

    Behavior on color { ColorAnim {} }

    Rectangle {
        id: thumb

        readonly property real size: root.height - 8

        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - 4 : 4
        width: mouse.pressed ? size + 4 : size
        height: size
        radius: Math.max(0, root.radius - 1)
        color: root.checked ? Colors.m3onPrimary : Colors.m3outline

        Behavior on x { SpatialAnim { duration: Appearance.anim.fast } }
        Behavior on width { SpatialAnim { duration: Appearance.anim.fast } }
        Behavior on color { ColorAnim {} }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked;
            root.toggled(root.checked);
        }
    }
}
