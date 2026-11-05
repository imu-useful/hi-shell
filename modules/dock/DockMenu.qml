import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets

// The right-click menu of a dock app: pin or unpin, move a pinned app, open a new window.
Rectangle {
    id: root

    property var app: null
    property bool canMoveLeft: false
    property bool canMoveRight: false
    property bool canOpen: false
    // A dock on the left or right: "move" goes up and down.
    property bool vertical: false
    // The .desktop actions of the app ("New private window", ...) and how many windows it has.
    property var actions: []
    property int windowCount: 0
    signal pin()
    signal runAction(var action)
    signal closeWindows()
    signal move(int step)
    signal open()

    readonly property bool open: app !== null

    width: 200
    implicitHeight: column.implicitHeight + 12
    height: implicitHeight
    radius: Appearance.rounding.medium
    color: Colors.m3surfaceContainerHighest
    border.width: 1
    border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)

    component MenuRow: Rectangle {
        property string icon: ""
        property string label: ""
        signal chosen()
        width: column.width
        height: 34
        radius: Appearance.rounding.small
        color: "transparent"
        MaterialIcon {
            id: glyph
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            icon: parent.icon
            iconSize: 17
        }
        StyledText {
            anchors.left: glyph.right
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            elide: Text.ElideRight
        }
        StateLayer {
            onClicked: parent.chosen()
        }
    }

    Column {
        id: column
        x: 6
        y: 6
        width: root.width - 12
        spacing: 2

        MenuRow {
            visible: root.app !== null
            icon: root.app?.pinned ? "keep_off" : "push_pin"
            label: root.app?.pinned ? Translation.tr("Unpin") : Translation.tr("Pin to the dock")
            onChosen: root.pin()
        }
        MenuRow {
            visible: root.canMoveLeft
            icon: root.vertical ? "north" : "west"
            label: root.vertical ? Translation.tr("Move up") : Translation.tr("Move left")
            onChosen: root.move(-1)
        }
        MenuRow {
            visible: root.canMoveRight
            icon: root.vertical ? "south" : "east"
            label: root.vertical ? Translation.tr("Move down") : Translation.tr("Move right")
            onChosen: root.move(1)
        }
        MenuRow {
            visible: root.canOpen
            icon: "add_box"
            label: Translation.tr("New window")
            onChosen: root.open()
        }
        Repeater {
            model: root.actions
            MenuRow {
                required property var modelData
                icon: "arrow_outward"
                label: modelData.name
                onChosen: root.runAction(modelData)
            }
        }
        MenuRow {
            visible: root.windowCount > 0
            icon: "close"
            label: root.windowCount > 1 ? Translation.tr("Close all windows") : Translation.tr("Close window")
            onChosen: root.closeWindows()
        }
    }
}
