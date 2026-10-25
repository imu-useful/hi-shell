import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets

// Settings section: icon + title, then rows in a rounded card.
ColumnLayout {
    id: root

    property string icon: ""
    property string title: ""
    default property alias rows: card.data

    Layout.fillWidth: true
    spacing: 8

    RowLayout {
        spacing: 10
        Rectangle {
            implicitWidth: 30
            implicitHeight: 30
            radius: 10
            color: Colors.m3secondaryContainer
            MaterialIcon {
                anchors.centerIn: parent
                icon: root.icon
                iconSize: 18
                color: Colors.m3onSecondaryContainer
            }
        }
        StyledText {
            text: root.title
            font.pixelSize: Appearance.font.size.titleMedium
            font.weight: Font.Medium
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: card.implicitHeight + 12
        radius: Appearance.rounding.large
        color: Colors.m3surfaceContainer

        ColumnLayout {
            id: card
            anchors.fill: parent
            anchors.margins: 6
            spacing: 0
        }
    }
}
