import QtQuick
import qs.common

// M3 state layer: hover / press tint over a component, plus the click area.
// Put it last inside the component so it covers the content.
MouseArea {
    id: root

    property color tint: Colors.m3onSurface
    property real radius: parent?.radius ?? 0

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.tint
        opacity: !root.enabled ? 0 : root.pressed ? 0.12 : root.containsMouse ? 0.08 : 0
        Behavior on opacity { EffectAnim { duration: Appearance.anim.fast } }
    }
}
