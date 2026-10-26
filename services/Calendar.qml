pragma Singleton

import QtQuick
import Quickshell
import qs.common

// The month shown by the calendar (popup under the bar clock, right sidebar tab).
Singleton {
    id: root

    property var viewMonth: firstOfMonth(new Date())

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
}
