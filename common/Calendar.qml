pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Google Calendar events via services/gcal.py, refreshed every 5 minutes
// and whenever the calendar popup opens or changes month.
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/services/gcal.py"

    // "idle" | "ok" | "needs_setup" | "needs_auth" | "error"
    property string status: "idle"
    property string message: ""
    property var events: []
    property var eventsByDay: ({}) // "yyyy-MM-dd" -> [event]
    property var viewMonth: firstOfMonth(new Date())

    readonly property bool loading: fetcher.running
    readonly property bool connecting: authProc.running
    property bool pending: false

    function iso(d) {
        return Qt.formatDate(d, "yyyy-MM-dd");
    }

    function firstOfMonth(d) {
        return new Date(d.getFullYear(), d.getMonth(), 1);
    }

    function startOfToday() {
        const d = new Date();
        return new Date(d.getFullYear(), d.getMonth(), d.getDate());
    }

    function shiftMonth(n) {
        viewMonth = new Date(viewMonth.getFullYear(), viewMonth.getMonth() + n, 1);
        refresh();
    }

    function resetMonth() {
        viewMonth = firstOfMonth(new Date());
    }

    function refresh() {
        if (fetcher.running) {
            pending = true;
            return;
        }
        // Cover the visible month and the next 30 days of agenda.
        const today = startOfToday();
        const monthEnd = new Date(viewMonth.getFullYear(), viewMonth.getMonth() + 1, 0);
        const agendaEnd = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 30);
        const from = viewMonth < today ? viewMonth : today;
        const to = monthEnd > agendaEnd ? monthEnd : agendaEnd;
        fetcher.command = ["python3", script, "events", "--from", iso(from), "--to", iso(to)];
        fetcher.running = true;
    }

    function connect() {
        if (authProc.running)
            return;
        message = "";
        authProc.running = true;
    }

    function handle(text) {
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            status = "error";
            message = "Calendar backend returned invalid output";
            return;
        }
        status = data.status;
        message = data.message ?? "";
        if (data.status !== "ok")
            return;
        const byDay = {};
        for (const ev of data.events)
            for (const day of ev.days)
                (byDay[day] = byDay[day] || []).push(ev);
        events = data.events;
        eventsByDay = byDay;
    }

    Process {
        id: fetcher
        stdout: StdioCollector {
            onStreamFinished: root.handle(text)
        }
        onExited: {
            if (root.pending) {
                root.pending = false;
                root.refresh();
            }
        }
    }

    Process {
        id: authProc
        command: ["python3", root.script, "auth"]
        stderr: StdioCollector {
            id: authErr
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.status = "error";
                root.message = authErr.text.trim().split("\n").pop() || "Google sign-in failed";
            }
            root.refresh();
        }
    }

    Timer {
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
