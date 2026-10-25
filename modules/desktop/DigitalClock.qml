import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets

// Big "HH:MM" with a blinking colon.
ColumnLayout {
    spacing: -10

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
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

        Digits {
            text: Qt.formatTime(clock.date, "HH")
            color: Colors.m3primary
        }
        Digits {
            text: ":"
            color: Colors.m3onSurface
            opacity: clock.date.getSeconds() % 2 ? 0.25 : 0.9
            Behavior on opacity { EffectAnim {} }
        }
        Digits {
            text: Qt.formatTime(clock.date, "mm")
            color: Colors.m3tertiary
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: Qt.formatDate(clock.date, "dddd, d MMMM")
        font.pixelSize: Appearance.font.size.titleLarge
        font.weight: Font.Medium
        color: Colors.m3onSurface
        style: Text.Outline
        styleColor: Qt.alpha("black", 0.15)
    }
}
