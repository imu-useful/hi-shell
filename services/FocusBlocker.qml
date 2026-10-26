pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.common

// Focus Mode app blocking, during focus periods only (Focus.restricted; breaks are free).
// Blacklist: windows of listed apps are killed as they open (and those already open
// when a focus period starts), and so are their background processes (Steam in the
// tray, say), checked every few seconds. Whitelist: windows of any other app are closed
// politely (the app may ask to save); processes are left alone, and an empty whitelist
// blocks nothing. The launcher and the dock don't start a blocked app at all. Each block
// emits blocked(), which modules/focus/BlockedToast.qml shows.
//
// A list entry is a window class or a process name: "steam", "telegram-desktop", or a
// word of the class ("telegram" for org.telegram.desktop).
Singleton {
    id: root

    readonly property bool on: Focus.restricted
    readonly property var lists: Focus.sessionProfile.lists ?? ({})
    readonly property bool whitelist: lists.mode === "whitelist"
    readonly property var apps: (lists[lists.mode]?.apps ?? []).map(a => a.toLowerCase())
    readonly property bool blocking: on && apps.length > 0

    // Never closed in whitelist mode: the shell, portals, auth dialogs.
    readonly property var safeWindows: ["org.quickshell", "xdg-desktop-portal-gtk", "xdg-desktop-portal-kde",
        "xdg-desktop-portal-hyprland", "hyprpolkitagent", "polkit-gnome-authentication-agent-1",
        "org.kde.polkit-kde-authentication-agent-1", "pinentry", "gcr-prompter"]
    // Never killed, whatever the blacklist says.
    readonly property var safeProcesses: ["quickshell", "qs", "hyprland", "systemd", "dbus-daemon", "dbus-broker",
        "pipewire", "wireplumber", "xwayland", "sddm", "login", "sudo", "pkexec", "polkitd"]

    // name: what was blocked (app name or class), icon: its icon name or "".
    signal blocked(string name, string icon)

    // Is `name` (a class, app id or process name) on the list?
    function listed(name) {
        const n = (name ?? "").toLowerCase();
        if (!n)
            return false;
        const words = n.split(/[.\-_ ]/);
        return apps.some(a => n === a || words.includes(a) || (a.length >= 5 && n.includes(a)));
    }

    // A window (class / initial class) that has to go.
    function blockedWindow(classes) {
        if (!blocking)
            return false;
        if (whitelist)
            return !classes.some(c => listed(c) || safeWindows.includes((c ?? "").toLowerCase()));
        return classes.some(c => listed(c));
    }

    // For the launcher and the dock: a DesktopEntry that shouldn't start.
    function blockedEntry(entry) {
        if (!blocking || !entry)
            return false;
        const names = [entry.id, entry.startupClass, entry.name, (entry.command?.[0] ?? "").split("/").pop()];
        return whitelist ? !names.some(n => listed(n)) : names.some(n => listed(n));
    }

    // Launch an app unless it's blocked (then say so); returns whether it started.
    function launch(entry) {
        if (blockedEntry(entry)) {
            blocked(entry.name, entry.icon ?? "");
            return false;
        }
        entry.execute();
        return true;
    }

    // --- Windows ---
    function checkWindows() {
        if (blocking)
            clients.running = true;
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (root.blocking && event.name === "openwindow")
                root.checkWindows();
        }
    }

    // When a focus period starts (and the session with it): what's open already.
    onBlockingChanged: {
        if (blocking) {
            checkWindows();
            processes.running = true;
        }
    }

    Process {
        id: clients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {
                    return;
                }
                const named = new Set();
                for (const c of list) {
                    if (!root.blockedWindow([c.class, c.initialClass]))
                        continue;
                    if (root.whitelist) {
                        Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${c.address}" })`);
                    } else if (c.pid > 0) {
                        Quickshell.execDetached(["kill", "-TERM", String(c.pid)]);
                    }
                    const id = c.class || c.initialClass;
                    if (!named.has(id)) {
                        named.add(id);
                        root.notice(id);
                    }
                }
            }
        }
    }

    // --- Background processes (blacklist only) ---
    Timer {
        running: root.blocking && !root.whitelist
        interval: 3000
        repeat: true
        onTriggered: processes.running = true
    }

    Process {
        id: processes
        command: ["ps", "-u", Quickshell.env("USER"), "-o", "pid=,comm="]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.blocking || root.whitelist)
                    return;
                // comm is cut at 15 characters.
                const cut = root.apps.map(a => a.slice(0, 15));
                const named = new Set();
                for (const line of text.split("\n")) {
                    const m = line.trim().match(/^(\d+)\s+(.+)$/);
                    if (!m)
                        continue;
                    const comm = m[2].toLowerCase();
                    if (!cut.includes(comm) || root.safeProcesses.includes(comm))
                        continue;
                    Quickshell.execDetached(["kill", "-TERM", m[1]]);
                    if (!named.has(comm)) {
                        named.add(comm);
                        root.notice(root.apps[cut.indexOf(comm)]);
                    }
                }
            }
        }
    }

    // One notice per app every few seconds (an app killed in a loop shouldn't flood).
    property var lastNotice: ({})
    function notice(id) {
        const now = Date.now();
        if (now - (lastNotice[id] ?? 0) < 8000)
            return;
        const all = Object.assign({}, lastNotice);
        all[id] = now;
        lastNotice = all;
        const entry = DesktopEntries.heuristicLookup(id);
        blocked(entry?.name ?? id, entry?.icon ?? "");
    }
}
