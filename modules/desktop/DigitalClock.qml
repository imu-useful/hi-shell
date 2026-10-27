import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets

// Big "HH:MM" with a blinking colon. A digit that changes fades out upwards while the new
// one rises in from below.
ColumnLayout {
    spacing: -10

    SystemClock {
        id: clock
        // The colon blinks with the seconds; minutes are enough while windows cover it.
        precision: ShellState.desktopCovered ? SystemClock.Minutes : SystemClock.Seconds
    }

    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: 6

        component Digits: StyledText {
            font.family: Appearance.font.title
            font.pixelSize: 132
            font.weight: Font.Black
            font.features: { "tnum": 1 }
            style: Text.Outline
            styleColor: Qt.alpha(Colors.m3shadow ?? "black", 0.15)
        }

        // One changing digit: the old one leaves, the new one comes in.
        component Roll: Item {
            id: roll
            property string value
            property color color
            property string shown: value
            property string old: ""
            property real progress: 1

            implicitWidth: current.implicitWidth
            implicitHeight: current.implicitHeight

            onValueChanged: {
                old = shown;
                shown = value;
                progress = 0;
                // Not while the desktop is out of sight, nor with animations off.
                if (ShellState.desktopCovered || Appearance.anim.speed <= 0)
                    progress = 1;
                else
                    rollAnim.restart();
            }

            NumberAnimation {
                id: rollAnim
                target: roll
                property: "progress"
                to: 1
                duration: Appearance.anim.spatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.anim.effects
            }

            Digits {
                visible: roll.progress < 1
                text: roll.old
                color: roll.color
                opacity: 1 - roll.progress
                y: -roll.progress * roll.height * 0.35
            }
            Digits {
                id: current
                text: roll.shown
                color: roll.color
                opacity: roll.progress
                y: (1 - roll.progress) * roll.height * 0.35
            }
        }

        Row {
            spacing: 0
            Roll { value: Qt.formatTime(clock.date, "HH").charAt(0); color: Colors.m3primary }
            Roll { value: Qt.formatTime(clock.date, "HH").charAt(1); color: Colors.m3primary }
        }
        Digits {
            text: ":"
            color: Colors.m3onSurface
            // Seconds only tick while the desktop is in view (see precision above).
            opacity: clock.date.getSeconds() % 2 ? 0.25 : 0.9
            Behavior on opacity { EffectAnim {} }
        }
        Row {
            spacing: 0
            Roll { value: Qt.formatTime(clock.date, "mm").charAt(0); color: Colors.m3tertiary }
            Roll { value: Qt.formatTime(clock.date, "mm").charAt(1); color: Colors.m3tertiary }
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: clock.date.toLocaleDateString(Translation.locale, "dddd, d MMMM")
        font.pixelSize: Appearance.font.size.titleLarge
        font.weight: Font.Medium
        color: Colors.m3onSurface
        style: Text.Outline
        styleColor: Qt.alpha("black", 0.15)
    }
}
