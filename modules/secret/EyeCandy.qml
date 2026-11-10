import QtQuick
import qs.common
import qs.common.widgets

// Keys "rice", "ricing", "eye candy", "eyecandy" and "trip": a silent neon show for showing off a rice.
// One shader (eyecandy.frag) draws four scenes: a warp tunnel, a kaleidoscope fractal, liquid
// chrome and a synthwave sun; this file blends them, keeps a 128 BPM beat that kicks the zoom and
// the glow, and swirls the picture while a scene changes. The colors start from the wallpaper's
// primary hue and keep drifting. Sparks fly out from the center on every beat.
Item {
    id: root

    required property bool revealed
    property real time: 0

    readonly property real sceneLength: 8
    readonly property real blendLength: 1.6
    readonly property int sceneCount: 4
    readonly property real cycle: sceneLength * sceneCount
    readonly property int sceneIndex: Math.floor((time % cycle) / sceneLength)
    readonly property real sceneTime: (time % cycle) - sceneIndex * sceneLength
    readonly property var captions: ["hi-shell", Translation.tr("Eye candy"), Translation.tr("Pure rice"), Translation.tr("Touch grass later")]

    readonly property real beatsPerSecond: 128 / 60
    readonly property real beat: Math.exp(-((time * beatsPerSecond) % 1) * 5)
    // 0 -> 1 over the blend at the end of a scene
    readonly property real blend: smooth((sceneTime - (sceneLength - blendLength)) / blendLength)
    // A swirl that peaks in the middle of the blend
    readonly property real warp: Math.sin(blend * Math.PI)

    property real baseHue: 0.75
    readonly property real hue: baseHue + time * 0.015

    Component.onCompleted: {
        const h = Colors.m3primary.hslHue;
        baseHue = h >= 0 ? h : 0.75;
    }

    FrameAnimation {
        running: root.revealed
        onTriggered: root.time += frameTime
    }

    function clamp(x) {
        return Math.max(0, Math.min(1, x));
    }

    function smooth(x) {
        const t = clamp(x);
        return t * t * (3 - 2 * t);
    }

    function weights() {
        const w = [0, 0, 0, 0];
        w[sceneIndex] = 1 - blend;
        w[(sceneIndex + 1) % sceneCount] += blend;
        return Qt.vector4d(w[0], w[1], w[2], w[3]);
    }

    ShaderEffect {
        anchors.fill: parent
        property vector2d res: Qt.vector2d(width, height)
        property real time: root.time
        property real beat: root.beat
        property real hue: root.hue
        property real warp: root.warp
        property vector4d mixw: root.weights()
        fragmentShader: Qt.resolvedUrl("eyecandy.frag.qsb")
    }

    // Sparks: each one leaves the center on a beat, flies out along its own angle and fades
    Repeater {
        model: 48

        Rectangle {
            id: spark

            required property int index
            readonly property real angle: index * 2.399963
            readonly property real lifeBeats: 3
            readonly property real age: ((root.time * root.beatsPerSecond + index * 0.37) % lifeBeats) / lifeBeats
            readonly property real dist: Math.pow(age, 1.6) * Math.max(root.width, root.height) * 0.6

            width: 4 + (index % 4) * 2
            height: width
            radius: width / 2
            x: root.width / 2 + Math.cos(angle + root.time * 0.3) * dist - width / 2
            y: root.height / 2 + Math.sin(angle + root.time * 0.3) * dist - height / 2
            scale: 0.4 + age * 1.6
            opacity: Math.sin(age * Math.PI) * 0.85
            color: Qt.hsla(((root.hue + index * 0.07) % 1 + 1) % 1, 1, 0.7, 1)
        }
    }

    LetterCaption {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.42 - height * 0.5
        text: root.captions[root.sceneIndex]
        time: root.time
        sceneTime: root.sceneTime
        sceneLength: root.sceneLength
        hue: root.hue
        fontSize: Math.min(140, root.height / 7.5, root.width / 11)
        outlineColor: Qt.rgba(0, 0, 0, 0.55)
        scale: 1 + 0.06 * root.beat
    }
}
