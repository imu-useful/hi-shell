pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.common

// Viewing mode: for a film, a series, a video or a game. While it's on, the bar hides, notifications
// wait (as in Focus Mode) and the screen stays on. It's on when turned on by hand (the Viewing quick
// toggle, `qs -c hi-shell ipc call viewing toggle`), or by itself while a window is fullscreen and either
// something plays or it's a game (a Steam or Proton game, or gamescope). Config viewing.auto. Off, everything
// goes back the way it was.
Singleton {
    id: root

    readonly property var options: Config.options.viewing

    property bool manual: false
    // The focused window is fullscreen (Hyprland: 2 = fullscreen, 1 = maximized), checked every second.
    property bool fullscreen: false
    // A fullscreen game: Steam and Proton games (their class is steam_app_<id>) and gamescope.
    property bool game: false
    readonly property bool wanted: manual || (options.auto && fullscreen && (Mpris.playing || game))
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
        onTriggered: {
            const window = Hyprland.activeToplevel?.lastIpcObject;
            root.fullscreen = (window?.fullscreen ?? 0) >= 2;
            const cls = window?.class ?? "";
            root.game = cls.startsWith("steam_app_") || cls === "gamescope";
        }
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
