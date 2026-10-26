import QtQuick
import qs.common

// Material 3 slider: thick track, active part in primary, bar-shaped handle.
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
    implicitHeight: 40

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
        if (playback && step >= 0 && step < 0.05) {
            shown = clamped;
            return;
        }
        glideAnim.from = shown;
        glideAnim.to = clamped;
        glideAnim.duration = Appearance.anim.normal;
        glideAnim.easing.type = Easing.OutCubic;
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

    // Inactive track
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: root.handleX + handle.width + 4
        width: Math.max(0, root.width - x)
        height: 16
        radius: 8
        color: Colors.m3secondaryContainer
    }

    // Active track
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, root.handleX - 4)
        height: 16
        radius: 8
        color: Colors.m3primary
    }

    Rectangle {
        id: handle
        x: root.handleX
        anchors.verticalCenter: parent.verticalCenter
        width: 4
        height: mouse.pressed ? 40 : 32
        radius: 2
        color: Colors.m3primary
        Behavior on height { NumberAnimation { duration: 100 } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: mouse => root.moveTo(mouse.x)
        onPositionChanged: mouse => root.moveTo(mouse.x)
    }

    WheelSteps {
        onStepped: steps => root.moved(Math.max(0, Math.min(1, root.clamped + steps * root.step)))
    }
}
