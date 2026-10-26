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
//
// Sites (blacklist only: /etc/hosts can't allow just a few): services/focus_hosts.py,
// started as root through pkexec when the session starts, sends them to 127.0.0.1 and
// serves the Focus Mode page (services/focus_page.html) there; it takes the block out
// for breaks and when the session ends, on our word through a FIFO. The page only shows
// for http://; browsers can't show it for https:// sites and show an error instead.
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

    // --- Sites ---
    readonly property var sites: Focus.active && lists.mode === "blacklist" ? (lists.blacklist?.sites ?? []) : []
    readonly property bool sitesWanted: sites.length > 0
    // The helper is running (the sites are set up for this session).
    property bool sitesRunning: false
    readonly property bool sitesBlocked: sitesRunning && Focus.restricted
    readonly property string fifo: `${Quickshell.env("XDG_RUNTIME_DIR")}/hi-shell-focus.fifo`
    readonly property string pageState: `${Paths.state}/focus_page.json`
    readonly property string helper: `${Quickshell.shellDir}/services/focus_hosts.py`
    property bool checked: false

    function send(command) {
        Quickshell.execDetached(["timeout", "3", "sh", "-c", '[ -p "$1" ] && printf "%s\\n" "$2" > "$1"', "sh", fifo, command]);
    }

    function syncSites() {
        if (!checked || !Focus.sessionChecked)
            return;
        if (sitesWanted && !sitesRunning && !hostsStart.running) {
            writePage();
            hostsStart.command = ["pkexec", "/usr/bin/python3", helper, "start", "--user", Quickshell.env("USER"),
                "--fifo", fifo, "--page", `${Quickshell.shellDir}/services/focus_page.html`, "--state", pageState, ...sites];
            hostsStart.running = true;
        } else if (!sitesWanted && sitesRunning) {
            send("stop");
            sitesRunning = false;
        }
    }
    onSitesWantedChanged: syncSites()

    // Breaks open the sites again; the next focus period blocks them.
    Connections {
        target: Focus
        function onSessionCheckedChanged() {
            root.syncSites();
            if (root.sitesRunning && root.sitesWanted)
                root.send(Focus.restricted ? "block" : "unblock");
        }
        function onRestrictedChanged() {
            if (root.sitesRunning)
                root.send(Focus.restricted ? "block" : "unblock");
        }
        function onPhaseChanged() {
            if (root.sitesRunning)
                pageTimer.restart();
        }
    }

    Process {
        id: hostsStart
        onExited: code => {
            root.sitesRunning = code === 0;
            if (code !== 0) {
                ShellState.osdMessage("public_off", Translation.tr("Sites aren't blocked: no permission"));
            } else if (!Focus.restricted) {
                root.send("unblock");
            }
            // The session may have ended while the password was asked for.
            if (root.sitesRunning && !root.sitesWanted)
                root.syncSites();
        }
    }

    // At startup: a helper still running from before a shell restart (keep it if the
    // session goes on, else stop it), or a block left in /etc/hosts by a crash.
    Process {
        id: startupCheck
        running: true
        command: ["sh", "-c", '[ -p "$1" ] && echo running; grep -qF "hi-shell focus mode" /etc/hosts && echo hosts; true', "sh", root.fifo]
        stdout: StdioCollector {
            onStreamFinished: {
                const running = text.includes("running");
                if (running)
                    root.sitesRunning = true;
                else if (text.includes("hosts") && !root.sitesWanted)
                    Quickshell.execDetached(["pkexec", "/usr/bin/python3", root.helper, "restore"]);
                root.checked = true;
                // Focus may load its session a moment later; syncSites runs again then.
                root.syncSites();
                if (root.sitesRunning && root.sitesWanted)
                    root.send(Focus.restricted ? "block" : "unblock");
            }
        }
    }

    // What the page shows: the phase's end, in the shell's colors and language.
    Timer {
        id: pageTimer
        interval: 200
        onTriggered: root.writePage()
    }
    function writePage() {
        const last = Focus.sessionProfile.exit === "timer" && Focus.phase.cycle >= (Focus.sessionProfile.timer?.cycles ?? 0);
        const hex = TerminalColors.hex;
        page.setText(JSON.stringify({
            title: Translation.tr("This site is blocked"),
            subtitle: (last ? Translation.tr("Focus Mode is on (%1). The site opens again when the session ends.")
                            : Translation.tr("Focus Mode is on (%1). The site opens again at the break.")).arg(Focus.profileName(Focus.sessionProfile)),
            until: last ? Translation.tr("until the end") : Translation.tr("until the break"),
            start: Focus.phase.start,
            end: Focus.phase.end,
            footer: Translation.tr("hi-shell · Focus Mode"),
            lang: Translation.code,
            font: Appearance.font.main,
            quotes: [
                Translation.tr("The secret of getting ahead is getting started."),
                Translation.tr("You don't have to see the whole staircase, just take the first step."),
                Translation.tr("Small steps every day add up to big results."),
                Translation.tr("Focus on being productive instead of busy."),
                Translation.tr("The best time to start was yesterday. The next best time is now.")
            ],
            colors: {
                "surface": hex(Colors.m3surface), "container": hex(Colors.m3surfaceContainer),
                "high": hex(Colors.m3surfaceContainerHigh), "on-surface": hex(Colors.m3onSurface),
                "variant": hex(Colors.m3onSurfaceVariant), "primary": hex(Colors.m3primary),
                "on-primary": hex(Colors.m3onPrimary), "primary-container": hex(Colors.m3primaryContainer),
                "on-primary-container": hex(Colors.m3onPrimaryContainer), "tertiary": hex(Colors.m3tertiary),
                "outline": hex(Colors.m3outline)
            }
        }) + "\n");
    }
    FileView {
        id: page
        path: root.pageState
        atomicWrites: true
        printErrors: false
        blockLoading: true
    }
}
