pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// The process list for the process manager: `ps` is polled only while the
// manager is open, so nothing runs in the background otherwise.
Singleton {
    id: root

    // [{ pid, name, user, cpu (%), mem (%), rssMiB }], sorted by `sortKey`.
    property var list: []
    property string sortKey: "cpu" // cpu | mem | name | pid
    property bool active: false
    property string lastError: ""

    function setSort(key) {
        sortKey = key;
        list = sorted(list);
    }

    function sorted(items) {
        const k = sortKey;
        return items.slice().sort((a, b) => k === "name" ? a.name.localeCompare(b.name) : k === "pid" ? a.pid - b.pid : b[k] - a[k]);
    }

    function parse(text) {
        const rows = [];
        for (const line of text.split("\n").slice(1)) {
            if (/\sps$/.test(line))
                continue;
            const m = line.trim().match(/^(\d+)\s+(\S+)\s+([\d.]+)\s+([\d.]+)\s+(\d+)\s+(.+)$/);
            if (m)
                rows.push({ pid: Number(m[1]), user: m[2], cpu: Number(m[3]), mem: Number(m[4]), rssMiB: Number(m[5]) / 1024, name: m[6] });
        }
        list = sorted(rows);
    }

    // signal: "TERM" (ask to quit) or "KILL" (force).
    function kill(pid, signal) {
        killer.command = ["kill", "-" + signal, String(pid)];
        killer.running = true;
    }

    Process {
        id: ps
        command: ["ps", "-eo", "pid=,user=,pcpu=,pmem=,rss=,comm=", "--sort=-pcpu"]
        stdout: StdioCollector {
            // A header line is expected by parse(); ps -o with "=" prints none, so add one.
            onStreamFinished: root.parse("h\n" + text)
        }
    }

    Process {
        id: killer
        stderr: StdioCollector {
            onStreamFinished: root.lastError = text.trim()
        }
        onExited: ps.running = true
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: if (!ps.running) ps.running = true
    }
}
