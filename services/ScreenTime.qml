pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Hyprland
import qs.common

// Screen time: how long each app had the focus, per day, and an optional daily limit per app.
// Kept in ~/.local/state/hi-shell/screentime.json (the last DAYS_KEPT days). The focused window's app
// is counted every TICK seconds; a limit gives one notification a day when it runs out.
// Settings > Screen time shows it; `qs -c hi-shell ipc call screentime today` prints today's totals,
// `... screentime limit firefox 30` sets a limit (0 removes it).
Singleton {
    id: root

    readonly property int tick: 5 // seconds
    readonly property int daysKept: 60
    readonly property string file: Paths.state + "/screentime.json"
    readonly property string today: dayKey(new Date())

    // { days: { "YYYY-MM-DD": { appId: seconds } }, limits: { appId: minutes }, warned: { "YYYY-MM-DD": [appId] } }
    property var data: ({ days: {}, limits: {}, warned: {} })
    property bool loaded: false

    function pad(n) {
        return String(n).padStart(2, "0");
    }
    function dayKey(date) {
        return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
    }
    // The app of a window: its app id (its class), or "" when nothing is focused.
    function appOf(toplevel) {
        return (toplevel?.wayland?.appId ?? "").toLowerCase();
    }

    // [{ app, seconds }] for a day, most used first.
    function totals(key) {
        const day = data.days[key] ?? {};
        return Object.entries(day).map(([app, seconds]) => ({ app, seconds })).sort((a, b) => b.seconds - a.seconds);
    }
    // The last 7 days, oldest first: [{ key, seconds }].
    function week() {
        const out = [];
        for (let i = 6; i >= 0; i--) {
            const d = new Date();
            d.setDate(d.getDate() - i);
            const key = dayKey(d);
            out.push({ key, seconds: Object.values(data.days[key] ?? {}).reduce((sum, s) => sum + s, 0) });
        }
        return out;
    }
    // The app id of what was typed: a program name ("firefox", "Telegram") or its id ("org.telegram.desktop").
    function appKey(text) {
        const typed = text.trim();
        const entry = DesktopEntries.heuristicLookup(typed);
        return (entry?.id ?? typed.replace(/\.desktop$/i, "").split("/").pop()).toLowerCase();
    }
    // Every app with a limit, sorted.
    readonly property var limitedApps: Object.keys(data.limits).sort()

    function limitOf(app) {
        return data.limits[app] ?? 0;
    }
    // Minutes; 0 takes the limit away.
    function setLimit(app, minutes) {
        const limits = Object.assign({}, data.limits);
        if (minutes > 0)
            limits[app] = minutes;
        else
            delete limits[app];
        data = Object.assign({}, data, { limits });
        save();
    }

    function count(app) {
        const day = Object.assign({}, data.days[today]);
        day[app] = (day[app] ?? 0) + tick;
        data = Object.assign({}, data, { days: Object.assign({}, data.days, { [today]: day }) });
        checkLimit(app, day[app]);
    }

    function checkLimit(app, seconds) {
        const limit = limitOf(app);
        const warned = data.warned[today] ?? [];
        if (limit === 0 || seconds < limit * 60 || warned.includes(app))
            return;
        data = Object.assign({}, data, { warned: Object.assign({}, data.warned, { [today]: [...warned, app] }) });
        Quickshell.execDetached(["notify-send", "-a", "hi-shell", "-i", "hourglass_top", Translation.tr("Time is up for %1").arg(app), Translation.tr("%1 minutes today, the limit you set").arg(limit)]);
    }

    function save() {
        if (!loaded)
            return;
        const days = {};
        for (const key of Object.keys(data.days).sort().slice(-daysKept))
            days[key] = data.days[key];
        store.setText(JSON.stringify(Object.assign({}, data, { days }), null, 2) + "\n");
    }

    Timer {
        running: true
        interval: root.tick * 1000
        repeat: true
        onTriggered: {
            const app = root.appOf(Hyprland.activeToplevel);
            if (app !== "")
                root.count(app);
        }
    }

    // Saved now and then, not at every tick.
    Timer {
        running: root.loaded
        interval: 30000
        repeat: true
        onTriggered: root.save()
    }

    FileView {
        id: store
        path: root.file
        printErrors: false
        onLoaded: {
            try {
                const saved = JSON.parse(text());
                root.data = { days: saved.days ?? {}, limits: saved.limits ?? {}, warned: saved.warned ?? {} };
            } catch (e) {
                console.warn("ScreenTime: invalid file", e);
            }
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }

    IpcHandler {
        target: "screentime"

        function today(): string {
            return JSON.stringify(root.totals(root.today));
        }
        // Minutes for an app (its name or command; 0 removes the limit), and the limits as JSON.
        function limit(program: string, minutes: int): void {
            root.setLimit(root.appKey(program), minutes);
        }
        function limits(): string {
            return JSON.stringify(root.data.limits);
        }
    }
}
