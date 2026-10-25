pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Download / upload rate summed over physical interfaces, from /proc/net/dev.
Singleton {
    id: root

    property real download: 0 // bytes/s
    property real upload: 0
    property real totalDownload: 0 // bytes since boot
    property real totalUpload: 0

    property var prev: null
    readonly property int interval: 1000

    // Only physical interfaces: VPN tunnels, bridges and containers carry traffic
    // that also passes through a physical one and would be counted twice.
    property list<string> physical: []

    // "1.2 MB/s", "340 KB/s"
    function format(bytesPerSecond) {
        const units = ["B/s", "KB/s", "MB/s", "GB/s"];
        let v = bytesPerSecond, i = 0;
        while (v >= 1000 && i < units.length - 1) {
            v /= 1000;
            i++;
        }
        return `${v >= 100 || i === 0 ? Math.round(v) : v.toFixed(1)} ${units[i]}`;
    }

    function parse(text) {
        let rx = 0, tx = 0;
        for (const line of text.split("\n").slice(2)) {
            const [name, data] = line.split(":");
            if (!data || !physical.includes(name.trim()))
                continue;
            const f = data.trim().split(/\s+/).map(Number);
            rx += f[0];
            tx += f[8];
        }
        const now = Date.now();
        if (prev && now > prev.time) {
            const dt = (now - prev.time) / 1000;
            download = Math.max(0, (rx - prev.rx) / dt);
            upload = Math.max(0, (tx - prev.tx) / dt);
        }
        totalDownload = rx;
        totalUpload = tx;
        prev = { rx, tx, time: now };
    }

    FileView {
        id: file
        path: "/proc/net/dev"
        onLoaded: root.parse(text())
    }

    Process {
        id: discover
        running: true
        command: ["sh", "-c", "for d in /sys/class/net/*/device; do basename \"$(dirname \"$d\")\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.physical = text.trim().split("\n").filter(x => x !== "");
                root.prev = null;
            }
        }
    }

    // Pick up USB adapters / docks plugged in later.
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: discover.running = true
    }

    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: file.reload()
    }
}
