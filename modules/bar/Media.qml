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
    Layout.maximumWidth: pick("maxWidth", Config.options.bar.media.maxWidth)
    contentWidth: vertical ? artSize : artSize + 8 + label.implicitWidth + 6 + playButton.width + 2
    contentHeight: artSize

    clickable: true
    onClicked: mouse => mouse.button === Qt.MiddleButton ? Mpris.next() : Mpris.togglePlaying()
    // Scroll for the player's volume (when it has one).
    scrollable: Mpris.active?.volumeSupported ?? false
    onScrolled: steps => Mpris.active.volume = Math.max(0, Math.min(1, Mpris.active.volume + steps * 0.05))

    ShapeImage {
        id: art
        anchors.verticalCenter: parent.verticalCenter
        x: root.vertical ? (parent.width - width) / 2 : 0
        width: root.artSize
        height: root.artSize
        shape: "square"
        source: Mpris.artUrl
        // Spinning turns a cached texture instead of re-masking the cover every frame.
        layer.enabled: spin.running
        layer.smooth: true

        // Like a record: a turn every 20 s while playing, stopping where it is on pause.
        // 15 steps a second look smooth at this speed; a 60 fps animation would redraw
        // the whole bar every frame for as long as music plays.
        Timer {
            id: spin
            running: Config.options.bar.media.spinArt && Mpris.playing && Appearance.anim.speed > 0
            interval: 66
            repeat: true
            onTriggered: art.rotation = (art.rotation + 360 * interval / 20000) % 360
        }
        Connections {
            target: Config.options.bar.media
            function onSpinArtChanged() {
                if (!Config.options.bar.media.spinArt)
                    art.rotation = 0;
            }
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
        width: root.artSize + 2
        height: root.artSize - 2
        radius: Appearance.shape.chip
        color: Mpris.playing ? Colors.m3primary : "transparent"
        border.width: Mpris.playing ? 0 : Math.max(1, Appearance.edge)
        border.color: Colors.m3outline
        Behavior on color { ColorAnim {} }

        MaterialIcon {
            anchors.centerIn: parent
            icon: Mpris.playing ? "pause" : "play_arrow"
            fill: 1
            iconSize: 18
            color: Mpris.playing ? Colors.m3onPrimary : Colors.m3onSurfaceVariant
        }
    }

    StyledPopup {
        target: root
        hovered: root.hovered
        edge: root.popupEdge

        MediaControls {}
    }
}
