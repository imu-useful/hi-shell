import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

// Focus, stopwatch and countdown tiles (tap to start / pause).
Row {
    spacing: 10

    component Tile: DesktopCard {
        id: tile
        property string icon
        property string label
        property string time
        property bool running
        default property alias extra: extraRow.data
        signal toggle

        width: 116
        height: 116
        baseColor: running ? Colors.m3primaryContainer : Colors.m3surfaceContainer

        StateLayer {
            onClicked: tile.toggle()
        }
        MaterialIcon {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            icon: tile.icon
            fill: 1
            iconSize: 24
            color: tile.running ? Colors.m3onPrimaryContainer : Colors.m3primary
        }
        ColumnLayout {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 12
            spacing: 0
            StyledText {
                text: tile.time
                font.pixelSize: 24
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: tile.running ? Colors.m3onPrimaryContainer : Colors.m3onSurface
            }
            StyledText {
                text: tile.label
                font.pixelSize: Appearance.font.size.labelMedium
                color: tile.running ? Colors.m3onPrimaryContainer : Colors.m3onSurfaceVariant
            }
            Row {
                id: extraRow
                spacing: 4
            }
        }
    }

    Tile {
        icon: Timers.onBreak ? "coffee" : "self_improvement"
        label: Timers.onBreak ? Translation.tr("Break") : Translation.tr("Focus")
        time: Timers.format(Timers.focusLeft)
        running: Timers.focusRunning
        onToggle: Timers.toggleFocus()
    }
    Tile {
        icon: "timer"
        label: Translation.tr("Stopwatch")
        time: Timers.format(Timers.stopwatchElapsed)
        running: Timers.stopwatchRunning
        onToggle: Timers.toggleStopwatch()
    }
    Tile {
        icon: "hourglass_top"
        label: Translation.tr("Countdown")
        time: Timers.format(Timers.countdownLeft)
        running: Timers.countdownRunning
        onToggle: Timers.toggleCountdown()

        Chip { text: "+1m"; implicitHeight: 22; onClicked: Timers.addCountdown(60) }
        Chip { text: "+5m"; implicitHeight: 22; onClicked: Timers.addCountdown(300) }
    }
}
