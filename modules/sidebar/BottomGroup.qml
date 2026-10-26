import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import qs.modules.calendar

// Tabs under the sliders: notifications, calendar, to-do, timers.
ColumnLayout {
    id: root

    readonly property list<string> tabs: ["notifications", "calendar", "todo", "timers"]

    spacing: 10

    SegmentedButton {
        Layout.fillWidth: true
        model: [
            { icon: "notifications", text: Notifications.list.length ? String(Notifications.list.length) : "" },
            { icon: "calendar_month", text: "" },
            { icon: "checklist", text: Todo.pending ? String(Todo.pending) : "" },
            { icon: "timer", text: "" }
        ]
        currentIndex: Math.max(0, root.tabs.indexOf(ShellState.sidebarTab))
        onSelected: index => ShellState.sidebarTab = root.tabs[index]
    }

    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        sourceComponent: ShellState.sidebarTab === "calendar" ? calendar : ShellState.sidebarTab === "todo" ? todo : ShellState.sidebarTab === "timers" ? timers : notifications
    }

    Component {
        id: notifications
        NotificationCenter {}
    }
    Component {
        id: todo
        TodoView {}
    }
    Component {
        id: timers
        TimersView {}
    }
    Component {
        id: calendar
        StyledFlickable {
            contentHeight: month.implicitHeight

            MonthGrid {
                id: month
                width: parent.width
            }
        }
    }
}
