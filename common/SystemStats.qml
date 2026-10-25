pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU and RAM usage, polled from /proc.
Singleton {
    id: root

    property real cpuUsage: 0 // 0..1
    property real memUsage: 0 // 0..1
    property real memUsedGiB: 0
    property real memTotalGiB: 0

    property var prevCpu: null

    function parseCpu(text) {
        // "cpu  user nice system idle iowait irq softirq steal ..."
        const f = text.split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
        const total = f.reduce((a, b) => a + b, 0);
        const idle = f[3] + f[4];
        if (prevCpu && total > prevCpu.total)
            cpuUsage = 1 - (idle - prevCpu.idle) / (total - prevCpu.total);
        prevCpu = { total, idle };
    }

    function parseMem(text) {
        const kb = key => Number((text.match(new RegExp(`^${key}:\\s+(\\d+)`, "m")) || [0, 0])[1]);
        const total = kb("MemTotal");
        const available = kb("MemAvailable");
        if (total <= 0)
            return;
        memUsage = (total - available) / total;
        memUsedGiB = (total - available) / 1048576;
        memTotalGiB = total / 1048576;
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: root.parseCpu(text())
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: root.parseMem(text())
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
        }
    }
}
