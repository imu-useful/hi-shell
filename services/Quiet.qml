pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.common

// Quiet: for a game. While it's on, the bar hides, notifications wait (as in Focus Mode) and the screen
// stays on. It's on when turned on by hand (the Quiet quick toggle, `qs -c hi-shell ipc call quiet toggle`),
// or by itself while a game is fullscreen (a Steam or Proton game, or gamescope; Config quiet.auto).
// Off, everything goes back the way it was. Viewing mode (services/Viewing.qml) is the same for films.
Singleton {
    id: root

    readonly property var options: Config.options.quiet

    property bool manual: false
    // The focused window is a game and fullscreen, checked every second.
    property bool inGame: false
    readonly property bool wanted: manual || (options.auto && inGame)
    property bool active: false
    property bool wasBarHidden: false
    property bool wasDnd: false

    onWantedChanged: apply(wanted)

    function isGame(toplevel) {
        const cls = toplevel?.lastIpcObject?.class ?? "";
        return (cls.startsWith("steam_app_") || cls === "gamescope") && (toplevel?.lastIpcObject?.fullscreen ?? 0) >= 2;
    }

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
        onTriggered: root.inGame = root.isGame(Hyprland.activeToplevel)
    }

    Process {
        id: keepAwake
        command: ["systemd-inhibit", "--what=idle", "--who=hi-shell", "--why=Quiet mode", "sleep", "infinity"]
    }

    IpcHandler {
        target: "quiet"

        function toggle(): void {
            root.toggle();
        }
        function status(): string {
            return JSON.stringify({ active: root.active, manual: root.manual, inGame: root.inGame });
        }
    }
}
