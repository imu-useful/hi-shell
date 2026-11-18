import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// An installed icon, cursor or GTK theme: a few of its icons (or colors) and its name; a tap applies it, the bin removes
// a theme of the user's own (not the one in use).
Rectangle {
    id: root

    // Stores.icons or Stores.cursors
    required property var store
    required property var theme
    readonly property bool active: theme.id === root.store.current

    implicitHeight: col.implicitHeight + 24
    radius: Appearance.rounding.large
    color: active ? Colors.m3secondaryContainer : Colors.m3surfaceContainerHigh
    border.width: active ? 2 : 0
    border.color: Colors.m3primary

    StateLayer {
        enabled: !root.active
        onClicked: root.store.apply(root.theme.id)
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Row {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 6
            Repeater {
                model: root.theme.samples
                Image {
                    required property string modelData
                    width: 32
                    height: 32
                    source: "file://" + modelData
                    sourceSize: Qt.size(64, 64)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                }
            }
            // A GTK theme: its main colors (background, base, text, selection).
            Repeater {
                model: root.theme.colors ?? []
                Rectangle {
                    required property string modelData
                    width: 32
                    height: 32
                    radius: 16
                    color: modelData
                    border.width: 1
                    border.color: Colors.m3outlineVariant
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            MaterialIcon {
                visible: root.active
                icon: "check_circle"
                iconSize: 18
                color: Colors.m3primary
            }
            StyledText {
                Layout.fillWidth: true
                text: root.theme.name
                elide: Text.ElideRight
                font.weight: Font.Medium
                color: root.active ? Colors.m3onSecondaryContainer : Colors.m3onSurface
            }
            IconButton {
                visible: root.theme.removable && !root.active
                implicitWidth: 28
                implicitHeight: 28
                icon: "delete"
                tooltip: Translation.tr("Remove")
                onClicked: root.store.remove(root.theme.id)
            }
        }
    }
}
