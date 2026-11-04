import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// The player under the calendar's month: cover, track, the buttons and the position. Only with a player.
ColumnLayout {
    id: root

    visible: Mpris.hasPlayer
    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ShapeImage {
            Layout.preferredWidth: 52
            Layout.preferredHeight: 52
            shape: "cookie7"
            source: Mpris.artUrl
            opacity: Mpris.playing ? 1 : 0.6
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: Mpris.title
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: Mpris.artist
                font.pixelSize: Appearance.font.size.labelMedium + 1
                color: Colors.m3onSurfaceVariant
                elide: Text.ElideRight
            }
        }

        RowLayout {
            spacing: 2

            IconButton {
                icon: "skip_previous"
                enabled: Mpris.active?.canGoPrevious ?? false
                onClicked: Mpris.previous()
            }
            IconButton {
                filled: true
                icon: Mpris.playing ? "pause" : "play_arrow"
                onClicked: Mpris.togglePlaying()
            }
            IconButton {
                icon: "skip_next"
                enabled: Mpris.active?.canGoNext ?? false
                onClicked: Mpris.next()
            }
        }
    }

    M3Slider {
        Layout.fillWidth: true
        implicitHeight: 20
        visible: Mpris.length > 0
        playback: true
        value: Mpris.progress
        onMoved: value => Mpris.seekTo(value)
    }

    RowLayout {
        Layout.fillWidth: true
        visible: Mpris.length > 0

        StyledText {
            text: Mpris.formatTime(Mpris.position)
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        Item { Layout.fillWidth: true }
        StyledText {
            text: Mpris.formatTime(Mpris.length)
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
    }
}
