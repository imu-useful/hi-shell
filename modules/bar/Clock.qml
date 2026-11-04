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
    // Held for the island's hold time, the clock switches the Dynamic Island instead of opening the calendar.
    onPressedDown: {
        ShellState.islandHeld = false;
        if (ShellState.islandCount > 0)
            ShellState.startIslandHold();
    }
    onPressedUp: ShellState.endIslandHold()
    onClicked: {
        if (!ShellState.islandHeld)
            ShellState.calendarOpen = !ShellState.calendarOpen;
        ShellState.islandHeld = false;
    }

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
            text: clock.date.toLocaleString(Translation.locale, root.options.dateFormat)
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
