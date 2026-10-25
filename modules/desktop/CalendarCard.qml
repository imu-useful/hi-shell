import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets

// Month chip and the current week, today highlighted.
DesktopCard {
    id: root

    readonly property var locale: Translation.locale
    readonly property var today: clock.date
    readonly property var weekStart: {
        const d = new Date(today.getFullYear(), today.getMonth(), today.getDate());
        d.setDate(d.getDate() - (d.getDay() - locale.firstDayOfWeek % 7 + 7) % 7);
        return d;
    }

    implicitWidth: 380
    implicitHeight: 112

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        Rectangle {
            implicitWidth: month.implicitWidth + 20
            implicitHeight: 26
            radius: 13
            color: Colors.m3primary
            StyledText {
                id: month
                anchors.centerIn: parent
                text: root.today.toLocaleDateString(root.locale, "MMMM yyyy")
                font.pixelSize: Appearance.font.size.labelMedium
                font.weight: Font.DemiBold
                color: Colors.m3onPrimary
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: 7

                ColumnLayout {
                    required property int index
                    readonly property var date: new Date(root.weekStart.getFullYear(), root.weekStart.getMonth(), root.weekStart.getDate() + index)
                    readonly property bool isToday: date.toDateString() === root.today.toDateString()

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.maximumWidth: Number.POSITIVE_INFINITY
                    spacing: 2

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: date.toLocaleDateString(root.locale, "ddd").slice(0, 2)
                        font.pixelSize: Appearance.font.size.labelSmall
                        color: Colors.m3onSurfaceVariant
                    }
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: 15
                        color: isToday ? Colors.m3secondaryContainer : "transparent"
                        StyledText {
                            anchors.centerIn: parent
                            text: date.getDate()
                            font.pixelSize: Appearance.font.size.labelMedium + 1
                            font.weight: isToday ? Font.DemiBold : Font.Normal
                            color: isToday ? Colors.m3onSecondaryContainer : Colors.m3onSurface
                        }
                    }
                }
            }
        }
    }
}
