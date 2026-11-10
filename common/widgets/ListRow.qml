import QtQuick
import QtQuick.Layouts
import qs.common

// Settings-style list row: leading icon, title / subtitle, trailing items
// (children go to the trailing slot, e.g. an M3Switch or SegmentedButton).
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    // A small label after the title ("Beta").
    property string tag: ""
    property bool clickable: false
    default property alias trailing: trailingRow.data

    signal clicked

    implicitHeight: Math.max(52, row.implicitHeight + 16)
    implicitWidth: row.implicitWidth + 32
    radius: Appearance.rounding.medium
    color: "transparent"

    StateLayer {
        visible: root.clickable
        onClicked: root.clicked()
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 12
        spacing: 14

        MaterialIcon {
            visible: root.icon !== ""
            icon: root.icon
            iconSize: 20
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.fillWidth: !tagLabel.visible
                    text: root.title
                    elide: Text.ElideRight
                }
                Rectangle {
                    id: tagLabel
                    visible: root.tag !== ""
                    Layout.fillWidth: false
                    implicitWidth: tagText.implicitWidth + 12
                    implicitHeight: 18
                    radius: height / 2
                    color: Colors.m3tertiaryContainer

                    StyledText {
                        id: tagText
                        anchors.centerIn: parent
                        text: root.tag
                        font.pixelSize: Appearance.font.size.labelSmall
                        font.weight: Font.Medium
                        color: Colors.m3onTertiaryContainer
                    }
                }
                Item {
                    visible: tagLabel.visible
                    Layout.fillWidth: true
                }
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                text: root.subtitle
                font.pixelSize: Appearance.font.size.labelMedium
                color: Colors.m3onSurfaceVariant
            }
        }

        RowLayout {
            id: trailingRow
            spacing: 8
        }
    }
}
