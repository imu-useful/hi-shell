import QtQuick
import Quickshell
import qs.common

Rectangle {
    implicitWidth: label.implicitWidth + 24
    implicitHeight: Style.barHeight - 12
    radius: Style.radiusFull
    color: Colors.m3secondaryContainer

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "ddd d MMM  HH:mm")
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize
        font.weight: Font.Medium
        color: Colors.m3onSecondaryContainer
    }
}
