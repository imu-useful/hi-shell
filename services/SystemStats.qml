pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU, RAM, swap, disk, GPU load and temperatures, polled from /proc and /sys.
// Values that the hardware doesn't expose stay at -1.
Singleton {
    id: root

    property real cpuUsage: 0 // 0..1
    property real memUsage: 0 // 0..1
    property real memUsedGiB: 0
    property real memTotalGiB: 0
    property real swapUsage: 0 // 0..1
    property real swapUsedGiB: 0
    property real swapTotalGiB: 0
    property real diskUsage: 0 // 0..1, root filesystem
    property real diskUsedGiB: 0
    property real diskTotalGiB: 0
    property real gpuUsage: -1 // 0..1, AMD (gpu_busy_percent)
    property real cpuTemp: -1 // °C
    property real gpuTemp: -1
    property real uptime: 0 // seconds
    property string cpuModel: ""
    property int cpuCores: 0

    // Sensor files found at startup (hwmon numbering isn't stable across boots).
    property string gpuBusyPath: ""
    property string cpuTempPath: ""
    property string gpuTempPath: ""

    property var prevCpu: null

    readonly property string uptimeText: {
        const d = Math.floor(uptime / 86400), h = Math.floor(uptime % 86400 / 3600), m = Math.floor(uptime % 3600 / 60);
        return d > 0 ? `${d}d ${h}h` : h > 0 ? `${h}h ${m}m` : `${m}m`;
    }

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
        const swapTotal = kb("SwapTotal");
        const swapUsed = swapTotal - kb("SwapFree");
        swapUsage = swapTotal > 0 ? swapUsed / swapTotal : 0;
        swapUsedGiB = swapUsed / 1048576;
        swapTotalGiB = swapTotal / 1048576;
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

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: root.uptime = Number(text().split(" ")[0])
    }

    FileView {
        id: gpuBusy
        path: root.gpuBusyPath
        printErrors: false
        onLoaded: root.gpuUsage = Number(text()) / 100
    }

    FileView {
        id: cpuTempFile
        path: root.cpuTempPath
        printErrors: false
        onLoaded: root.cpuTemp = Number(text()) / 1000
    }

    FileView {
        id: gpuTempFile
        path: root.gpuTempPath
        printErrors: false
        onLoaded: root.gpuTemp = Number(text()) / 1000
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            uptimeFile.reload();
            if (root.gpuBusyPath)
                gpuBusy.reload();
            if (root.cpuTempPath)
                cpuTempFile.reload();
            if (root.gpuTempPath)
                gpuTempFile.reload();
        }
    }

    // "used total" bytes of the root filesystem; disk usage changes slowly.
    Process {
        id: df
        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [used, size] = text.trim().split("\n").pop().trim().split(/\s+/).map(Number);
                if (size > 0) {
                    root.diskUsage = used / size;
                    root.diskUsedGiB = used / 1073741824;
                    root.diskTotalGiB = size / 1073741824;
                }
            }
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: df.running = true
    }

    // Find the GPU load file and the CPU / GPU temperature sensors once.
    Process {
        running: true
        command: ["sh", "-c", `
            for f in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r "$f" ] && echo "gpubusy $f" && break; done
            for h in /sys/class/hwmon/hwmon*; do echo "hwmon $(cat "$h/name" 2>/dev/null) $h"; done
            grep -m1 'model name' /proc/cpuinfo | cut -d: -f2-
            nproc`]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                for (const line of lines) {
                    const f = line.trim().split(" ");
                    if (f[0] === "gpubusy")
                        root.gpuBusyPath = f[1];
                    else if (f[0] === "hwmon" && /^(k10temp|coretemp|zenpower|cpu_thermal)$/.test(f[1]) && !root.cpuTempPath)
                        root.cpuTempPath = `${f[2]}/temp1_input`;
                    else if (f[0] === "hwmon" && /^(amdgpu|radeon|nouveau)$/.test(f[1]) && !root.gpuTempPath)
                        root.gpuTempPath = `${f[2]}/temp1_input`;
                }
                root.cpuCores = Number(lines[lines.length - 1]) || 0;
                root.cpuModel = (lines[lines.length - 2] ?? "").trim().replace(/ with Radeon.*$/, "");
            }
        }
    }
}
