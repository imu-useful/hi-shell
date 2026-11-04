pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.common
import qs.services

// The Dynamic Island's state (the island is the clock widget in the bar; see Clock.qml).
// Holding it (ShellState.islandSwitches counts completed holds) toggles between the default
// state (the clock) and the music player. Notifications and the camera / microphone indicator
// are shown by events, over whatever state it is in, and over a fullscreen window by the
// overlay (IslandOverlay.qml).
Singleton {
    id: root

    // The state asked for; `mode` is what is shown (music needs a player).
    property string wanted: "default"
    readonly property string mode: wanted === "music" && Mpris.hasPlayer ? "music" : "default"
    // The music state's full controls are open (a tap on the island).
    property bool expanded: false
    readonly property bool musicExpanded: expanded && mode === "music"

    // The notification the island shows now (the newest one it handles), null when none.
    readonly property var notif: Notifications.popups.find(n => handles(n)) ?? null
    // Something to show over a fullscreen window.
    readonly property bool alertActive: notif !== null || Privacy.active

    // The island takes the notification instead of the popup card: the ones that time out and need no
    // answer; over a fullscreen window also the ones with actions (replies), since the island is
    // where the user is looking. Critical ones, which stay until dismissed, keep their card.
    function handles(n) {
        if (!Config.options.bar.island.notifications || n.critical || n.timeout <= 0)
            return false;
        return (n.actions?.length ?? 0) === 0 || Fullscreen.on(Hyprland.focusedMonitor?.name ?? "");
    }

    Connections {
        target: ShellState
        function onIslandSwitchesChanged() {
            root.expanded = false;
            root.wanted = root.mode === "music" ? "default" : "music";
        }
    }

    // `qs -c hi-shell ipc call island cycle` = a completed hold; `expand` = a tap in the music state.
    IpcHandler {
        target: "island"

        function cycle(): void {
            ShellState.islandSwitches++;
        }
        function expand(): void {
            root.expanded = !root.expanded;
        }
    }
}
