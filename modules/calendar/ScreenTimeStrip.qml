import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import Quickshell
import qs.services

// Screen time under the calendar: today's total and top apps, and the last week as bars.
ColumnLayout {
    id: root

    readonly property var todays: ScreenTime.totals(ScreenTime.today)
    readonly property int todayTotal: todays.reduce((sum, a) => sum + a.seconds, 0)
    readonly property var week: ScreenTime.week()
    readonly property int weekPeak: Math.max(1, ...week.map(d => d.seconds))

    spacing: 8

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Colors.m3outlineVariant
    }

    RowLayout {
        Layout.fillWidth: true

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Screen time today")
            font.pixelSize: Appearance.font.size.labelMedium
            color: Colors.m3onSurfaceVariant
        }
        StyledText {
            text: root.todayTotal > 0 ? ScreenTime.duration(root.todayTotal) : Translation.tr("Nothing yet")
            font.pixelSize: Appearance.font.size.labelMedium
            font.weight: Font.Medium
        }
    }

    // The top three apps, as one line.
    StyledText {
        Layout.fillWidth: true
        visible: root.todays.length > 0
        wrapMode: Text.Wrap
        font.pixelSize: Appearance.font.size.labelSmall
        color: Colors.m3onSurfaceVariant
        text: root.todays.slice(0, 3).map(a => `${DesktopEntries.heuristicLookup(a.app)?.name ?? a.app} ${ScreenTime.duration(a.seconds)}`).join("  ·  ")
    }

    // The last 7 days, today highlighted.
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 6

        Repeater {
            model: root.week

            ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 3

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(modelData.seconds > 0 ? 3 : 0, parent.height * modelData.seconds / root.weekPeak)
                        radius: 4
                        color: modelData.key === ScreenTime.today ? Colors.m3primary : Colors.m3primaryContainer
                    }
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: new Date(modelData.key + "T12:00").toLocaleDateString(Translation.locale, "dd")
                    font.pixelSize: Appearance.font.size.labelSmall
                    color: modelData.key === ScreenTime.today ? Colors.m3primary : Colors.m3onSurfaceVariant
                }
            }
        }
    }
}
