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
                text: Translation.tr("Hi, %1!").arg(Quickshell.env("USER"))
                font.pixelSize: Appearance.font.size.titleLarge
                font.weight: Font.DemiBold
                color: Colors.m3primary
            }
            StyledText {
                text: parent.hour < 5 ? Translation.tr("Good night") : parent.hour < 12 ? Translation.tr("Good morning") : parent.hour < 18 ? Translation.tr("Good afternoon") : Translation.tr("Good evening")
            }
            StyledText {
                text: [Translation.tr("Today"), clock.date.toLocaleDateString(Translation.locale, "dddd d MMM"), Todo.pending ? Translation.trn("%1 task", "%1 tasks", Todo.pending) : ""].filter(s => s).join(" · ")
                font.pixelSize: Appearance.font.size.labelMedium
                color: Colors.m3onSurfaceVariant
            }
        }
    }
}
