import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.services

// "Hi, user!" with the time of day, a short phrase for it and today's date. The phrase
// changes once a day (same all day), picked from the set for the current part of the day.
DesktopCard {
    id: root
    implicitWidth: 380
    implicitHeight: 116

    // Day of the year, for picking the phrase.
    readonly property int dayOfYear: Math.floor((clock.date - new Date(clock.date.getFullYear(), 0, 0)) / 86400000)

    function phrase(hour) {
        const set = hour < 5 ? [Translation.tr("Rest well when you can."), Translation.tr("Late hours? Keep it short."), Translation.tr("The world can wait until morning.")]
            : hour < 12 ? [Translation.tr("Coffee first, then the rest."), Translation.tr("A fresh day, a clean start."), Translation.tr("Small steps still count.")]
            : hour < 18 ? [Translation.tr("Halfway there. Keep going."), Translation.tr("Take a short break if you need one."), Translation.tr("You're doing better than you think.")]
            : [Translation.tr("A good day deserves a good evening."), Translation.tr("Wind down, you've earned it."), Translation.tr("Tomorrow is a new page.")];
        return set[dayOfYear % set.length];
    }

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
                Layout.fillWidth: true
                text: root.phrase(parent.hour)
                elide: Text.ElideRight
                font.italic: true
                font.pixelSize: Appearance.font.size.labelMedium + 1
                color: Colors.m3onSurfaceVariant
            }
            StyledText {
                text: [Translation.tr("Today"), clock.date.toLocaleDateString(Translation.locale, "dddd d MMM"), Todo.pending ? Translation.trn("%1 task", "%1 tasks", Todo.pending) : ""].filter(s => s).join(" · ")
                font.pixelSize: Appearance.font.size.labelMedium
                color: Colors.m3onSurfaceVariant
            }
        }
    }
}
