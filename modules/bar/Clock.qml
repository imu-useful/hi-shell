import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets

// Date and time (formats in bar.clock); click toggles the calendar popup.
BarWidget {
    id: root

    readonly property var options: Config.options.bar.clock

    clickable: true
    active: ShellState.calendarOpen
    padding: 4
    contentWidth: vertical ? thickness : row.implicitWidth + 6
    contentHeight: column.implicitHeight
    onClicked: ShellState.calendarOpen = !ShellState.calendarOpen

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    RowLayout {
        id: row
        visible: !root.vertical
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        spacing: 8

        StyledText {
            Layout.leftMargin: 6
            text: Qt.formatDateTime(clock.date, root.options.dateFormat)
            font.pixelSize: Appearance.font.size.normal
        }

        Rectangle {
            implicitWidth: time.implicitWidth + 16
            implicitHeight: root.thickness - 8
            radius: Appearance.rounding.full
            color: Colors.m3primary

            StyledText {
                id: time
                anchors.centerIn: parent
                text: Qt.formatDateTime(clock.date, root.options.timeFormat)
                font.pixelSize: Appearance.font.size.normal
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: Colors.m3onPrimary
            }
        }
    }

    ColumnLayout {
        id: column
        visible: root.vertical
        anchors.centerIn: parent
        spacing: -2

        Repeater {
            model: Qt.formatDateTime(clock.date, "HH mm").split(" ")

            StyledText {
                required property string modelData
                Layout.alignment: Qt.AlignHCenter
                text: modelData
                font.pixelSize: Appearance.font.size.bodyMedium
                font.weight: Font.DemiBold
            }
        }
    }
}
