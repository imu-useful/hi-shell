import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

// Screen time: today's apps (how long each had the focus), the week, and a daily limit per app.
ColumnLayout {
    id: root

    spacing: 24

    readonly property var todays: ScreenTime.totals(ScreenTime.today)
    readonly property int todayTotal: todays.reduce((sum, a) => sum + a.seconds, 0)
    readonly property int topSeconds: todays.length ? todays[0].seconds : 1
    readonly property var shownApps: todays.slice(0, 12)
    // The chart: how many weeks back (0 to 3) and the day picked in it ("" = none).
    property int weeksAgo: 0
    property string pickedDay: ""
    readonly property var week: ScreenTime.week(weeksAgo)
    readonly property var pickedApps: pickedDay ? ScreenTime.totals(pickedDay).slice(0, 12) : []
    readonly property int pickedTotal: pickedApps.length ? ScreenTime.totals(pickedDay).reduce((sum, a) => sum + a.seconds, 0) : 0
    function dayLabel(key, format) {
        return new Date(key + "T12:00").toLocaleDateString(Translation.locale, format);
    }
    function weekTitle() {
        if (weeksAgo === 0)
            return Translation.tr("The last 7 days");
        return `${dayLabel(week[0].key, "d MMM")} – ${dayLabel(week[6].key, "d MMM")}`;
    }
    readonly property int weekPeak: Math.max(1, ...week.map(d => d.seconds))

    function duration(seconds) {
        const m = Math.floor(seconds / 60), h = Math.floor(m / 60);
        if (m === 0)
            return Translation.tr("< 1 min");
        return h ? (m % 60 ? Translation.tr("%1 h %2 min").arg(h).arg(m % 60) : Translation.tr("%1 h").arg(h)) : Translation.tr("%1 min").arg(m);
    }
    // A line about today's total, by how long it is; one of a few for each range, the same all day.
    readonly property var phrases: [
        { upTo: 1, icon: "sentiment_very_satisfied", set: [Translation.tr("Barely any screen time. Well done!"), Translation.tr("Light day so far, great."), Translation.tr("Plenty of time left for real life.")] },
        { upTo: 3, icon: "thumb_up", set: [Translation.tr("A solid hour or two. Nice job!"), Translation.tr("A healthy amount, keep it up."), Translation.tr("Good balance today, well done.")] },
        { upTo: 6, icon: "visibility", set: [Translation.tr("That's a fair bit. Maybe a break?"), Translation.tr("Rest your eyes for a minute."), Translation.tr("Stand up, stretch, look out of the window.")] },
        { upTo: Infinity, icon: "bedtime", set: [Translation.tr("Over six hours. Try to use less."), Translation.tr("That's a lot of screen. Go outside for a bit."), Translation.tr("Your eyes need a rest. Try less tomorrow.")] }
    ]
    readonly property var verdict: {
        const hours = todayTotal / 3600;
        const range = phrases.find(p => hours < p.upTo);
        const dayNumber = Math.floor(new Date() / 86400000);
        return { icon: range.icon, text: range.set[dayNumber % range.set.length] };
    }
    function appName(app) {
        return DesktopEntries.heuristicLookup(app)?.name ?? app;
    }
    property bool adding: false
    property int newMinutes: 30

    function usedToday(app) {
        return todays.find(a => a.app === app)?.seconds ?? 0;
    }
    function addLimit() {
        const app = ScreenTime.appKey(program.text);
        if (app === "")
            return;
        ScreenTime.setLimit(app, newMinutes);
        program.text = "";
        adding = false;
    }
    function appIcon(app) {
        // Quickshell.iconPath gives an image:// URL already.
        return AppIcons.path(app);
    }

    // One app: icon, name, time and a bar against `peak` (the most used app's seconds).
    component AppRow: RowLayout {
        required property var modelData
        property int peak: 1

        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        spacing: 12

        Image {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            source: root.appIcon(modelData.app)
            sourceSize.width: 28
            sourceSize.height: 28
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: source !== ""
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: root.appName(modelData.app)
                    elide: Text.ElideRight
                }
                StyledText {
                    text: root.duration(modelData.seconds)
                    font.pixelSize: Appearance.font.size.labelMedium
                    color: Colors.m3onSurfaceVariant
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 6
                radius: 3
                color: Colors.m3surfaceContainerHighest
                Rectangle {
                    width: parent.width * modelData.seconds / peak
                    height: parent.height
                    radius: 3
                    color: Colors.m3primary
                }
            }
        }
    }

    Section {
        icon: "hourglass_top"
        title: Translation.tr("Today")

        ListRow {
            Layout.fillWidth: true
            icon: "schedule"
            title: root.todayTotal > 0 ? root.duration(root.todayTotal) : Translation.tr("Nothing counted yet")
            subtitle: Translation.tr("Time with an app in the focus, counted every %1 seconds. Kept in ~/.local/state/hi-shell/screentime.json").arg(ScreenTime.tick)
        }

        ListRow {
            Layout.fillWidth: true
            visible: root.todayTotal >= 60
            icon: root.verdict.icon
            title: root.verdict.text
        }

        Repeater {
            model: root.shownApps

            AppRow {
                peak: root.topSeconds
            }
        }
    }

    Section {
        icon: "calendar_view_week"
        title: Translation.tr("Earlier days")

        // The week shown, with arrows to the weeks before it (up to three).
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            spacing: 4

            IconButton {
                icon: "chevron_left"
                enabled: root.weeksAgo < 3
                onClicked: {
                    root.weeksAgo++;
                    root.pickedDay = "";
                }
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.weekTitle()
                font.weight: Font.Medium
            }
            IconButton {
                icon: "chevron_right"
                enabled: root.weeksAgo > 0
                onClicked: {
                    root.weeksAgo--;
                    root.pickedDay = "";
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.preferredHeight: 150
            spacing: 8

            Repeater {
                model: root.week

                ColumnLayout {
                    id: day

                    required property var modelData
                    readonly property bool picked: root.pickedDay === modelData.key

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: day.modelData.seconds > 0 ? root.duration(day.modelData.seconds) : ""
                        font.pixelSize: Appearance.font.size.labelSmall
                        color: Colors.m3onSurfaceVariant
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(day.modelData.seconds > 0 ? 4 : 0, parent.height * day.modelData.seconds / root.weekPeak)
                            radius: 6
                            color: day.modelData.key === ScreenTime.today ? Colors.m3primary : Colors.m3primaryContainer
                            border.width: day.picked ? 2 : 0
                            border.color: Colors.m3onSurface
                            Behavior on height { EffectAnim {} }
                        }
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.dayLabel(day.modelData.key, "dd")
                        font.pixelSize: Appearance.font.size.labelSmall
                        font.weight: day.picked ? Font.Bold : Font.Normal
                    }

                    // Tap a day for the apps it was spent in.
                    TapHandler {
                        onTapped: root.pickedDay = day.picked ? "" : day.modelData.key
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }

        ListRow {
            Layout.fillWidth: true
            visible: root.pickedDay !== ""
            icon: "event"
            title: root.pickedDay ? root.dayLabel(root.pickedDay, "dddd, d MMMM") : ""
            subtitle: root.pickedTotal > 0 ? root.duration(root.pickedTotal) : Translation.tr("Nothing counted yet")
        }

        Repeater {
            model: root.pickedApps

            AppRow {
                peak: root.pickedApps.length ? root.pickedApps[0].seconds : 1
            }
        }
    }

    Section {
        icon: "timer_off"
        title: Translation.tr("Daily limits")

        ListRow {
            Layout.fillWidth: true
            icon: "info"
            title: Translation.tr("A notification when an app's time for today runs out")
            subtitle: Translation.tr("Set the minutes for an app; 0 is no limit. Apps from today's list are shown.")
        }

        Repeater {
            model: ScreenTime.limitedApps

            StepperRow {
                required property var modelData
                icon: "hourglass_top"
                title: root.appName(modelData)
                subtitle: Translation.tr("%1 used today").arg(root.duration(root.usedToday(modelData)))
                value: ScreenTime.limitOf(modelData)
                step: 5
                from: 0
                to: 720
                onChanged: value => ScreenTime.setLimit(modelData, value)
            }
        }

        // A new limit: the program's name or command, and its minutes.
        ListRow {
            Layout.fillWidth: true
            icon: "add"
            title: Translation.tr("Add a limit")
            subtitle: Translation.tr("A program's name or command (firefox, Telegram, org.telegram.desktop)")
            IconButton {
                icon: root.adding ? "close" : "add"
                onClicked: root.adding = !root.adding
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            visible: root.adding
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 40
                radius: 20
                color: Colors.m3surfaceContainerHighest

                TextInput {
                    id: program
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Appearance.font.mono
                    font.pixelSize: Appearance.font.size.bodyMedium
                    color: Colors.m3onSurface
                    clip: true
                    selectByMouse: true
                    onAccepted: root.addLimit()

                    StyledText {
                        anchors.fill: parent
                        visible: program.text === ""
                        verticalAlignment: Text.AlignVCenter
                        text: Translation.tr("firefox")
                        color: Colors.m3outline
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    text: Translation.tr("Minutes a day")
                    color: Colors.m3onSurfaceVariant
                }
                Item {
                    Layout.fillWidth: true
                }
                IconButton {
                    icon: "remove"
                    enabled: root.newMinutes > 5
                    onClicked: root.newMinutes -= 5
                }
                StyledText {
                    Layout.preferredWidth: 48
                    horizontalAlignment: Text.AlignHCenter
                    text: root.newMinutes
                    font.features: { "tnum": 1 }
                }
                IconButton {
                    icon: "add"
                    enabled: root.newMinutes < 720
                    onClicked: root.newMinutes += 5
                }
                M3Button {
                    text: Translation.tr("Add")
                    icon: "add"
                    enabled: program.text.trim() !== ""
                    onClicked: root.addLimit()
                }
            }
        }
    }
}
