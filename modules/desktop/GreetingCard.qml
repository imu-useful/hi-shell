import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// "Hi, user!" with the time of day and today's date.
DesktopCard {
    implicitWidth: 380
    implicitHeight: 100

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        ShapeImage {
            implicitWidth: 72
            implicitHeight: 72
            shape: "cookie9"
            source: `file://${Paths.home}/.face`
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            readonly property int hour: clock.date.getHours()
            StyledText {
                text: `Hi, ${Quickshell.env("USER")}!`
                font.pixelSize: Appearance.font.size.titleLarge
                font.weight: Font.DemiBold
                color: Colors.m3primary
            }
            StyledText {
                text: parent.hour < 5 ? "Good night" : parent.hour < 12 ? "Good morning" : parent.hour < 18 ? "Good afternoon" : "Good evening"
            }
            StyledText {
                text: `Today · ${Qt.formatDate(clock.date, "dddd d MMM")}${Todo.pending ? " · " + Todo.pending + " tasks" : ""}`
                font.pixelSize: Appearance.font.size.labelMedium
                color: Colors.m3onSurfaceVariant
            }
        }
    }
}
