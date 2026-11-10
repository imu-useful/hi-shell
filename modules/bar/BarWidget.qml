import QtQuick
import Quickshell
import qs.common
import qs.common.widgets

// Base for bar widgets. Lives inside a BarSection Loader, which provides `bar`
// (orientation, style, popup edge). Draws the widget's outlined box in every style but
// "islands", where the section itself is the box.
//
// Children go into a content area (the widget minus padding); declare the
// preferred content size with `contentWidth` / `contentHeight`.
Item {
    id: root

    readonly property var bar: parent?.bar ?? null
    // The options of this copy of the widget ("type#name" in the bar's list, Config bar.instances); empty for a plain id.
    readonly property var instance: parent?.instance ?? ({})
    // An option of this copy, else the widget's shared one.
    function pick(key, shared) {
        return instance[key] !== undefined ? instance[key] : shared;
    }
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
    // The left button went down / up (released also when the press was cancelled).
    signal pressedDown()
    signal pressedUp()
    // Scrolling over the widget (with scrollable), in whole steps; up / right positive.
    signal scrolled(int steps)

    implicitWidth: vertical ? thickness : contentWidth + padding * 2
    implicitHeight: vertical ? contentHeight + padding * 2 : thickness

    Rectangle {
        anchors.fill: parent
        visible: root.pill || root.active
        radius: Appearance.shape.button
        color: root.active ? Qt.alpha(Colors.m3primary, 0.14) : root.bar?.style === "m3" ? Colors.m3surfaceContainerHigh : "transparent"
        border.width: Appearance.edge
        border.color: root.active ? Colors.m3primary : Colors.m3outlineVariant
        Behavior on color { ColorAnim {} }
        Behavior on border.color { ColorAnim {} }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        id: area
        anchors.fill: parent
        visible: root.clickable
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked(mouse)
        onPressed: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.pressedDown();
        }
        onReleased: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.pressedUp();
        }
        onCanceled: root.pressedUp()

        Rectangle {
            anchors.fill: parent
            radius: Appearance.shape.button
            color: Colors.m3primary
            opacity: parent.pressed ? Appearance.state.press + 0.02 : root.hovered ? Appearance.state.hover : 0
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
