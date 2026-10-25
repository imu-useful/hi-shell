import QtQuick
import Quickshell
import qs.common

// Bar clock; click toggles the calendar popup.
Rectangle {
    implicitWidth: label.implicitWidth + 24
    implicitHeight: Appearance.sizes.barHeight - 12
    radius: Appearance.rounding.full
    color: ShellState.calendarOpen || mouse.containsMouse ? Qt.lighter(Colors.m3secondaryContainer, 1.15) : Colors.m3secondaryContainer

    Behavior on color { ColorAnimation { duration: 150 } }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "ddd d MMM  HH:mm")
        font.family: Appearance.font.main
        font.pixelSize: Appearance.font.size.normal
        font.weight: Font.Medium
        color: Colors.m3onSecondaryContainer
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.calendarOpen = !ShellState.calendarOpen
    }
}
