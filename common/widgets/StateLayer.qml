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
        // Not -1 handed over as it is: an explicit -1 reads as 0, not as "use radius".
        topLeftRadius: root.topLeftRadius >= 0 ? root.topLeftRadius : root.radius
        topRightRadius: root.topRightRadius >= 0 ? root.topRightRadius : root.radius
        bottomLeftRadius: root.bottomLeftRadius >= 0 ? root.bottomLeftRadius : root.radius
        bottomRightRadius: root.bottomRightRadius >= 0 ? root.bottomRightRadius : root.radius
        color: root.tint
        opacity: !root.enabled ? 0 : root.pressed ? Appearance.state.press + 0.02 : root.containsMouse ? Appearance.state.hover : 0
        Behavior on opacity { EffectAnim { duration: Appearance.anim.fast } }
    }

    // Ripple: a copy of the shape grows from the click point and fades. Shrunk toward a point inside the
    // shape it stays inside it, so no mask is needed.
    Rectangle {
        id: ripple

        property real originX: root.width / 2
        property real originY: root.height / 2
        property real grown: 0

        anchors.fill: parent
        visible: opacity > 0
        opacity: 0
        radius: root.radius
        topLeftRadius: root.topLeftRadius >= 0 ? root.topLeftRadius : root.radius
        topRightRadius: root.topRightRadius >= 0 ? root.topRightRadius : root.radius
        bottomLeftRadius: root.bottomLeftRadius >= 0 ? root.bottomLeftRadius : root.radius
        bottomRightRadius: root.bottomRightRadius >= 0 ? root.bottomRightRadius : root.radius
        color: root.tint
        transform: Scale {
            origin.x: ripple.originX
            origin.y: ripple.originY
            xScale: ripple.grown
            yScale: ripple.grown
        }
    }

    ParallelAnimation {
        id: rippleAnim

        NumberAnimation { target: ripple; property: "grown"; from: 0.05; to: 1; duration: Appearance.anim.slow; easing.type: Easing.OutCubic }
        SequentialAnimation {
            NumberAnimation { target: ripple; property: "opacity"; from: 0; to: Appearance.state.press + 0.06; duration: Appearance.anim.fast * 0.5 }
            NumberAnimation { target: ripple; property: "opacity"; to: 0; duration: Appearance.anim.slow }
        }
    }

    onPressed: mouse => {
        if (!enabled || !Config.options.appearance.ripple || Appearance.anim.speed <= 0)
            return;
        ripple.originX = mouse.x;
        ripple.originY = mouse.y;
        rippleAnim.restart();
    }
}
