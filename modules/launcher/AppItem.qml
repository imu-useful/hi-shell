import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.common.widgets

// One application row in the launcher results list (or a settings page:
// a plain object with name / comment / materialIcon / settingsPage).
Rectangle {
    id: root

    required property var modelData
    readonly property bool isSetting: modelData.settingsPage !== undefined
    required property int index
    property bool selected: false

    signal activated
    signal hovered

    implicitHeight: 52
    radius: Appearance.rounding.medium
    color: selected ? Colors.m3secondaryContainer : "transparent"

    Behavior on color { ColorAnimation { duration: 120 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        Rectangle {
            visible: root.isSetting
            implicitWidth: 32
            implicitHeight: 32
            radius: 16
            color: Colors.m3primaryContainer
            MaterialIcon {
                anchors.centerIn: parent
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
