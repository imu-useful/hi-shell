pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.services

// The Dynamic Island's state (the island is the clock widget in the bar; see Clock.qml).
// Holding it (ShellState.islandSwitches counts completed holds) toggles between the default
// state (the clock) and the music player; the notification, privacy and update states of
// the later stages are shown by events, not by holding.
Singleton {
    id: root

    // The state asked for; `mode` is what is shown (music needs a player).
    property string wanted: "default"
    readonly property string mode: wanted === "music" && Mpris.hasPlayer ? "music" : "default"
    // The music state's full controls are open (a tap on the island).
    property bool expanded: false
    readonly property bool musicExpanded: expanded && mode === "music"

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
