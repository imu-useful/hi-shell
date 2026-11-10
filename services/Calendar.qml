pragma Singleton

import QtQuick
import Quickshell
import qs.common

// The month shown by the calendar (popup under the bar clock, right sidebar tab).
Singleton {
    id: root

    property var viewMonth: firstOfMonth(new Date())
    // Today at midnight. A binding on new Date() is read once, so whatever is "today" (the calendar's
    // mark, screen time, Focus stats) reads this, and it moves on at midnight in a shell left running.
    property var today: dayOf(new Date())

    function dayOf(d) {
        return new Date(d.getFullYear(), d.getMonth(), d.getDate());
    }

    function iso(d) {
        return Qt.formatDate(d, "yyyy-MM-dd");
    }

    function firstOfMonth(d) {
        return new Date(d.getFullYear(), d.getMonth(), 1);
    }

    function shiftMonth(n) {
        viewMonth = new Date(viewMonth.getFullYear(), viewMonth.getMonth() + n, 1);
    }

    function resetMonth() {
        viewMonth = firstOfMonth(new Date());
    }

    SystemClock {
        precision: SystemClock.Minutes
        onDateChanged: {
            const day = root.dayOf(date);
            if (day.getTime() !== root.today.getTime())
                root.today = day;
        }
    }
}
