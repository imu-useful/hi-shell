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
        // The time can be typed (click it): minutes, "mm:ss", "h:mm:ss", "25m" or "30s".
        property bool editable: false
        default property alias buttons: buttonRow.data
        signal toggle
        signal edited(string text)

        Layout.fillWidth: true
        implicitHeight: layout.implicitHeight + 28
        radius: Appearance.shape.card
        color: running ? Qt.alpha(Colors.m3primary, 0.12) : "transparent"
        border.width: Math.max(1, Appearance.edge)
        border.color: running ? Colors.m3primary : Colors.m3outlineVariant
        Behavior on color { ColorAnim {} }
        Behavior on border.color { ColorAnim {} }

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
                trackColor: Colors.m3outlineVariant

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: card.icon
                    iconSize: 24
                    color: card.running ? Colors.m3primary : Colors.m3onSurfaceVariant
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: card.title
                    font.family: Appearance.font.mono
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: Appearance.font.labelSpacing
                    font.pixelSize: Appearance.font.size.labelSmall
                    color: card.running ? Colors.m3primary : Colors.m3onSurfaceVariant
                }
                StyledText {
                    id: shownTime
                    Layout.fillWidth: true
                    visible: !typing.visible
                    text: card.time
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.font.size.headlineSmall
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                    color: card.running ? Colors.m3primary : Colors.m3onSurface
                    MouseArea {
                        anchors.fill: parent
                        enabled: card.editable
                        cursorShape: Qt.IBeamCursor
                        onClicked: {
                            typing.text = card.time;
                            typing.visible = true;
                            typing.forceActiveFocus();
                            typing.selectAll();
                        }
                    }
                }
                TextInput {
                    id: typing
                    Layout.fillWidth: true
                    visible: false
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.font.size.headlineSmall
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                    color: Colors.m3primary
                    selectByMouse: true
                    onAccepted: {
                        card.edited(text);
                        visible = false;
                        focus = false;
                    }
                    Keys.onEscapePressed: {
                        visible = false;
                        focus = false;
                    }
                    onActiveFocusChanged: if (!activeFocus && visible) {
                        card.edited(text);
                        visible = false;
                    }
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
            title: (Timers.onBreak ? Translation.tr("Break") : Translation.tr("Focus")) + " · " + Translation.tr("%1 min").arg(Math.round((Timers.onBreak ? Timers.breakMinutes * 60 : Timers.focusTotal) / 60))
            time: Timers.format(Timers.focusLeft)
            progress: 1 - Timers.focusLeft / (Timers.onBreak ? Timers.breakMinutes * 60 : Timers.focusTotal)
            running: Timers.focusRunning
            editable: !Timers.focusRunning && !Timers.onBreak
            onToggle: Timers.toggleFocus()
            onEdited: text => Timers.setFocusTime(Timers.parse(text))

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
            editable: !Timers.countdownRunning
            onToggle: Timers.toggleCountdown()
            onEdited: text => Timers.setCountdownTime(Timers.parse(text))

            Chip { text: "+1 m"; implicitHeight: 26; onClicked: Timers.addCountdown(60) }
            Chip { text: "+5 m"; implicitHeight: 26; onClicked: Timers.addCountdown(300) }
            Chip { text: Translation.tr("Reset"); implicitHeight: 26; onClicked: Timers.resetCountdown() }
        }
    }
}
