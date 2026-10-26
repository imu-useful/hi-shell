import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.common.widgets

// Month view: header with navigation, weekday row, 6x7 day grid; today is filled with
// primary.
ColumnLayout {
    id: root

    readonly property var month: Calendar.viewMonth

    // Scroll through months.
    WheelSteps {
        onStepped: steps => Calendar.shiftMonth(-steps)
    }
    readonly property var locale: Translation.locale
    // Qt.DayOfWeek is 1 = Monday .. 7 = Sunday; JS getDay() is 0 = Sunday.
    readonly property int firstDay: locale.firstDayOfWeek % 7
    readonly property var gridStart: new Date(month.getFullYear(), month.getMonth(), 1 - (month.getDay() - firstDay + 7) % 7)
    readonly property string todayIso: Calendar.iso(new Date())
    readonly property bool isCurrentMonth: Calendar.iso(month) === Calendar.iso(Calendar.firstOfMonth(new Date()))

    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            text: {
                const name = root.locale.standaloneMonthName(root.month.getMonth());
                return name.charAt(0).toUpperCase() + name.slice(1) + " " + root.month.getFullYear();
            }
            font.family: Appearance.font.main
            font.pixelSize: 16
            font.weight: Font.Medium
            color: Colors.m3onSurface
        }

        IconButton {
            icon: "today"
            visible: !root.isCurrentMonth
            onClicked: Calendar.resetMonth()
        }
        IconButton {
            icon: "chevron_left"
            onClicked: Calendar.shiftMonth(-1)
        }
        IconButton {
            icon: "chevron_right"
            onClicked: Calendar.shiftMonth(1)
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: 7

            Text {
                required property int index
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.locale.dayName((root.firstDay + index) % 7, Locale.ShortFormat).slice(0, 2)
                font.family: Appearance.font.main
                font.pixelSize: 12
                color: Colors.m3onSurfaceVariant
            }
        }

        Repeater {
            model: 42

            Rectangle {
                id: cell

                required property int index
                readonly property var date: new Date(root.gridStart.getFullYear(), root.gridStart.getMonth(), root.gridStart.getDate() + index)
                readonly property string iso: Calendar.iso(date)
                readonly property bool inMonth: date.getMonth() === root.month.getMonth()
                readonly property bool isToday: iso === root.todayIso

                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 38
                implicitHeight: 38
                radius: Appearance.rounding.full
                color: isToday ? Colors.m3primary : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: cell.date.getDate()
                    font.family: Appearance.font.main
                    font.pixelSize: 13
                    font.weight: cell.isToday ? Font.Bold : Font.Normal
                    color: cell.isToday ? Colors.m3onPrimary : Colors.m3onSurface
                    opacity: cell.inMonth || cell.isToday ? 1 : 0.4
                }
            }
        }
    }
}
