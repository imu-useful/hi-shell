import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
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
    // The wave on the progress bar kicks to the beat (services/Beat), only while playing in view.
    readonly property bool waveOn: Config.options.desktop.waveProgress
    readonly property bool beatWanted: lyricsShown && Mpris.playing && Appearance.anim.speed > 0 && waveOn && Config.options.desktop.waveBeat
    property bool beatCounted: false
    function syncBeat() {
        if (beatWanted !== beatCounted) {
            Beat.users += beatWanted ? 1 : -1;
            beatCounted = beatWanted;
        }
    }
    onBeatWantedChanged: syncBeat()
    onLyricsShownChanged: syncLyrics()
    Component.onCompleted: {
        syncLyrics();
        syncBeat();
    }
    Component.onDestruction: {
        if (counted)
            Lyrics.users--;
        if (beatCounted)
            Beat.users--;
    }

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

        // Progress: players report the position about once a second. While playing, each
        // report is glided to linearly over that second, so the bar moves continuously;
        // seeks and track changes ease. The played part is a travelling wave while playing.
        Rectangle {
            id: track
            Layout.fillWidth: true
            implicitHeight: 4
            visible: Mpris.length > 0
            color: "transparent"

            property real shown: Mpris.progress
            // Pointer on the bar or dragging it: the bar thickens and the handle shows.
            readonly property bool expanded: seekable && (seek.containsMouse || seeking)
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
                glideAnim.from = shown;
                glideAnim.to = to;
                // One position report while playing: run on at the speed of playback.
                const tick = Mpris.playing && step >= 0 && step * Mpris.length < 2.5;
                glideAnim.duration = tick ? 1000 : Appearance.anim.normal;
                glideAnim.easing.type = tick ? Easing.Linear : Easing.OutCubic;
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

            // The bar and its fill grow around the middle of the 4 px the layout gives them, so
            // the card doesn't change size.
            Rectangle {
                id: bar
                width: parent.width
                height: track.expanded ? 8 : 4
                anchors.verticalCenter: parent.verticalCenter
                radius: height / 2
                color: Colors.m3secondaryContainer
                Behavior on height { enabled: root.animate; SpatialAnim { duration: Appearance.anim.fast } }
            }
            // The played part: a sine wave while playing that flattens when paused. The wave is
            // drawn once, a wavelength wider than needed, and slid sideways, then clipped to the
            // played width: no per-frame work in JS.
            Item {
                id: played
                readonly property real wavelength: 26
                property real amplitude: Mpris.playing && root.waveOn ? 2.6 : 0
                readonly property real fill: track.width * Math.max(0, Math.min(1, track.seeking ? track.seekValue : track.shown))
                // The wave's sideways position (0..wavelength). It drifts steadily and every rise of
                // the bass (a drum hit) throws it forward, then the push dies away.
                property real phase: 0
                property real push: 0
                property real lastBass: 0
                FrameAnimation {
                    running: Mpris.playing && root.animate && root.waveOn
                    onTriggered: {
                        const dt = Math.min(0.1, frameTime);
                        const bass = Beat.bass;
                        const rise = root.beatWanted ? Math.max(0, bass - played.lastBass) : 0;
                        played.lastBass = bass;
                        played.push = played.push * Math.exp(-dt * 7) + rise * 600;
                        played.phase = (played.phase + (played.wavelength / 1.4 + played.push) * dt) % played.wavelength;
                    }
                }
                Behavior on amplitude { enabled: root.animate; NumberAnimation { duration: Appearance.anim.spatial; easing.type: Easing.OutCubic } }

                width: fill
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                Shape {
                    id: wave
                    height: parent.height
                    width: track.width + played.wavelength
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Colors.m3primary
                        strokeWidth: bar.height
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathPolyline {
                            path: {
                                const pts = [];
                                const mid = wave.height / 2;
                                for (let x = 0; x <= wave.width; x += 2)
                                    pts.push(Qt.point(x, mid + played.amplitude * Math.sin(x / played.wavelength * 2 * Math.PI)));
                                return pts;
                            }
                        }
                    }
                    x: -played.phase
                }
            }

            // The handle, while the pointer is over the bar or it's being dragged, with the time it
            // would seek to.
            Rectangle {
                id: handle
                visible: opacity > 0
                // Always there: it caps the wave. Taller while the pointer is on the bar.
                opacity: 1
                scale: track.expanded ? 1.15 : 1
                Behavior on opacity { enabled: root.animate; EffectAnim { duration: Appearance.anim.fast } }
                Behavior on scale { enabled: root.animate; SpringAnim { overshoot: 1.6 } }
                x: parent.width * Math.max(0, Math.min(1, track.seeking ? track.seekValue : track.shown)) - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 4
                height: 18
                radius: 2
                color: Colors.m3primary

                Rectangle {
                    opacity: track.seeking ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { enabled: root.animate; EffectAnim { duration: Appearance.anim.fast } }
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
                    // The bar is where the pointer was; the player's position arrives a moment later.
                    track.shown = valueAt(mouse.x);
                    Mpris.seekTo(valueAt(mouse.x));
                    track.seeking = false;
                }
                onCanceled: track.seeking = false
            }
        }

        // Lyrics: the current line in the middle, scrolling smoothly to the next.
        ListView {
            id: lyrics
            readonly property int rowHeight: 24
            readonly property bool available: Lyrics.synced && Lyrics.lines.length > 0
            // 0..1: the block opens and closes instead of the card jumping in height.
            property real reveal: available ? 1 : 0
            Behavior on reveal { enabled: root.animate; NumberAnimation { duration: Appearance.anim.spatial; easing.type: Easing.OutCubic } }
            // 0..1: a new song's lines fade in.
            property real fresh: 1

            Layout.fillWidth: true
            // The column's spacing goes away with the block.
            Layout.topMargin: -10 * (1 - reveal)
            implicitHeight: (rowHeight * 3 + spacing * 2) * reveal
            visible: reveal > 0
            opacity: reveal * fresh
            onAvailableChanged: if (available && root.animate) freshAnim.restart()
            Connections {
                target: Lyrics
                function onLinesChanged() {
                    if (lyrics.available && root.animate)
                        freshAnim.restart();
                }
            }
            NumberAnimation {
                id: freshAnim
                target: lyrics
                property: "fresh"
                from: 0
                to: 1
                duration: Appearance.anim.slow
                easing.type: Easing.OutCubic
            }
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
