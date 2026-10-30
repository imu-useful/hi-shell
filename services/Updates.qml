pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Pending package updates: repo packages via checkupdates (pacman-contrib),
// AUR via yay / paru. `run()` opens a terminal with the system upgrade.
Singleton {
    id: root

    readonly property var options: Config.options.updates

    // [{ name, from, to, aur }]
    property var packages: []
    readonly property int count: packages.length
    readonly property int aurCount: packages.filter(p => p.aur).length
    readonly property bool checking: checker.running
    property string error: ""
    property real lastCheck: 0
    property string aurHelper: ""
    // Only pacman systems have updates to count (not NixOS, Debian, ...).
    property bool available: false

    function refresh() {
        if (options.enabled && available && !checker.running && !upgrade.running)
            checker.running = true;
    }

    function run() {
        if (upgrade.running)
            return;
        const cmd = aurHelper && options.aur ? aurHelper : "sudo pacman -Syu";
        upgrade.command = [Config.options.apps.terminal, "-e", "bash", "-c", `${cmd}; echo; read -n 1 -s -r -p 'Done. Press any key to close'`];
        upgrade.running = true;
    }

    // "name 1.0-1 -> 1.1-1"
    function parse(lines, aur) {
        return lines.split("\n").map(l => l.trim().split(/\s+/)).filter(f => f.length >= 4 && f[2] === "->")
            .map(f => ({ name: f[0], from: f[1], to: f[3], aur }));
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v checkupdates"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = text.trim() !== "";
                root.refresh();
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v yay || command -v paru"]
        stdout: StdioCollector {
            onStreamFinished: root.aurHelper = text.trim().split("/").pop()
        }
    }

    Process {
        id: checker
        // checkupdates exits 2 when there is nothing to update.
        command: ["sh", "-c", `checkupdates --nocolor; s=$?; [ $s -le 2 ] || exit $s; echo '::aur::'; ${root.options.aur && root.aurHelper ? root.aurHelper + " -Qua 2>/dev/null" : "true"}; exit 0`]
        stdout: StdioCollector {
            onStreamFinished: {
                const [repo, aur] = text.split("::aur::");
                root.packages = [...root.parse(repo ?? "", false), ...root.parse(aur ?? "", true)];
                root.lastCheck = Date.now();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: root.error = text.trim()
        }
        onExited: code => {
            if (code === 0)
                root.error = "";
        }
    }

    Process {
        id: upgrade
        onExited: root.refresh()
    }

    Timer {
        running: root.options.enabled
        interval: Math.max(10, root.options.intervalMinutes) * 60000
        repeat: true
        onTriggered: root.refresh()
    }

    // First check shortly after startup, once the network is likely up.
    Timer {
        running: root.options.enabled
        interval: 30000
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "updates"

        function refresh(): void {
            root.refresh();
        }
        function count(): int {
            return root.count;
        }
    }
}
