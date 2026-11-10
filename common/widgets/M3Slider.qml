import QtQuick
import qs.common
import qs.services

// Slider: a hairline for the rest of the track, a thick accent bar for the value, a narrow handle.
// Emits moved(value) on drag / click / scroll; `value` is 0..1 and owned by the caller.
// Changes animate (scroll, keys, other apps), except while the handle is dragged.
Item {
    id: root

    property real value: 0
    property real step: 0.05
    // Track position of something playing: the player's once-a-second reports (small
    // forward steps) are set directly instead of animating; seeks still ease.
    property bool playback: false

    signal moved(real value)

    implicitWidth: 200
    implicitHeight: 28

    readonly property real clamped: Math.max(0, Math.min(1, value))
    // What's drawn: follows `clamped` with an animation.
    property real shown: 0
    readonly property real handleX: shown * (width - handle.width)

    function glide() {
        glideAnim.stop();
        if (mouse.pressed || Appearance.anim.speed === 0) {
            shown = clamped;
            return;
        }
        const step = clamped - shown;
        // One position report while playing: run on at the speed of playback.
        const tick = playback && Mpris.playing && step >= 0 && step < 0.05;
        glideAnim.from = shown;
        glideAnim.to = clamped;
        glideAnim.duration = tick ? 1000 : Appearance.anim.normal;
        glideAnim.easing.type = tick ? Easing.Linear : Easing.OutCubic;
        glideAnim.start();
    }
    onClampedChanged: glide()
    Component.onCompleted: shown = clamped

    NumberAnimation {
        id: glideAnim
        target: root
        property: "shown"
    }

    function moveTo(x) {
        root.moved(Math.max(0, Math.min(1, (x - handle.width / 2) / (width - handle.width))));
    }

    // A player's progress: a wave for the played part.
    readonly property bool wavy: playback && Config.options.desktop.waveProgress
    readonly property int trackHeight: wavy ? 4 : 6

    // Inactive track: a hairline.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: root.handleX + handle.width + 3
        width: Math.max(0, root.width - x)
        height: Math.max(1, Appearance.edge)
        color: Colors.m3outline
    }

    // Active track
    Rectangle {
        visible: !root.wavy
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, root.handleX - 3)
        height: root.trackHeight
        radius: Math.min(Appearance.rounding.extraSmall, height / 2)
        color: Colors.m3primary
    }
    WaveFill {
        visible: root.wavy
        fill: Math.max(0, root.handleX - 3)
        thickness: root.trackHeight
        playing: Mpris.playing
    }

    Rectangle {
        id: handle
        x: root.handleX
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: mouse.pressed ? 22 : mouse.containsMouse ? 20 : 16
        radius: 1
        color: Colors.m3onSurface
        Behavior on height { NumberAnimation { duration: 100 } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: mouse => root.moveTo(mouse.x)
        onPositionChanged: mouse => root.moveTo(mouse.x)
    }

    WheelSteps {
        onStepped: steps => root.moved(Math.max(0, Math.min(1, root.clamped + steps * root.step)))
    }
}
