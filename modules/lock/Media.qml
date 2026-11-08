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
}
