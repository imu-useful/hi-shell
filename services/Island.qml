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

    readonly property var options: Config.options.bar.island
    readonly property bool enabled: options.enabled
    // There is a state to switch to: a hold on the island does something.
    readonly property bool canSwitch: enabled && options.music

    // The state asked for; `mode` is what is shown (music needs a player).
    property string wanted: "default"
    readonly property string mode: canSwitch && wanted === "music" && Mpris.hasPlayer ? "music" : "default"
    // The music state's full controls are open (a tap on the island).
    property bool expanded: false
    readonly property bool musicExpanded: expanded && mode === "music"

    // The notification the island shows now (the newest one it handles), null when none.
    readonly property var notif: Notifications.popups.find(n => handles(n)) ?? null
    // A notification lands like a ball: this goes from above the island's place (negative, in px) down to 0,
    // bouncing. The clock and the bar's background under it move by it.
    property real drop: 0
    onNotifChanged: {
        hoverSpent = false;
        if (notif !== null) {
            ball.restart();
        } else {
            // Stopped mid-bounce it would stay off its place.
            ball.stop();
            drop = 0;
        }
    }
    NumberAnimation {
        id: ball
        target: root
        property: "drop"
        from: -16
        to: 0
        duration: Appearance.anim.speed > 0 ? 900 : 0
        easing.type: Easing.OutBounce
    }

    // A tap on the notification: what the app asked for ("default": most apps focus their window), else
    // the first link in the text, else the app itself. Then the notification is done with.
    function open() {
        const n = notif;
        if (!n)
            return;
        if (n.actions.some(a => a.identifier === "default")) {
            Notifications.invoke(n.uid, "default");
        } else {
            const url = /https?:\/\/[^\s"'<>]+/.exec(`${n.body} ${n.summary}`)?.[0];
            if (url)
                Qt.openUrlExternally(url);
            else
                DesktopEntries.heuristicLookup(n.appName)?.execute();
        }
        // Done with, even when the app keeps the notification (resident ones are not dismissed by invoke).
        close(n);
    }

    // Hide the notification's popup now; the pointer resting on the island must not hold the next one.
    function close(n) {
        Notifications.hidePopup(n.uid);
        hovering = ({});
    }

    // The island takes the whole bar (the other widgets leave) while it shows music or a notification.
    readonly property bool compact: enabled && options.hideBar && (mode === "music" || notif !== null)
    // Something to show over a fullscreen window.
    readonly property bool privacy: enabled && options.privacy && Privacy.active
    readonly property bool alertActive: notif !== null || privacy

    // Notifications handed back to their popup card (the Reply button needs its text field).
    property var released: []

    // The island takes the notification instead of the popup card: every one that times out. Critical
    // ones, which stay until dismissed, keep their card, and so do the ones sent back with Reply.
    function handles(n) {
        if (!enabled || !options.notifications || n.critical || n.timeout <= 0 || released.includes(n.uid))
            return false;
        // The bar is hidden over a fullscreen window: without the overlay the popup card is the only way.
        return options.fullscreen || !Fullscreen.on(Hyprland.focusedMonitor?.name ?? "");
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
    // Hovering holds the countdown, but not for ever: the island grows under a pointer that is just resting
    // there, and a notification waiting for it would never go. Past holdLimit it goes on counting.
    readonly property bool hovered: Object.values(hovering).some(v => v) && !hoverSpent
    property bool hoverSpent: false
    readonly property int holdLimit: 6000
    Timer {
        interval: root.holdLimit
        running: Object.values(root.hovering).some(v => v) && root.notif !== null && !root.hoverSpent
        onTriggered: root.hoverSpent = true
    }
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

    // `qs -c hi-shell ipc call island cycle` = a completed hold; `expand` = a tap in the music state; `open` = a tap on a notification.
    IpcHandler {
        target: "island"

        function cycle(): void {
            ShellState.islandSwitches++;
        }
        function open(): void {
            root.open();
        }
        function expand(): void {
            root.expanded = !root.expanded;
        }
    }
}
