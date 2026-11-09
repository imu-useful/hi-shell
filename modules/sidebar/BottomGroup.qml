import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import qs.modules.calendar

// Tabs under the sliders: notifications, calendar, to-do, timers.
ColumnLayout {
    id: root

    // Config sidebar.tabs, in order; the default four if it holds none that exist.
    readonly property var known: ["notifications", "calendar", "todo", "timers"]
    readonly property var tabs: {
        const list = Array.from(Config.options.sidebar.tabs).filter((t, i, all) => known.includes(t) && all.indexOf(t) === i);
        return list.length > 0 ? list : known;
    }
    readonly property var tabInfo: ({
        notifications: { icon: "notifications", text: Notifications.list.length ? String(Notifications.list.length) : "" },
        calendar: { icon: "calendar_month", text: "" },
        todo: { icon: "checklist", text: Todo.pending ? String(Todo.pending) : "" },
        timers: { icon: "timer", text: "" }
    })
    // The open tab, or the first one when it was hidden.
    readonly property string currentTab: tabs.includes(ShellState.sidebarTab) ? ShellState.sidebarTab : tabs[0]

    spacing: 10

    SegmentedButton {
        Layout.fillWidth: true
        visible: root.tabs.length > 1
        model: root.tabs.map(t => root.tabInfo[t])
        currentIndex: Math.max(0, root.tabs.indexOf(root.currentTab))
        onSelected: index => ShellState.sidebarTab = root.tabs[index]
    }

    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        sourceComponent: root.currentTab === "calendar" ? calendar : root.currentTab === "todo" ? todo : root.currentTab === "timers" ? timers : notifications
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
