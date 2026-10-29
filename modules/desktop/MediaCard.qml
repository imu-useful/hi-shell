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

    // Smooth motion only while the card can be seen.
    readonly property bool animate: lyricsShown && Appearance.anim.speed > 0

    // Text that fades in with a small slide when it changes (track change).
    component SwapText: StyledText {
        id: swap
        transform: Translate { id: shift }
        onTextChanged: if (root.animate) swapIn.restart()
        ParallelAnimation {
            id: swapIn
            NumberAnimation { target: swap; property: "opacity"; from: 0; to: 1; duration: Appearance.anim.slow; easing.type: Easing.OutCubic }
            NumberAnimation { target: shift; property: "x"; from: 10; to: 0; duration: Appearance.anim.spatial; easing.type: Easing.OutCubic }
        }
    }

    CoverBackdrop {
        source: Mpris.artUrl
        radius: root.radius
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            // Cover art, cross-faded on track change.
            Item {
                id: art
                implicitWidth: 84
                implicitHeight: 84

                readonly property string url: Mpris.artUrl
                property bool flip: false
                onUrlChanged: {
                    flip = !flip;
                    (flip ? artB : artA).source = url;
                }
                Component.onCompleted: artA.source = url

                ShapeImage {
                    id: artA
                    anchors.fill: parent
                    shape: "square"
                    opacity: !art.flip && status === Image.Ready ? 1 : 0
                    Behavior on opacity { EffectAnim { duration: Appearance.anim.slow } }
                }
                ShapeImage {
                    id: artB
                    anchors.fill: parent
                    shape: "square"
                    opacity: art.flip && status === Image.Ready ? 1 : 0
                    Behavior on opacity { EffectAnim { duration: Appearance.anim.slow } }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                SwapText {
                    Layout.fillWidth: true
                    text: Mpris.title
                    font.pixelSize: Appearance.font.size.titleMedium
                    font.weight: Font.Medium
                }
                SwapText {
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

        // Progress: players report the position about once a second. Those small steps
        // (a pixel or two) are set directly: gliding between them would redraw the whole
        // desktop at 60 fps for as long as music plays. Seeks and track changes ease.
        Rectangle {
            id: track
            Layout.fillWidth: true
            implicitHeight: 4
            radius: 2
            visible: Mpris.length > 0
            color: Colors.m3secondaryContainer

            property real shown: Mpris.progress
            // Dragging the bar to seek: where the pointer is (0..1) until it's let go.
            property bool seeking: false
            property real seekValue: 0
            readonly property bool seekable: Mpris.active?.canSeek ?? false

            function glide() {
                if (seeking)
                    return;
                const to = Mpris.progress;
                const step = to - shown;
                glideAnim.stop();
                if (!root.animate) {
                    shown = to;
                    return;
                }
                // One position report while playing.
                if (Mpris.playing && step >= 0 && step * Mpris.length < 2.5) {
                    shown = to;
                    return;
                }
                glideAnim.from = shown;
                glideAnim.to = to;
                glideAnim.duration = Appearance.anim.normal;
                glideAnim.easing.type = Easing.OutCubic;
                glideAnim.start();
            }

            Connections {
                target: Mpris
                function onProgressChanged() {
                    track.glide();
                }
            }
            NumberAnimation {
                id: glideAnim
                target: track
                property: "shown"
            }

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, track.seeking ? track.seekValue : track.shown))
                height: parent.height
                radius: 2
                color: Colors.m3primary
            }

            // The handle, while the pointer is over the bar or it's being dragged, with the time it
            // would seek to.
            Rectangle {
                id: handle
                visible: track.seekable && (seek.containsMouse || track.seeking)
                x: parent.width * Math.max(0, Math.min(1, track.seeking ? track.seekValue : track.shown)) - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 4
                height: 16
                radius: 2
                color: Colors.m3primary

                Rectangle {
                    visible: track.seeking
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.top
                    anchors.bottomMargin: 6
                    implicitWidth: seekTime.implicitWidth + 14
                    implicitHeight: 22
                    radius: 11
                    color: Colors.m3primary
                    StyledText {
                        id: seekTime
                        anchors.centerIn: parent
                        text: Timers.format(track.seekValue * Mpris.length)
                        font.pixelSize: Appearance.font.size.labelSmall
                        font.features: { "tnum": 1 }
                        color: Colors.m3onPrimary
                    }
                }
            }

            // Click or drag along the bar to seek (not while widgets are being edited: then a drag
            // moves the widget).
            MouseArea {
                id: seek
                anchors.fill: parent
                anchors.topMargin: -10
                anchors.bottomMargin: -10
                enabled: track.seekable && !ShellState.desktopEditing
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                function valueAt(x) {
                    return Math.max(0, Math.min(1, x / track.width));
                }
                onPressed: mouse => {
                    track.seeking = true;
                    track.seekValue = valueAt(mouse.x);
                }
                onPositionChanged: mouse => {
                    if (track.seeking)
                        track.seekValue = valueAt(mouse.x);
                }
                onReleased: mouse => {
                    Mpris.seekTo(valueAt(mouse.x));
                    track.shown = valueAt(mouse.x);
                    track.seeking = false;
                }
                onCanceled: track.seeking = false
            }
        }

        // Lyrics: the current line in the middle, scrolling smoothly to the next.
        ListView {
            id: lyrics
            readonly property int rowHeight: 24

            Layout.fillWidth: true
            implicitHeight: rowHeight * 3 + spacing * 2
            visible: Lyrics.synced && Lyrics.lines.length > 0
            clip: true
            interactive: false
            spacing: 2
            model: Lyrics.lines
            currentIndex: Lyrics.index
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: (height - rowHeight) / 2
            preferredHighlightEnd: (height + rowHeight) / 2
            highlightMoveDuration: root.animate ? Appearance.anim.spatial : 0
            highlightMoveVelocity: -1

            delegate: StyledText {
                required property var modelData
                required property int index
                readonly property bool current: index === Lyrics.index

                width: lyrics.width
                height: lyrics.rowHeight
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: modelData.text || "♪"
                // One size for every row (rows keep their height); the current one is scaled up.
                font.pixelSize: Appearance.font.size.bodyLarge
                font.weight: current ? Font.DemiBold : Font.Normal
                color: current ? Colors.m3primary : Colors.m3onSurfaceVariant
                opacity: current ? 1 : 0.55
                scale: current ? 1 : 0.84

                Behavior on scale { SpatialAnim { duration: Appearance.anim.spatial } }
                Behavior on opacity { EffectAnim { duration: Appearance.anim.slow } }
                Behavior on color { ColorAnim { duration: Appearance.anim.slow } }
            }
        }
    }
}
