import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.common
import qs.common.widgets

// Dynamic Island: a pill in the bar that shows one state at a time (for now only the clock).
// Press and hold: a ring is drawn along the pill's border and, once it closes (bar.island.holdDuration),
// the island moves to the next state (ShellState.startIslandHold; the clock widget does the same).
// A short press toggles the calendar, like the clock.
BarWidget {
    id: root

    readonly property var options: Config.options.bar.island

    // The states the island cycles through; the later stages (music, notifications, privacy, updates) add theirs.
    readonly property var states: ["default"]
    readonly property int stateIndex: ShellState.islandSwitches % states.length
    readonly property string currentState: states[stateIndex % states.length]

    // 0..1, how much of the hold has passed (a hold on the clock widget fills it too).
    readonly property real holdProgress: ShellState.islandHold

    padding: 4
    active: false
    contentWidth: vertical ? thickness : clockText.implicitWidth + 24
    contentHeight: vertical ? column.implicitHeight : thickness
    Behavior on contentWidth { SpatialAnim {} }

    Connections {
        target: ShellState
        function onIslandSwitchesChanged() { pulse.restart(); }
    }

    Component.onCompleted: ShellState.islandCount++
    Component.onDestruction: ShellState.islandCount--

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // The island's own body, over the widget's pill.
    Rectangle {
        id: body
        anchors.fill: parent
        radius: Appearance.rounding.full
        color: Colors.m3surfaceContainerHighest
        scale: mouse.pressed ? 0.96 : 1
        Behavior on scale { SpatialAnim { duration: Appearance.anim.fast } }

        SequentialAnimation {
            id: pulse
            NumberAnimation { target: body; property: "scale"; to: 1.08; duration: Appearance.anim.fast; easing.type: Easing.OutCubic }
            NumberAnimation { target: body; property: "scale"; to: 1; duration: Appearance.anim.normal; easing.type: Easing.OutBack }
        }

        // Default state: the time.
        StyledText {
            id: clockText
            visible: !root.vertical
            anchors.centerIn: parent
            text: Qt.formatDateTime(clock.date, Config.options.bar.clock.timeFormat)
            font.pixelSize: Appearance.font.size.normal
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Column {
            id: column
            visible: root.vertical
            anchors.centerIn: parent
            spacing: -2

            Repeater {
                model: Qt.formatDateTime(clock.date, "HH mm").split(" ")

                StyledText {
                    required property string modelData
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData
                    font.pixelSize: Appearance.font.size.bodyMedium
                    font.weight: Font.DemiBold
                }
            }
        }

        // The hold ring: a stroke along the pill border, drawn clockwise from the top centre.
        Shape {
            id: ring
            anchors.fill: parent
            visible: root.holdProgress > 0
            preferredRendererType: Shape.CurveRenderer

            readonly property real stroke: 2.5
            readonly property real r: Math.max(0, height / 2 - stroke / 2)
            readonly property real x0: stroke / 2
            readonly property real x1: width - stroke / 2
            readonly property real y0: stroke / 2
            readonly property real y1: height - stroke / 2
            readonly property real straight: Math.max(0, x1 - x0 - 2 * r)
            readonly property real perimeter: 2 * straight + 2 * Math.PI * r

            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.m3primary
                strokeWidth: ring.stroke
                capStyle: ShapePath.RoundCap
                // Dashes are in stroke widths: one dash as long as the progress, then a gap past the end.
                strokeStyle: ShapePath.DashLine
                dashPattern: [Math.max(0.001, root.holdProgress * ring.perimeter / ring.stroke), ring.perimeter / ring.stroke + 1]

                startX: (ring.x0 + ring.x1) / 2
                startY: ring.y0
                PathLine { x: ring.x1 - ring.r; y: ring.y0 }
                PathArc { x: ring.x1 - ring.r; y: ring.y1; radiusX: ring.r; radiusY: ring.r }
                PathLine { x: ring.x0 + ring.r; y: ring.y1 }
                PathArc { x: ring.x0 + ring.r; y: ring.y0; radiusX: ring.r; radiusY: ring.r }
                PathLine { x: (ring.x0 + ring.x1) / 2; y: ring.y0 }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor

        onPressed: ShellState.startIslandHold()
        onReleased: ShellState.endIslandHold()
        onCanceled: ShellState.endIslandHold()
        onClicked: {
            if (!ShellState.islandHeld)
                ShellState.calendarOpen = !ShellState.calendarOpen;
            ShellState.islandHeld = false;
        }
    }
}
