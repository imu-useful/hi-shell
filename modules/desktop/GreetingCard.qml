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

    // The phrases for each part of the day; one of them for the whole day.
    readonly property var night: [
        Translation.tr("Rest well when you can."),
        Translation.tr("Late hours? Keep it short."),
        Translation.tr("The world can wait until morning."),
        Translation.tr("Sleep is part of the work."),
        Translation.tr("The night is for quiet ideas."),
        Translation.tr("Tomorrow's you will thank you."),
        Translation.tr("Even the moon takes it slow."),
        Translation.tr("One more thing, then bed.")
    ]
    readonly property var morning: [
        Translation.tr("Coffee first, then the rest."),
        Translation.tr("A fresh day, a clean start."),
        Translation.tr("Small steps still count."),
        Translation.tr("Today is yours to shape."),
        Translation.tr("Start with the easy one."),
        Translation.tr("A slow morning is still a good one."),
        Translation.tr("Drink some water first."),
        Translation.tr("Breathe in, the day is long.")
    ]
    readonly property var day: [
        Translation.tr("Halfway there. Keep going."),
        Translation.tr("Take a short break if you need one."),
        Translation.tr("You're doing better than you think."),
        Translation.tr("Stretch your shoulders a little."),
        Translation.tr("One thing at a time."),
        Translation.tr("Lunch counts as progress."),
        Translation.tr("Look away from the screen for a moment."),
        Translation.tr("Focus beats speed.")
    ]
    readonly property var evening: [
        Translation.tr("A good day deserves a good evening."),
        Translation.tr("Wind down, you've earned it."),
        Translation.tr("Tomorrow is a new page."),
        Translation.tr("Leave the rest for tomorrow."),
        Translation.tr("Time for something just for you."),
        Translation.tr("Dim the lights, slow the pace."),
        Translation.tr("What went well today?"),
        Translation.tr("A quiet evening is a gift.")
    ]

    function phrase(hour) {
        const set = hour < 5 ? night : hour < 12 ? morning : hour < 18 ? day : evening;
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
                // A long phrase shrinks to fit the line instead of being cut off.
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 9
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
