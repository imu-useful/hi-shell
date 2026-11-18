pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import "../common/Bedtime.js" as Logic

// Bedtime: at `bedtime.time` a full-screen reminder (modules/BedtimeScreen.qml) says it's time
// to sleep, and keeps coming back until `bedtime.wake` unless it was put off for the night.
// "Later" brings it back after `bedtime.snoozeMinutes`. What was picked tonight is kept in
// ~/.local/state/hi-shell/bedtime.json, so a restart doesn't bring it back early.
// IPC: `qs -c hi-shell ipc call bedtime open` (also snooze, skip, status).
Singleton {
    id: root

    readonly property var options: Config.options.bedtime
    readonly property string file: Paths.state + "/bedtime.json"
    readonly property int checkEvery: 15000 // ms

    // { skippedNight: "YYYY-MM-DD" (the evening it was put off), snoozedUntil: ms since the epoch }
    property var state: ({ skippedNight: "", snoozedUntil: 0 })
    property bool loaded: false
    // The reminder is on screen.
    property bool showing: false

    function check() {
        if (loaded && !showing && Logic.due(new Date(), options, state))
            show();
    }
    function show() {
        showing = true;
    }
    function setState(changes) {
        state = Object.assign({}, state, changes);
        store.setText(JSON.stringify(state, null, 2) + "\n");
    }
    // Back in `bedtime.snoozeMinutes`.
    function snooze() {
        setState({ snoozedUntil: Date.now() + Math.max(1, options.snoozeMinutes) * 60000 });
        showing = false;
    }
    // Quiet until the next evening (or for good tonight, when it's shown outside bedtime as a preview).
    function skip() {
        const night = Logic.nightOf(new Date(), options.time, options.wake);
        if (night !== "")
            setState({ skippedNight: night });
        showing = false;
    }
    // Sleep or power off. A snooze first: waking up still at night brings it back later, not at once.
    function suspend() {
        snooze();
        Qt.callLater(() => Session.suspend());
    }
    function poweroff() {
        showing = false;
        Qt.callLater(() => Session.poweroff());
    }

    // A new time for tonight drops an old snooze, so moving 23:00 to 22:00 works right away.
    Connections {
        target: root.options
        function onTimeChanged() {
            if (root.loaded)
                root.setState({ snoozedUntil: 0 });
            root.check();
        }
        function onEnabledChanged() {
            if (!root.options.enabled)
                root.showing = false;
            root.check();
        }
    }

    Timer {
        running: root.loaded && root.options.enabled
        interval: root.checkEvery
        repeat: true
        triggeredOnStart: true
        onTriggered: root.check()
    }

    FileView {
        id: store
        path: root.file
        printErrors: false
        onLoaded: {
            try {
                const saved = JSON.parse(text());
                root.state = { skippedNight: String(saved.skippedNight ?? ""), snoozedUntil: Number(saved.snoozedUntil) || 0 };
            } catch (e) {
                console.warn("Bedtime: invalid file", e);
            }
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }

    IpcHandler {
        target: "bedtime"

        function open(): void { root.show(); }
        function snooze(): void { root.snooze(); }
        function skip(): void { root.skip(); }
        function status(): string {
            return JSON.stringify({ enabled: root.options.enabled, time: root.options.time, wake: root.options.wake, showing: root.showing, state: root.state });
        }
    }
}
