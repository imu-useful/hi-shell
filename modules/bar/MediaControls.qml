import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// The player's card: cover, title, seek bar and controls. In the media widget's hover popup and
// in the Dynamic Island's expanded music state.
ColumnLayout {
    width: 300
    spacing: 12

    RowLayout {
        Layout.fillWidth: true
        spacing: 14

        ShapeImage {
            implicitWidth: 88
            implicitHeight: 88
            shape: "box"
            source: Mpris.artUrl
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: Mpris.title
                font.pixelSize: Appearance.font.size.titleMedium
                font.weight: Font.Medium
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: Mpris.artist
                color: Colors.m3onSurfaceVariant
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: Mpris.album
                font.pixelSize: Appearance.font.size.labelMedium
                color: Colors.m3outline
            }
        }
    }

    M3Slider {
        playback: true
        Layout.fillWidth: true
        implicitHeight: 24
        visible: Mpris.length > 0
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

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 8

        IconButton {
            icon: "skip_previous"
            enabled: Mpris.active?.canGoPrevious ?? false
            onClicked: Mpris.previous()
        }
        IconButton {
            implicitWidth: 56
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

    RowLayout {
        Layout.fillWidth: true
        visible: Mpris.players.length > 1

        StyledText {
            Layout.fillWidth: true
            text: Mpris.active?.identity ?? ""
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        Chip {
            icon: "swap_horiz"
            text: Translation.tr("Switch player")
            onClicked: Mpris.cyclePlayer()
        }
    }
}
