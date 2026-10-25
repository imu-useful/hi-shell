import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// Now playing with three lines of synced lyrics around the current one.
DesktopCard {
    id: root

    visible: Mpris.hasPlayer
    implicitWidth: 380
    implicitHeight: content.implicitHeight + 28

    // Lyrics only tick while someone can see them.
    readonly property bool lyricsShown: visible && !ShellState.desktopCovered
    property bool counted: false
    function syncLyrics() {
        if (lyricsShown !== counted) {
            Lyrics.users += lyricsShown ? 1 : -1;
            counted = lyricsShown;
        }
    }
    onLyricsShownChanged: syncLyrics()
    Component.onCompleted: syncLyrics()
    Component.onDestruction: if (counted) Lyrics.users--

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            ShapeImage {
                implicitWidth: 84
                implicitHeight: 84
                shape: "square"
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
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Mpris.artist
                    color: Colors.m3onSurfaceVariant
                }
                RowLayout {
                    spacing: 2
                    IconButton { icon: "skip_previous"; onClicked: Mpris.previous() }
                    IconButton {
                        filled: true
                        icon: Mpris.playing ? "pause" : "play_arrow"
                        onClicked: Mpris.togglePlaying()
                    }
                    IconButton { icon: "skip_next"; onClicked: Mpris.next() }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 4
            radius: 2
            visible: Mpris.length > 0
            color: Colors.m3secondaryContainer
            Rectangle {
                width: parent.width * Mpris.progress
                height: parent.height
                radius: 2
                color: Colors.m3primary
            }
        }

        // Previous / current / next lyric line.
        ColumnLayout {
            Layout.fillWidth: true
            visible: Lyrics.synced && Lyrics.lines.length > 0
            spacing: 2

            Repeater {
                model: [-1, 0, 1]

                StyledText {
                    required property int modelData
                    readonly property var line: Lyrics.lines[Lyrics.index + modelData]
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: line ? (line.text || "♪") : " "
                    font.pixelSize: modelData === 0 ? Appearance.font.size.bodyLarge : Appearance.font.size.labelMedium
                    font.weight: modelData === 0 ? Font.DemiBold : Font.Normal
                    color: modelData === 0 ? Colors.m3primary : Colors.m3onSurfaceVariant
                    opacity: modelData === 0 ? 1 : 0.6
                }
            }
        }
    }
}
