import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// Now playing: album art (spins while playing), "title • artist", play/pause.
// Hover for a popup with seek bar and controls. Middle click = next track.
BarWidget {
    id: root

    readonly property int artSize: thickness - 6

    shown: Mpris.hasPlayer
    padding: 3
    Layout.fillWidth: true
    Layout.maximumWidth: Config.options.bar.media.maxWidth
    contentWidth: vertical ? artSize : artSize + 8 + label.implicitWidth + 6 + playButton.width + 2
    contentHeight: artSize

    clickable: true
    onClicked: mouse => mouse.button === Qt.MiddleButton ? Mpris.next() : Mpris.togglePlaying()

    ShapeImage {
        id: art
        anchors.verticalCenter: parent.verticalCenter
        x: root.vertical ? (parent.width - width) / 2 : 0
        width: root.artSize
        height: root.artSize
        shape: "cookie7"
        source: Mpris.artUrl

        RotationAnimation on rotation {
            running: Mpris.playing && Appearance.anim.speed > 0
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 20000
        }
    }

    MaterialIcon {
        anchors.centerIn: art
        visible: art.status !== Image.Ready
        icon: "music_note"
        iconSize: 16
    }

    StyledText {
        id: label
        visible: !root.vertical
        anchors.left: art.right
        anchors.leftMargin: 8
        anchors.right: playButton.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: Mpris.artist ? `${Mpris.title} • ${Mpris.artist}` : Mpris.title
        font.pixelSize: Appearance.font.size.normal
    }

    Rectangle {
        id: playButton
        visible: !root.vertical
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        width: root.artSize + 6
        height: root.artSize - 2
        radius: Appearance.rounding.full
        color: Mpris.playing ? Colors.m3primary : Colors.m3secondaryContainer
        Behavior on color { ColorAnim {} }

        MaterialIcon {
            anchors.centerIn: parent
            icon: Mpris.playing ? "pause" : "play_arrow"
            fill: 1
            iconSize: 18
            color: Mpris.playing ? Colors.m3onPrimary : Colors.m3onSecondaryContainer
        }
    }

    StyledPopup {
        target: root
        hovered: root.hovered
        edge: root.popupEdge

        ColumnLayout {
            width: 300
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                ShapeImage {
                    implicitWidth: 88
                    implicitHeight: 88
                    shape: "cookie9"
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
                    text: "Switch player"
                    onClicked: Mpris.cyclePlayer()
                }
            }
        }
    }
}
