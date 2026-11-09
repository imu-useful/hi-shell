import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets

// The details that open next to a pill while the pointer is on it (or on the details themselves, so a
// button in them can be reached). Put it inside the pill and anchor it above or below.
Rectangle {
    id: root

    // The pill under the pointer (set by the pill's HoverHandler).
    property bool pillHovered: false
    readonly property bool shown: pillHovered || over.hovered || grace.running
    default property alias content: column.data

    implicitWidth: column.implicitWidth + Appearance.space.lg * 2
    implicitHeight: column.implicitHeight + Appearance.space.lg * 2
    radius: Appearance.rounding.extraLarge
    color: Qt.alpha(Colors.m3surfaceContainerHigh, 0.95)
    border.width: Appearance.edge
    border.color: Appearance.edgeColor

    GlassSheen {}

    z: 10
    visible: opacity > 0
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.94
    transformOrigin: y < 0 ? Item.Bottom : Item.Top
    Behavior on opacity { NumberAnimation { duration: Appearance.anim.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.anim.effects } }
    Behavior on scale { NumberAnimation { duration: Appearance.anim.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.anim.spatialDefault } }

    // Moving the pointer from the pill to the details crosses a small gap.
    onPillHoveredChanged: if (!pillHovered) grace.restart()
    Timer {
        id: grace
        interval: 250
    }

    HoverHandler {
        id: over
    }

    ColumnLayout {
        id: column
        anchors.centerIn: parent
        spacing: Appearance.space.sm
    }
}
