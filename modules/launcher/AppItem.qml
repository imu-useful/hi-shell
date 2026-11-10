import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.common.widgets
import qs.services

// One launcher result: a DesktopEntry app, or a plain object with
// name / comment and materialIcon or glyph (an emoji).
Rectangle {
    id: root

    required property var modelData
    readonly property bool isSetting: modelData.run !== undefined
    required property int index
    property bool selected: false
    // A clipboard image's file (see Launcher.imageItem), decoded when the row appears.
    property string thumb: ""

    signal activated
    signal hovered

    implicitHeight: 52
    radius: Appearance.rounding.small
    // Selected: an accent tint and a bar down the left side, like a cursor line.
    color: selected ? Qt.alpha(Colors.m3primary, 0.12) : "transparent"

    Behavior on color { ColorAnimation { duration: 120 } }

    Rectangle {
        width: 3
        height: parent.height
        topLeftRadius: parent.radius
        bottomLeftRadius: parent.radius
        color: Colors.m3primary
        visible: root.selected
    }

    Component.onCompleted: if (modelData.clip) Clipboard.decodeThumbnail(modelData.clip, url => root.thumb = url)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        // A clipboard image's thumbnail.
        Rectangle {
            visible: root.thumb !== ""
            implicitWidth: 40
            implicitHeight: 40
            radius: Appearance.rounding.small
            color: Colors.m3surfaceContainerHighest
            clip: true
            Image {
                anchors.fill: parent
                source: root.thumb
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(80, 80)
            }
        }

        Rectangle {
            visible: root.isSetting && root.thumb === ""
            implicitWidth: 32
            implicitHeight: 32
            radius: Appearance.rounding.small
            // Emoji sit on their own; icons get an outlined square.
            color: "transparent"
            border.width: root.modelData.glyph !== undefined ? 0 : 1
            border.color: Colors.m3outlineVariant
            Text {
                anchors.centerIn: parent
                visible: root.modelData.glyph !== undefined
                text: root.modelData.glyph ?? ""
                font.pixelSize: 22
            }
            MaterialIcon {
                anchors.centerIn: parent
                visible: root.modelData.glyph === undefined
                icon: root.modelData.materialIcon ?? ""
                iconSize: 18
                color: Colors.m3primary
            }
        }

        ThemedIcon {
            visible: !root.isSetting
            size: 32
            source: !root.isSetting ? Quickshell.iconPath(root.modelData.icon, "application-x-executable") : ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.modelData.name
                elide: Text.ElideRight
                font.family: Appearance.font.main
                font.pixelSize: 14
                font.weight: Font.Medium
                color: root.selected ? Colors.m3primary : Colors.m3onSurface
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.modelData.comment || (root.modelData.genericName ?? "")
                elide: Text.ElideRight
                font.family: Appearance.font.main
                font.pixelSize: 11
                color: Colors.m3onSurfaceVariant
            }
        }

        // The key that runs the selected row.
        MonoLabel {
            visible: root.selected
            text: "↵ enter"
            color: Colors.m3primary
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered()
        onClicked: root.activated()
    }
}
