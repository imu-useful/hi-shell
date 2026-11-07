import QtQuick
import Quickshell
import qs.common
import qs.common.widgets

// The apps button of the dock: opens the full-screen list of every app. Sized, magnified and
// separated like a DockItem, so it sits in the same row.
Item {
    id: root

    required property int iconSize
    property real pointer: -1000
    property bool magnifies: true
    property real magnifyAmount: 0.45
    property string position: "bottom"
    readonly property bool vertical: position === "left" || position === "right"

    signal clicked

    property real eased: magnify
    Behavior on eased { NumberAnimation { duration: 90 * Appearance.anim.speed; easing.type: Easing.OutCubic } }
    property real press: area.pressed ? 0.86 : 1
    Behavior on press { NumberAnimation { duration: 90 * Appearance.anim.speed; easing.type: Easing.OutCubic } }

    readonly property real magnify: magnifies ? Math.max(0, 1 - Math.abs(pointer - (vertical ? y + height / 2 : x + width / 2)) / (iconSize * 2.5)) * magnifyAmount : 0

    width: vertical ? iconSize : iconSize + 8
    height: vertical ? iconSize + 8 : iconSize

    Rectangle {
        id: disc
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        radius: width * 0.3
        color: area.containsMouse || ShellState.appGridOpen ? Colors.m3primary : Colors.m3primaryContainer
        transformOrigin: root.position === "left" ? Item.Left : root.position === "right" ? Item.Right
            : root.position === "top" ? Item.Top : Item.Bottom
        scale: (1 + root.eased) * root.press
        Behavior on color { ColorAnim {} }

        MaterialIcon {
            anchors.centerIn: parent
            icon: "apps"
            iconSize: root.iconSize * 0.6
            color: area.containsMouse || ShellState.appGridOpen ? Colors.m3onPrimary : Colors.m3onPrimaryContainer
        }
    }

    // A thin line after the button, between it and the apps.
    Rectangle {
        x: root.vertical ? (root.width - width) / 2 : root.width + 3 - width
        y: root.vertical ? root.height + 1 : (root.height - height) / 2
        width: root.vertical ? root.iconSize * 0.6 : 1
        height: root.vertical ? 1 : root.iconSize * 0.6
        color: Qt.alpha(Colors.m3outlineVariant, 0.8)
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    StyledPopup {
        target: root
        hovered: area.containsMouse
        edge: root.position === "top" ? Edges.Bottom : root.position === "left" ? Edges.Right : root.position === "right" ? Edges.Left : Edges.Top
        openDelay: 400
        padding: 10
        StyledText {
            text: Translation.tr("All apps")
        }
    }
}
