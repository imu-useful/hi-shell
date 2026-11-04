pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
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

    // Notifications handed back to their popup card (the Reply button needs its text field).
    property var released: []

    // The island takes the notification instead of the popup card: every one that times out. Critical
    // ones, which stay until dismissed, keep their card, and so do the ones sent back with Reply.
    function handles(n) {
        return Config.options.bar.island.notifications && !n.critical && n.timeout > 0 && !released.includes(n.uid);
    }

    // The buttons floating by the island for the notification: its actions ("default" is the body click,
    // not a button), and Reply for the ones with an inline reply.
    readonly property var buttons: {
        if (!notif)
            return [];
        const list = notif.actions.filter(a => a.identifier !== "default" && a.text).map(a => ({ identifier: a.identifier, text: a.text }));
        if (notif.notification?.hasInlineReply)
            list.push({ identifier: "", text: Translation.tr("Reply"), reply: true });
        return list;
    }

    function press(button) {
        if (!notif)
            return;
        if (button.reply) {
            // The card, with its reply field, takes over.
            released = [...released, notif.uid];
            return;
        }
        Notifications.invoke(notif.uid, button.identifier);
    }

    // The pointer is over the island or its buttons: the notification's countdown waits.
    property var hovering: ({})
    readonly property bool hovered: Object.values(hovering).some(v => v)
    function setHover(source, value) {
        if (hovering[source] === value)
            return;
        const h = Object.assign({}, hovering);
        h[source] = value;
        hovering = h;
    }
    Binding {
        when: root.notif !== null
        target: root.notif
        property: "paused"
        value: root.hovered
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
