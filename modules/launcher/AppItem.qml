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
    radius: Appearance.rounding.medium
    color: selected ? Colors.m3secondaryContainer : "transparent"

    Behavior on color { ColorAnimation { duration: 120 } }

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
            radius: 16
            // Emoji sit on their own; icons get a tonal disc.
            color: root.modelData.glyph !== undefined ? "transparent" : Colors.m3primaryContainer
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
                color: Colors.m3onPrimaryContainer
            }
        }

        IconImage {
            visible: !root.isSetting
            implicitSize: 32
            // Wait for a real size: a 0 sourceSize makes Qt rasterize SVGs at native size.
            source: actualSize > 0 && !root.isSetting ? Quickshell.iconPath(root.modelData.icon, "application-x-executable") : ""
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
                color: root.selected ? Colors.m3onSecondaryContainer : Colors.m3onSurface
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
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered()
        onClicked: root.activated()
    }
}
