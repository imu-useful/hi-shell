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

    // { id, pinned, windows } from Dock.qml, and its .desktop entry (null when there is none)
    required property var app
    property var entry: null
    required property int iconSize
    // The pointer's x in the dock's row (-1000 when it's not over the dock), and how much to grow (0 = off).
    property real pointer: -1000
    property bool magnifies: true
    // The dock's screen edge: bottom, top, left or right.
    property string position: "bottom"
    readonly property bool vertical: position === "left" || position === "right"
    // How much the icon grows at most (0.45 = 45%), and whether the window dots show.
    property real magnifyAmount: 0.45
    property bool showIndicators: true
    // A thin line after this item (between the pinned apps and the running ones).
    property bool dividerAfter: false

    signal clicked(int button)
    signal wheeled(int step)

    // The magnify and the press, eased so the icons follow the pointer smoothly; `appear` pops a new icon in.
    property real appear: 0
    Behavior on appear { SpringAnim { overshoot: 2 } }
    Component.onCompleted: appear = 1
    property real eased: magnify
    Behavior on eased { NumberAnimation { duration: 90 * Appearance.anim.speed; easing.type: Easing.OutCubic } }
    property real press: area.pressed ? 0.86 : 1
    Behavior on press { NumberAnimation { duration: 90 * Appearance.anim.speed; easing.type: Easing.OutCubic } }

    readonly property real magnify: magnifies ? Math.max(0, 1 - Math.abs(pointer - (vertical ? y + height / 2 : x + width / 2)) / (iconSize * 2.5)) * magnifyAmount : 0
    // Called by the dock when the app is launched from here: the icon jumps while it starts.
    function bounce() {
        jump.restart();
    }

    readonly property bool focused: app.windows.includes(Hyprland.activeToplevel)

    width: vertical ? iconSize : iconSize + 8
    height: vertical ? iconSize + 8 : iconSize

    // The unit vector from the dock's edge toward the screen's middle: where the icon grows and jumps.
    readonly property int towardX: position === "left" ? 1 : position === "right" ? -1 : 0
    readonly property int towardY: position === "top" ? 1 : position === "bottom" ? -1 : 0

    ThemedIcon {
        id: icon
        anchors.centerIn: parent
        size: root.iconSize
        transformOrigin: root.position === "left" ? Item.Left : root.position === "right" ? Item.Right
            : root.position === "top" ? Item.Top : Item.Bottom
        scale: (1 + root.eased) * root.press * root.appear
        opacity: Math.min(1, root.appear * 2)
        property real lift: 0
        transform: Translate {
            x: icon.lift * root.towardX
            y: icon.lift * root.towardY
        }
        SequentialAnimation {
            id: jump
            loops: 3
            NumberAnimation { target: icon; property: "lift"; to: root.iconSize * 0.35; duration: 180; easing.type: Easing.OutQuad }
            NumberAnimation { target: icon; property: "lift"; to: 0; duration: 180; easing.type: Easing.InQuad }
        }
        source: Quickshell.iconPath(root.entry?.icon ?? root.app.id, "application-x-executable")
    }

    // The windows of the app: one dot per window (up to 3), the focused app's dots are longer.
    // They sit on the side of the icon that faces the screen edge.
    Grid {
        visible: root.showIndicators
        columns: root.vertical ? 1 : 3
        spacing: 3
        x: root.position === "left" ? -width - 3 : root.position === "right" ? root.width + 3 : (root.width - width) / 2
        y: root.position === "top" ? -height - 3 : root.position === "bottom" ? root.height + 3 : (root.height - height) / 2
        Repeater {
            model: Math.min(3, root.app.windows.length)
            Rectangle {
                width: root.vertical ? 4 : root.focused ? 10 : 5
                height: root.vertical ? (root.focused ? 10 : 5) : 4
                radius: 2
                color: Colors.m3primary
                Behavior on width { SpatialAnim { duration: Appearance.anim.fast } }
                Behavior on height { SpatialAnim { duration: Appearance.anim.fast } }
            }
        }
    }

    Rectangle {
        visible: root.dividerAfter
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
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked(mouse.button)
        onWheel: wheel => root.wheeled(wheel.angleDelta.y < 0 ? 1 : -1)
    }

    StyledPopup {
        target: root
        hovered: area.containsMouse
        edge: root.position === "top" ? Edges.Bottom : root.position === "left" ? Edges.Right : root.position === "right" ? Edges.Left : Edges.Top
        openDelay: 400
        padding: 10
        ColumnLayout {
            spacing: 2
            StyledText {
                text: root.entry?.name ?? root.app.id
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
