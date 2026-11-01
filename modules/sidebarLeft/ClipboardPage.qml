import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

// Clipboard history (cliphist): search, click to copy, pin, delete, image thumbnails.
// Pinned entries come first and survive "Clear history". Right-click an entry for its menu.
ColumnLayout {
    id: root

    property string query: ""
    // The entry the right-click menu is open for, and where it was opened (in the list).
    property var menuEntry: null
    property point menuAt: Qt.point(0, 0)
    readonly property var shown: [...Clipboard.pinnedEntries, ...Clipboard.history].filter(e => query === "" || (!e.image && e.text.toLowerCase().includes(query.toLowerCase())))

    function openMenu(entry, mouse) {
        menuAt = entry.mapToItem(list, mouse.x, mouse.y);
        menuEntry = entry.e;
    }

    signal copied

    function focusInput() {
        search.forceActiveFocus();
    }

    Component.onCompleted: Clipboard.refresh()
    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 44
            radius: 22
            color: Colors.m3surfaceContainerHighest

            MaterialIcon {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                icon: "search"
                iconSize: 20
            }
            TextInput {
                id: search
                anchors.left: searchIcon.right
                anchors.right: parent.right
                anchors.leftMargin: 10
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                font.family: Appearance.font.main
                font.pixelSize: Appearance.font.size.bodyMedium
                color: Colors.m3onSurface
                clip: true
                onTextChanged: root.query = text
                onAccepted: if (root.shown.length) { Clipboard.copy(root.shown[0]); root.copied(); }

                StyledText {
                    visible: search.text === ""
                    text: Translation.trn("Search %1 item", "Search %1 items", Clipboard.entries.length)
                    color: Colors.m3outline
                }
            }
        }
        IconButton {
            icon: "delete_sweep"
            tooltip: Translation.tr("Clear history")
            enabled: Clipboard.entries.length > 0
            onClicked: Clipboard.wipe()
        }
    }

    // A row of the right-click menu.
    component MenuRow: Rectangle {
        id: row

        required property string icon
        required property string text
        signal chosen

        width: parent.width
        height: 40
        radius: Appearance.rounding.small
        color: "transparent"

        MaterialIcon {
            id: rowIcon
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            icon: row.icon
            iconSize: 18
        }
        StyledText {
            anchors.left: rowIcon.right
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: row.text
            elide: Text.ElideRight
        }
        StateLayer {
            onClicked: row.chosen()
        }
    }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 6
        model: ScriptModel {
            values: root.shown
            objectProp: "id"
        }
        boundsBehavior: Flickable.StopAtBounds

        // Removing one entry or clearing them all: they slide away and the rest close up.
        remove: EraseTransition {}
        displaced: Transition {
            SpatialAnim { properties: "y" }
        }

        delegate: Rectangle {
            id: entry

            required property var modelData
            // Null for a moment while a removed entry's delegate is torn down.
            readonly property var e: modelData ?? ({ id: "", text: "", image: false })
            readonly property bool pinned: Clipboard.isPinned(e.id)
            property string thumb: ""

            width: list.width
            implicitHeight: e.image ? 120 : Math.min(84, label.implicitHeight + 24)
            radius: Appearance.rounding.large
            color: Colors.m3surfaceContainer

            Component.onCompleted: if (e.image) Clipboard.decodeThumbnail(e, url => entry.thumb = url)

            StyledText {
                id: label
                visible: !entry.e.image
                anchors.fill: parent
                anchors.margins: 12
                anchors.rightMargin: 44
                text: entry.e.text
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 3
                verticalAlignment: Text.AlignTop
                font.pixelSize: Appearance.font.size.labelMedium + 1
            }

            Image {
                visible: entry.e.image
                anchors.fill: parent
                anchors.margins: 8
                anchors.rightMargin: 44
                source: entry.thumb
                fillMode: Image.PreserveAspectFit
                horizontalAlignment: Image.AlignLeft
                asynchronous: true
                sourceSize.height: 120
            }

            StateLayer {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        root.openMenu(entry, mouse);
                        return;
                    }
                    Clipboard.copy(entry.e);
                    root.copied();
                }
            }

            IconButton {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 4
                implicitWidth: 34
                implicitHeight: 34
                icon: "push_pin"
                filled: entry.pinned
                tooltip: entry.pinned ? Translation.tr("Unpin") : Translation.tr("Pin")
                onClicked: Clipboard.togglePin(entry.e)
            }
        }

        // Clicking outside the menu closes it.
        MouseArea {
            anchors.fill: parent
            z: 1
            visible: root.menuEntry !== null
            acceptedButtons: Qt.AllButtons
            onPressed: root.menuEntry = null
        }

        Rectangle {
            id: menu

            readonly property bool pinned: root.menuEntry !== null && Clipboard.isPinned(root.menuEntry.id)

            z: 2
            visible: root.menuEntry !== null
            x: Math.max(0, Math.min(root.menuAt.x, list.width - width))
            y: Math.max(0, Math.min(root.menuAt.y, list.height - height))
            width: 170
            height: menuColumn.implicitHeight + 12
            radius: Appearance.rounding.medium
            color: Colors.m3surfaceContainerHighest

            Column {
                id: menuColumn
                x: 6
                y: 6
                width: menu.width - 12
                spacing: 2

                MenuRow {
                    icon: menu.pinned ? "keep_off" : "push_pin"
                    text: menu.pinned ? Translation.tr("Unpin") : Translation.tr("Pin")
                    onChosen: {
                        Clipboard.togglePin(root.menuEntry);
                        root.menuEntry = null;
                    }
                }
                MenuRow {
                    icon: "delete"
                    text: Translation.tr("Delete")
                    onChosen: {
                        Clipboard.remove(root.menuEntry);
                        root.menuEntry = null;
                    }
                }
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: list.count === 0
            text: Clipboard.entries.length === 0 ? Translation.tr("Clipboard history is empty") : Translation.tr("Nothing matches")
            color: Colors.m3outline
        }
    }
}
