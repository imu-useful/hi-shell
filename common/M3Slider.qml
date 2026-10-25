import QtQuick

// Material 3 slider: thick track, active part in primary, bar-shaped handle.
// Emits moved(value) on drag / click / scroll; `value` is 0..1 and owned by the caller.
Item {
    id: root

    property real value: 0
    property real step: 0.05

    signal moved(real value)

    implicitWidth: 200
    implicitHeight: 40

    readonly property real clamped: Math.max(0, Math.min(1, value))
    readonly property real handleX: clamped * (width - handle.width)

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

    WheelHandler {
        onWheel: event => root.moved(Math.max(0, Math.min(1, root.clamped + (event.angleDelta.y > 0 ? root.step : -root.step))))
    }
}
