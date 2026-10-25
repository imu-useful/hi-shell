import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

// Clipboard history (cliphist): search, click to copy, delete, image thumbnails.
ColumnLayout {
    id: root

    property string query: ""
    readonly property var shown: query === "" ? Clipboard.entries : Clipboard.entries.filter(e => !e.image && e.text.toLowerCase().includes(query.toLowerCase()))

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

        delegate: Rectangle {
            id: entry

            required property var modelData
            // Null for a moment while a removed entry's delegate is torn down.
            readonly property var e: modelData ?? ({ id: "", text: "", image: false })
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
                onClicked: {
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
                icon: "close"
                onClicked: Clipboard.remove(entry.e)
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
