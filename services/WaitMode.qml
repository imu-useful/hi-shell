pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Wait Mode (wait-mode/), which runs as its own process: this only starts and stops it
// through wait-mode.sh and knows whether it's on (the quick toggle in the right sidebar).
// It's checked while the sidebar is open, and just after a start or stop.
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/wait-mode/wait-mode.sh"
    property bool active: false

    function refresh() {
        if (!check.running)
            check.running = true;
    }

    function start() {
        Quickshell.execDetached(["sh", script, "start"]);
        settle.restart();
    }

    function stop() {
        Quickshell.execDetached(["sh", script, "stop"]);
        settle.restart();
    }

    Process {
        id: check
        command: ["systemctl", "--user", "is-active", "hi-wait-mode"]
        stdout: StdioCollector {
            onStreamFinished: root.active = text.trim() === "active"
        }
    }

    // The unit takes a moment to come up or go down.
    Timer {
        id: settle
        interval: 1500
        onTriggered: root.refresh()
    }

    // `qs -c hi-shell ipc call waitmode start|stop|toggle|status` (the same as the quick toggle).
    IpcHandler {
        target: "waitmode"

        function start(): void {
            root.start();
        }
        function stop(): void {
            root.stop();
        }
        function toggle(): void {
            root.active ? root.stop() : root.start();
        }
        function status(): string {
            return root.active ? "on" : "off";
        }
    }

    Timer {
        running: ShellState.sidebarRightOpen
        interval: 3000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
