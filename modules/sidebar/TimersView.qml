import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Focus (pomodoro), stopwatch and countdown.
StyledFlickable {
    id: root

    contentHeight: column.implicitHeight

    component TimerCard: Rectangle {
        id: card
        property string icon
        property string title
        property string time
        property real progress: -1
        property bool running: false
        default property alias buttons: buttonRow.data
        signal toggle

        Layout.fillWidth: true
        implicitHeight: layout.implicitHeight + 28
        radius: Appearance.rounding.extraLarge
        color: running ? Colors.m3primaryContainer : Colors.m3surfaceContainer
        Behavior on color { ColorAnim {} }

        RowLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            CircularProgress {
                implicitWidth: 56
                implicitHeight: 56
                lineWidth: 4
                value: card.progress < 0 ? 0 : card.progress
                color: Colors.m3primary
                trackColor: card.running ? Qt.alpha(Colors.m3onPrimaryContainer, 0.15) : Colors.m3secondaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: card.icon
                    fill: 1
                    iconSize: 24
                    color: card.running ? Colors.m3onPrimaryContainer : Colors.m3onSurfaceVariant
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: card.title
                    font.pixelSize: Appearance.font.size.labelMedium
                    color: card.running ? Colors.m3onPrimaryContainer : Colors.m3onSurfaceVariant
                }
                StyledText {
                    Layout.fillWidth: true
                    text: card.time
                    font.pixelSize: Appearance.font.size.headlineSmall
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                    color: card.running ? Colors.m3onPrimaryContainer : Colors.m3onSurface
                }
                RowLayout {
                    id: buttonRow
                    Layout.alignment: Qt.AlignLeft
                    Layout.topMargin: 4
                    spacing: 4
                }
            }

            IconButton {
                implicitWidth: 48
                implicitHeight: 48
                filled: true
                icon: card.running ? "pause" : "play_arrow"
                onClicked: card.toggle()
            }
        }
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: 10

        TimerCard {
            icon: Timers.onBreak ? "coffee" : "self_improvement"
            title: (Timers.onBreak ? Translation.tr("Break") : Translation.tr("Focus")) + " · " + Translation.tr("%1 min").arg(Timers.onBreak ? Timers.breakMinutes : Timers.focusMinutes)
            time: Timers.format(Timers.focusLeft)
            progress: 1 - Timers.focusLeft / ((Timers.onBreak ? Timers.breakMinutes : Timers.focusMinutes) * 60)
            running: Timers.focusRunning
            onToggle: Timers.toggleFocus()

            Chip { text: Translation.tr("Reset"); implicitHeight: 26; onClicked: Timers.resetFocus() }
        }

        TimerCard {
            icon: "timer"
            title: Timers.laps.length ? Translation.tr("Stopwatch · lap %1: %2").arg(Timers.laps.length).arg(Timers.format(Timers.laps[0])) : Translation.tr("Stopwatch")
            time: Timers.format(Timers.stopwatchElapsed)
            progress: (Timers.stopwatchElapsed % 60) / 60
            running: Timers.stopwatchRunning
            onToggle: Timers.toggleStopwatch()

            Chip { text: Translation.tr("Lap"); implicitHeight: 26; enabled: Timers.stopwatchRunning; onClicked: Timers.lap() }
            Chip { text: Translation.tr("Reset"); implicitHeight: 26; onClicked: Timers.resetStopwatch() }
        }

        TimerCard {
            icon: "hourglass_top"
            title: Translation.tr("Countdown")
            time: Timers.format(Timers.countdownLeft)
            progress: Timers.countdownTotal > 0 ? 1 - Timers.countdownLeft / Timers.countdownTotal : 0
            running: Timers.countdownRunning
            onToggle: Timers.toggleCountdown()

            Chip { text: "+1 m"; implicitHeight: 26; onClicked: Timers.addCountdown(60) }
            Chip { text: "+5 m"; implicitHeight: 26; onClicked: Timers.addCountdown(300) }
            Chip { text: Translation.tr("Reset"); implicitHeight: 26; onClicked: Timers.resetCountdown() }
        }
    }
}
