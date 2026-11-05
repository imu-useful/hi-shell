import QtQuick
import QtQuick.Shapes
import qs.common
import qs.services

// The played part of a player's progress bar: a sine wave that travels while the music plays,
// flattens when paused and (with cava) is thrown sideways by every drum hit. The wave is drawn
// once, a wavelength wider than needed, slid sideways and clipped to `fill`: no per-frame JS
// path work. Sits vertically centered on its parent's middle; the caller sets x / anchors.
Item {
    id: root

    // Width of the played part, px.
    property real fill: 0
    property real thickness: 4
    property color color: Colors.m3primary
    // The waves move (music is playing and the bar can be seen).
    property bool playing: false
    property real wavelength: 26
    readonly property bool enabledInConfig: Config.options.desktop.waveProgress
    readonly property bool moving: playing && enabledInConfig && visible && Appearance.anim.speed > 0
    readonly property bool beating: moving && Config.options.desktop.waveBeat

    // Count in with Beat while the wave kicks to the beat.
    property bool counted: false
    function syncBeat() {
        if (beating !== counted) {
            Beat.users += beating ? 1 : -1;
            counted = beating;
        }
    }
    onBeatingChanged: syncBeat()
    Component.onCompleted: syncBeat()
    Component.onDestruction: if (counted) Beat.users--

    property real amplitude: playing && enabledInConfig ? Math.max(2.6, thickness * 0.5) : 0
    Behavior on amplitude { enabled: Appearance.anim.speed > 0; NumberAnimation { duration: Appearance.anim.spatial; easing.type: Easing.OutCubic } }

    // The wave's sideways position (0..wavelength): drifts steadily, and every rise of the bass
    // throws it forward, then the push dies away.
    property real phase: 0
    property real push: 0
    property real lastBass: 0
    FrameAnimation {
        running: root.moving
        onTriggered: {
            const dt = Math.min(0.1, frameTime);
            const bass = Beat.bass;
            const rise = root.beating ? Math.max(0, bass - root.lastBass) : 0;
            root.lastBass = bass;
            root.push = root.push * Math.exp(-dt * 7) + rise * 600;
            root.phase = (root.phase + (root.wavelength / 1.4 + root.push) * dt) % root.wavelength;
        }
    }

    width: Math.max(0, fill)
    height: thickness + 16
    anchors.verticalCenter: parent.verticalCenter
    clip: true

    Shape {
        id: wave
        x: -root.phase
        height: parent.height
        width: root.parent ? root.parent.width + root.wavelength : root.wavelength
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathPolyline {
                path: {
                    const pts = [];
                    const mid = wave.height / 2;
                    for (let x = 0; x <= wave.width; x += 2)
                        pts.push(Qt.point(x, mid + root.amplitude * Math.sin(x / root.wavelength * 2 * Math.PI)));
                    return pts;
                }
            }
        }
    }
}
