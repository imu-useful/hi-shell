import QtQuick
import qs.common
import qs.common.widgets
import qs.services

// The running timer: the countdown, else the stopwatch, else the focus timer; hidden while none runs.
// Click = pause / resume it.
BarWidget {
    id: root

    readonly property string kind: Timers.countdownRunning ? "countdown" : Timers.stopwatchRunning ? "stopwatch" : Timers.focusRunning ? "focus" : ""
    readonly property string text: kind === "countdown" ? Timers.format(Timers.countdownLeft) : kind === "stopwatch" ? Timers.format(Timers.stopwatchElapsed) : Timers.format(Timers.focusLeft)

    shown: kind !== ""
    clickable: true
    padding: 9
    contentWidth: grid.implicitWidth
    contentHeight: grid.implicitHeight
    onClicked: kind === "countdown" ? Timers.toggleCountdown() : kind === "stopwatch" ? Timers.toggleStopwatch() : Timers.toggleFocus()

    Grid {
        id: grid
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        spacing: 4
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        MaterialIcon {
            icon: root.kind === "stopwatch" ? "timer" : root.kind === "focus" ? "psychology" : "hourglass_top"
            iconSize: 17
            color: Colors.m3primary
        }
        StyledText {
            text: root.text
            font.pixelSize: Appearance.font.size.labelMedium + 1
            font.features: { "tnum": 1 }
        }
    }
}
