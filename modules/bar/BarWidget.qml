import QtQuick
import Quickshell
import qs.common
import qs.common.widgets

// Base for bar widgets. Lives inside a BarSection Loader, which provides `bar`
// (orientation, style, popup edge). Draws the widget's pill in every style but
// "islands", where the section itself is the pill.
//
// Children go into a content area (the widget minus padding); declare the
// preferred content size with `contentWidth` / `contentHeight`.
Item {
    id: root

    readonly property var bar: parent?.bar ?? null
    readonly property bool vertical: bar?.vertical ?? false
    readonly property int thickness: (bar?.thickness ?? 40) - 12
    readonly property int popupEdge: bar?.popupEdge ?? Edges.Bottom
    readonly property bool hovered: hover.hovered

    // Whether the widget wants to be in the bar (e.g. media only with a player).
    // Not `visible`: the section's Loader hides itself based on this.
    property bool shown: true
    property bool pill: (bar?.style ?? "float") !== "islands"
    property bool active: false
    property bool clickable: false
    property bool scrollable: false
    property real padding: 10
    property real contentWidth: 0
    property real contentHeight: 0
    default property alias content: container.data

    signal clicked(var mouse)
    // Scrolling over the widget (with scrollable), in whole steps; up / right positive.
    signal scrolled(int steps)

    implicitWidth: vertical ? thickness : contentWidth + padding * 2
    implicitHeight: vertical ? contentHeight + padding * 2 : thickness

    Rectangle {
        anchors.fill: parent
        visible: root.pill || root.active
        radius: Appearance.rounding.full
        color: root.active ? Colors.m3secondaryContainer : (root.bar?.style === "m3" ? Colors.m3surfaceContainerHighest : Colors.m3surfaceContainerHigh)
        Behavior on color { ColorAnim {} }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        visible: root.clickable
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked(mouse)

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.full
            color: Colors.m3onSurface
            opacity: parent.pressed ? 0.12 : root.hovered ? 0.06 : 0
            Behavior on opacity { EffectAnim { duration: Appearance.anim.fast } }
        }
    }

    WheelSteps {
        enabled: root.scrollable
        onStepped: steps => root.scrolled(steps)
    }

    Item {
        id: container
        anchors.centerIn: parent
        // Follows the real size, so widgets the layout shrinks (fillWidth) can elide.
        width: root.vertical ? root.thickness : Math.max(0, root.width - root.padding * 2)
        height: root.vertical ? Math.max(0, root.height - root.padding * 2) : root.thickness
    }
}
