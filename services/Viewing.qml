pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.common

// Viewing mode: for a film, a series or a video. While it's on, the bar hides, notifications wait
// (as in Focus Mode) and the screen stays on. It's on when turned on by hand (the Viewing quick toggle,
// `qs -c hi-shell ipc call viewing toggle`), or by itself while a window is fullscreen and something
// plays (Config viewing.auto). Off, everything goes back the way it was.
Singleton {
    id: root

    readonly property var options: Config.options.viewing

    property bool manual: false
    // The focused window is fullscreen (Hyprland: 2 = fullscreen, 1 = maximized), checked every second.
    property bool fullscreen: false
    readonly property bool wanted: manual || (options.auto && fullscreen && Mpris.playing)
    property bool active: false
    property bool wasBarHidden: false
    property bool wasDnd: false

    onWantedChanged: apply(wanted)

    function toggle() {
        manual = !manual;
    }

    function apply(on) {
        if (on === active)
            return;
        active = on;
        if (on) {
            wasBarHidden = ShellState.barHidden;
            wasDnd = Notifications.dnd;
            ShellState.barHidden = true;
            Notifications.dnd = true;
            keepAwake.running = true;
        } else {
            ShellState.barHidden = wasBarHidden;
            Notifications.dnd = wasDnd;
            keepAwake.running = false;
        }
    }

    Timer {
        running: true
        interval: 1000
        repeat: true
        onTriggered: root.fullscreen = (Hyprland.activeToplevel?.lastIpcObject?.fullscreen ?? 0) >= 2
    }

    Process {
        id: keepAwake
        command: ["systemd-inhibit", "--what=idle", "--who=hi-shell", "--why=Viewing mode", "sleep", "infinity"]
    }

    IpcHandler {
        target: "viewing"

        function toggle(): void {
            root.toggle();
        }
        function status(): string {
            return JSON.stringify({ active: root.active, manual: root.manual, fullscreen: root.fullscreen });
        }
    }
}
