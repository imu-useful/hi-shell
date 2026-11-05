import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.common
import qs.common.widgets
import qs.services

// One app in the dock: its icon (grown toward the pointer), the dots of its windows, and the tooltip
// with their titles. The layout doesn't change when the icon grows, so the dock doesn't move under the pointer.
Item {
    id: root

    // { id, pinned, windows, entry } from Dock.qml
    required property var app
    required property int iconSize
    // The pointer's x in the dock's row (-1000 when it's not over the dock), and how much to grow (0 = off).
    property real pointer: -1000
    property bool magnifies: true
    // A thin line after this item (between the pinned apps and the running ones).
    property bool dividerAfter: false

    signal clicked(int button)
    signal wheeled(int step)

    readonly property real magnify: magnifies ? Math.max(0, 1 - Math.abs(pointer - x - width / 2) / (iconSize * 2.5)) * 0.45 : 0
    // Called by the dock when the app is launched from here: the icon jumps while it starts.
    function bounce() {
        jump.restart();
    }

    readonly property bool focused: app.windows.includes(Hyprland.activeToplevel)

    width: iconSize + 8
    height: iconSize

    ThemedIcon {
        id: icon
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        size: root.iconSize
        transformOrigin: Item.Bottom
        scale: 1 + root.magnify
        anchors.bottomMargin: lift
        property real lift: 0
        SequentialAnimation {
            id: jump
            loops: 3
            NumberAnimation { target: icon; property: "lift"; to: root.iconSize * 0.35; duration: 180; easing.type: Easing.OutQuad }
            NumberAnimation { target: icon; property: "lift"; to: 0; duration: 180; easing.type: Easing.InQuad }
        }
        source: Quickshell.iconPath(root.app.entry?.icon ?? root.app.id, "application-x-executable")
    }

    // The windows of the app: one dot per window (up to 3), the focused app's dots are longer.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 3
        spacing: 3
        Repeater {
            model: Math.min(3, root.app.windows.length)
            Rectangle {
                width: root.focused ? 10 : 5
                height: 4
                radius: 2
                color: Colors.m3primary
            }
        }
    }

    Rectangle {
        visible: root.dividerAfter
        anchors.right: parent.right
        anchors.rightMargin: -3
        anchors.verticalCenter: icon.verticalCenter
        width: 1
        height: root.iconSize * 0.6
        color: Qt.alpha(Colors.m3outlineVariant, 0.8)
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked(mouse.button)
        onWheel: wheel => root.wheeled(wheel.angleDelta.y < 0 ? 1 : -1)
    }

    StyledPopup {
        target: root
        hovered: area.containsMouse
        edge: Edges.Top
        openDelay: 400
        padding: 10
        ColumnLayout {
            spacing: 2
            StyledText {
                text: root.app.entry?.name ?? root.app.id
                font.weight: Font.Medium
            }
            Repeater {
                model: root.app.windows.slice(0, 4)
                StyledText {
                    required property var modelData
                    Layout.maximumWidth: 260
                    text: modelData.wayland?.title ?? ""
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.size.labelMedium
                    color: Colors.m3onSurfaceVariant
                }
            }
            StyledText {
                visible: !root.app.pinned
                text: Translation.tr("Right click for more")
                font.pixelSize: Appearance.font.size.labelSmall
                color: Colors.m3outline
            }
        }
    }
}
