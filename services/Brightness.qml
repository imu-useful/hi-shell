pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Screen brightness: the built-in panel via /sys/class/backlight + brightnessctl,
// external monitors via ddcutil (DDC/CI, needs i2c access). One monitor per screen.
// IPC: `qs -c hi-shell ipc call brightness increment` (decrement, set <percent>).
Singleton {
    id: root

    property string backlight: ""
    // DRM connector name (e.g. "HDMI-A-1") -> i2c bus number.
    property var ddcBuses: ({})

    readonly property list<QtObject> monitors: variants.instances
    readonly property QtObject focused: forScreen(Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0])

    function forScreen(screen) {
        return monitors.find(m => m.screen === screen) ?? null;
    }

    component Monitor: QtObject {
        id: monitor

        required property ShellScreen screen
        property string backlight: ""
        property int ddcBus: -1

        readonly property bool internal: /^(eDP|LVDS|DSI)/.test(screen?.name ?? "")
        readonly property bool available: internal ? backlight !== "" : ddcBus >= 0
        property real brightness: 0 // 0..1
        property real maxRaw: 1
        property real queued: -1

        function set(value) {
            if (!available)
                return;
            brightness = Math.max(0.01, Math.min(1, value));
            queued = brightness;
            if (!writer.running)
                flush();
        }
        function increment() {
            set(brightness + 0.05);
        }
        function decrement() {
            set(brightness - 0.05);
        }

        // Write the latest requested value; slider drags coalesce into a few writes.
        function flush() {
            if (queued < 0)
                return;
            const percent = Math.round(queued * 100);
            queued = -1;
            writer.command = internal ? ["brightnessctl", "-q", "-d", backlight, "set", `${percent}%`]
                                      : ["ddcutil", "--bus", String(ddcBus), "--noverify", "setvcp", "10", String(percent)];
            writer.running = true;
        }

        function refresh() {
            if (!available || writer.running || queued >= 0)
                return;
            if (internal) {
                current.reload();
            } else {
                reader.running = true;
            }
        }

        onAvailableChanged: refresh()

        property Process writer: Process {
            onExited: monitor.flush()
        }

        property FileView max: FileView {
            path: monitor.internal && monitor.backlight ? `/sys/class/backlight/${monitor.backlight}/max_brightness` : ""
            onLoaded: monitor.maxRaw = Math.max(1, Number(text()))
        }
        property FileView current: FileView {
            path: monitor.internal && monitor.backlight ? `/sys/class/backlight/${monitor.backlight}/brightness` : ""
            onLoaded: monitor.brightness = Number(text()) / monitor.maxRaw
        }

        // "VCP 10 C 50 100" (feature, type, current, max)
        property Process reader: Process {
            command: ["ddcutil", "--bus", String(monitor.ddcBus), "--brief", "getvcp", "10"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const f = text.trim().split(/\s+/);
                    if (f[0] === "VCP" && Number(f[4]) > 0)
                        monitor.brightness = Number(f[3]) / Number(f[4]);
                }
            }
        }

        // Fallback for missed changes; DDC is slow, so rarely.
        property Timer poll: Timer {
            running: monitor.available
            interval: monitor.internal ? 10000 : 30000
            repeat: true
            onTriggered: monitor.refresh()
        }
    }

    Variants {
        id: variants
        model: Quickshell.screens

        Monitor {
            required property ShellScreen modelData
            screen: modelData
            backlight: root.backlight
            ddcBus: root.ddcBuses[modelData.name] ?? -1
        }
    }

    // Backlight changes from elsewhere (brightness keys, brightnessctl) arrive as udev events.
    Process {
        running: root.backlight !== ""
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("(backlight)"))
                    root.monitors.filter(m => m.internal).forEach(m => m.refresh());
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/backlight | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: root.backlight = text.trim()
        }
    }

    // Only probe DDC when an external screen is connected (ddcutil detect takes ~1 s).
    readonly property bool hasExternal: Quickshell.screens.some(s => !/^(eDP|LVDS|DSI)/.test(s.name))
    onHasExternalChanged: if (hasExternal) ddcDetect.running = true
    Component.onCompleted: if (hasExternal) ddcDetect.running = true

    Process {
        id: ddcDetect
        command: ["ddcutil", "detect", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                const buses = {};
                for (const block of text.split(/\n(?=\S)/)) {
                    const bus = block.match(/I2C bus:\s+\/dev\/i2c-(\d+)/);
                    const connector = block.match(/DRM connector:\s+card\d+-(\S+)/);
                    if (bus && connector)
                        buses[connector[1]] = Number(bus[1]);
                }
                root.ddcBuses = buses;
            }
        }
    }

    IpcHandler {
        target: "brightness"

        function increment(): void {
            root.focused?.increment();
        }
        function decrement(): void {
            root.focused?.decrement();
        }
        function set(percent: int): void {
            root.focused?.set(percent / 100);
        }
    }
}
