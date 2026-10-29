import QtQuick
import qs.common

// M3 state layer: hover / press tint over a component, plus the click area.
// Put it last inside the component so it covers the content.
MouseArea {
    id: root

    property color tint: Colors.m3onSurface
    property real radius: parent?.radius ?? 0
    // Per corner, for a parent that rounds its corners differently (-1 = use `radius`).
    property real topLeftRadius: -1
    property real topRightRadius: -1
    property real bottomLeftRadius: -1
    property real bottomRightRadius: -1

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        color: root.tint
        opacity: !root.enabled ? 0 : root.pressed ? 0.12 : root.containsMouse ? 0.08 : 0
        Behavior on opacity { EffectAnim { duration: Appearance.anim.fast } }
    }
}
