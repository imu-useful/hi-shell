import QtQuick
import qs.common

// M3 switch; the thumb grows and shows a check when on.
Rectangle {
    id: root

    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: 52
    implicitHeight: 32
    radius: height / 2
    color: checked ? Colors.m3primary : Colors.m3surfaceContainerHighest
    border.width: checked ? 0 : 2
    border.color: Colors.m3outline
    opacity: enabled ? 1 : 0.38

    Behavior on color { ColorAnim {} }

    Rectangle {
        id: thumb

        readonly property real size: mouse.pressed ? 28 : root.checked ? 24 : 16

        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - 4 : (root.height - width) / 2
        width: size
        height: size
        radius: width / 2
        color: root.checked ? Colors.m3onPrimary : Colors.m3outline

        Behavior on x { SpatialAnim { duration: Appearance.anim.normal } }
        Behavior on width { SpatialAnim { duration: Appearance.anim.normal } }
        Behavior on height { SpatialAnim { duration: Appearance.anim.normal } }
        Behavior on color { ColorAnim {} }

        MaterialIcon {
            anchors.centerIn: parent
            icon: "check"
            iconSize: 16
            color: Colors.m3onPrimaryContainer
            opacity: root.checked ? 1 : 0
            Behavior on opacity { EffectAnim {} }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked;
            root.toggled(root.checked);
        }
    }
}
