import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// Bottom: a pill with the cover, the title and artist, previous / play / next. Only while there is a player.
Tile {
    id: root

    visible: Mpris.hasPlayer
    implicitWidth: 420
    implicitHeight: 72

    HoverHandler {
        id: hover
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: Appearance.space.md

        ShapeImage {
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            shape: "cookie9"
            source: Mpris.artUrl
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                Layout.fillWidth: true
                text: Mpris.title
                font.weight: Font.Medium
            }
            StyledText {
                Layout.fillWidth: true
                text: Mpris.artist
                color: Colors.m3onSurfaceVariant
                font.pixelSize: Appearance.font.size.labelMedium
            }
        }

        IconButton { icon: "skip_previous"; enabled: Mpris.active?.canGoPrevious ?? false; onClicked: Mpris.previous() }
        IconButton { icon: Mpris.playing ? "pause" : "play_arrow"; filled: true; enabled: Mpris.active?.canTogglePlaying ?? false; onClicked: Mpris.togglePlaying() }
        IconButton { icon: "skip_next"; enabled: Mpris.active?.canGoNext ?? false; onClicked: Mpris.next() }
    }

    // Above the pill: the cover, album, and a bar to seek in.
    Detail {
        anchors.bottom: parent.top
        anchors.bottomMargin: Appearance.space.sm
        anchors.horizontalCenter: parent.horizontalCenter
        pillHovered: hover.hovered

        ShapeImage {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 160
            Layout.preferredHeight: 160
            shape: "cookie9"
            source: Mpris.artUrl
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: 320
            text: Mpris.title
            font.pixelSize: Appearance.font.size.titleMedium
            font.weight: Font.Medium
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: 320
            text: [Mpris.artist, Mpris.album].filter(t => t !== "").join(" · ")
            color: Colors.m3onSurfaceVariant
            font.pixelSize: Appearance.font.size.labelMedium
        }

        Item {
            id: bar
            Layout.preferredWidth: 320
            Layout.preferredHeight: 20
            visible: Mpris.length > 0

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                color: Colors.m3secondaryContainer
                Rectangle {
                    width: parent.width * Mpris.progress
                    height: parent.height
                    radius: 3
                    color: Colors.m3primary
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => Mpris.seekTo(mouse.x / width)
            }
        }
        RowLayout {
            Layout.preferredWidth: 320
            visible: Mpris.length > 0
            StyledText { text: Mpris.formatTime(Mpris.position); color: Colors.m3onSurfaceVariant; font.pixelSize: Appearance.font.size.labelSmall }
            Item { Layout.fillWidth: true }
            StyledText { text: Mpris.formatTime(Mpris.length); color: Colors.m3onSurfaceVariant; font.pixelSize: Appearance.font.size.labelSmall }
        }
    }
}
