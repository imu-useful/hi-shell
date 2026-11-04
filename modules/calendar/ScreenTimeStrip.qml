import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import Quickshell
import qs.services

// Screen time under the calendar: a day's total and top apps (today's, or the one tapped in the bars), and
// the week as bars, with arrows to the weeks before it (up to three).
ColumnLayout {
    id: root

    // How many weeks back the bars are (0 to 3), and the day tapped in them ("" = today).
    property int weeksAgo: 0
    property string pickedDay: ""
    readonly property string shownDay: pickedDay || ScreenTime.today
    readonly property var apps: ScreenTime.totals(shownDay)
    readonly property int total: apps.reduce((sum, a) => sum + a.seconds, 0)
    readonly property var week: ScreenTime.week(weeksAgo)
    readonly property int weekPeak: Math.max(1, ...week.map(d => d.seconds))

    function dayLabel(key, format) {
        return new Date(key + "T12:00").toLocaleDateString(Translation.locale, format);
    }

    // The line above it (not wanted when it is the first thing in its column).
    property bool topDivider: true

    spacing: 8

    Rectangle {
        visible: root.topDivider
        Layout.fillWidth: true
        height: 1
        color: Colors.m3outlineVariant
    }

    RowLayout {
        Layout.fillWidth: true

        StyledText {
            Layout.fillWidth: true
            text: root.shownDay === ScreenTime.today ? Translation.tr("Screen time today") : root.dayLabel(root.shownDay, "ddd, d MMM")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        StyledText {
            text: root.total > 0 ? ScreenTime.duration(root.total) : Translation.tr("Nothing yet")
            font.pixelSize: Appearance.font.size.labelMedium
            font.weight: Font.Medium
        }
    }

    // The top apps of the day, as one line.
    StyledText {
        Layout.fillWidth: true
        visible: root.apps.length > 0
        wrapMode: Text.Wrap
        font.pixelSize: Appearance.font.size.labelSmall
        color: Colors.m3onSurfaceVariant
        text: root.apps.slice(0, 4).map(a => `${DesktopEntries.heuristicLookup(a.app)?.name ?? a.app} ${ScreenTime.duration(a.seconds)}`).join("  ·  ")
    }

    // The week shown, with arrows to the weeks before it.
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 0

        MaterialIcon {
            icon: "chevron_left"
            iconSize: 20
            opacity: root.weeksAgo < 3 ? 1 : 0.3
            color: Colors.m3onSurfaceVariant
            TapHandler {
                enabled: root.weeksAgo < 3
                onTapped: {
                    root.weeksAgo++;
                    root.pickedDay = "";
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.weeksAgo === 0 ? Translation.tr("The last 7 days") : `${root.dayLabel(root.week[0].key, "d MMM")} – ${root.dayLabel(root.week[6].key, "d MMM")}`
            font.pixelSize: Appearance.font.size.labelSmall
            color: Colors.m3onSurfaceVariant
        }
        MaterialIcon {
            icon: "chevron_right"
            iconSize: 20
            opacity: root.weeksAgo > 0 ? 1 : 0.3
            color: Colors.m3onSurfaceVariant
            TapHandler {
                enabled: root.weeksAgo > 0
                onTapped: {
                    root.weeksAgo--;
                    root.pickedDay = "";
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }

    // The 7 days, today highlighted; tap one for its apps.
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: root.week

            ColumnLayout {
                id: day

                required property var modelData
                readonly property bool picked: root.shownDay === modelData.key

                Layout.fillWidth: true
                spacing: 3

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(day.modelData.seconds > 0 ? 3 : 0, parent.height * day.modelData.seconds / root.weekPeak)
                        radius: 4
                        color: day.modelData.key === ScreenTime.today ? Colors.m3primary : Colors.m3primaryContainer
                        border.width: day.picked ? 2 : 0
                        border.color: Colors.m3onSurface
                    }
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.dayLabel(day.modelData.key, "dd")
                    font.pixelSize: Appearance.font.size.labelSmall
                    font.weight: day.picked ? Font.Bold : Font.Normal
                    color: day.modelData.key === ScreenTime.today ? Colors.m3primary : Colors.m3onSurfaceVariant
                }

                TapHandler {
                    onTapped: root.pickedDay = day.modelData.key === ScreenTime.today || day.picked ? "" : day.modelData.key
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }
    }
}
