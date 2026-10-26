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
// A list entry is an app as you'd call it: a window class, a process or app name, or a
// word the app's .desktop file goes by. It's matched through the installed apps, so
// "telegram-desktop" also catches the Telegram process and the TelegramDesktop window,
// and "discord" catches Vesktop (its keywords say discord).
//
// Sites (blacklist only: /etc/hosts can't allow just a few): services/focus_hosts.py,
// started as root through pkexec when the session starts, sends them to 127.0.0.1 and
// serves the Focus Mode page (services/focus_page.html) there; it takes the block out
// for breaks and when the session ends, on our word through a FIFO. The page only shows
// for http://; browsers can't show it for https:// sites and show an error instead.
// Browsers with their own DNS over HTTPS skip /etc/hosts altogether, so browser windows
// are watched too: a tab whose title names a blocked site is closed (Ctrl+W).
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
    // Launchers in .desktop Exec lines: the app is what they run, not them.
    readonly property var launchers: ["flatpak", "env", "sh", "bash", "zsh", "fish", "python", "python3", "java",
        "electron", "wine", "gtk-launch", "xdg-open", "dbus-launch", "systemd-run", "uwsm", "app2unit",
        "gamemoderun", "prime-run", "mangohud", "sudo", "pkexec"]

    // name: what was blocked (app name or class), icon: its icon name or "".
    signal blocked(string name, string icon)

    // "org.telegram.desktop" -> "orgtelegramdesktop"
    function norm(name) {
        return (name ?? "").toLowerCase().replace(/[.\-_ ]/g, "");
    }
    function execName(entry) {
        const exec = entry.command?.[0] ?? "";
        const name = exec.includes(":") ? "" : exec.split("/").pop();
        return launchers.includes(name.toLowerCase()) ? "" : name;
    }
    function entryMatches(entry, item) {
        const n = norm(item);
        const names = [entry.id, entry.startupClass, entry.name, execName(entry)].map(norm).filter(x => x);
        return names.some(x => x === n || (n.length >= 5 && x.includes(n)))
            || (entry.keywords ?? []).some(k => k.toLowerCase() === item);
    }

    // Everything the listed apps go by (normalized): the entries themselves, plus the
    // ids, window classes, names and programs of the installed apps they point at.
    readonly property var targets: {
        const out = new Set(apps.map(norm).filter(x => x));
        if (!on)
            return [...out];
        for (const entry of DesktopEntries.applications.values) {
            if (!apps.some(a => entryMatches(entry, a)))
                continue;
            for (const x of [entry.id, entry.startupClass, entry.name, execName(entry)].map(norm))
                if (x.length >= 3)
                    out.add(x);
        }
        return [...out];
    }

    // Is `name` (a class, app id or process name) one of the listed apps?
    function listed(name) {
        const n = norm(name);
        return n !== "" && targets.some(t => n === t || (t.length >= 5 && n.includes(t)));
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
        const hit = apps.some(a => entryMatches(entry, a)) || listed(entry.startupClass) || listed(entry.id);
        return whitelist ? !hit : hit;
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

    // --- Windows (and browser tabs) ---
    readonly property bool watching: blocking || tabsBlocking
    function checkWindows() {
        if (watching)
            clients.running = true;
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!root.watching)
                return;
            if (event.name === "openwindow")
                root.checkWindows();
            else if (event.name === "windowtitlev2" && root.tabsBlocking)
                titleCheck.restart();
        }
    }
    // Titles change in bursts while a page loads.
    Timer {
        id: titleCheck
        interval: 250
        onTriggered: root.checkWindows()
    }

    // When a focus period starts (and the session with it): what's open already.
    onWatchingChanged: if (watching) checkWindows()
    onBlockingChanged: if (blocking) processes.running = true

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
                    if (root.blockedWindow([c.class, c.initialClass])) {
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
                    } else {
                        root.checkTab(c);
                    }
                }
            }
        }
    }

    // --- Browser tabs: the title names a blocked site ---
    readonly property bool tabsBlocking: on && sites.length > 0
    readonly property var browsers: ["zen", "firefox", "librewolf", "floorp", "waterfox", "chrom", "brave", "vivaldi",
        "yandex", "opera", "edge", "thorium", "mullvad", "tor-browser"]
    // How sites show up in titles: their name ("youtube" for youtube.com, "m.youtube.com"
    // too), and a few that title their pages differently.
    readonly property var titleAliases: ({
        "x.com": "/ x$", "twitter.com": "/ x$", "vk.com": "вконтакте|(^|[^a-zа-яё0-9])vk([^a-zа-яё0-9]|$)"
    })
    readonly property var siteMatchers: sites.map(site => {
        const labels = site.split(".");
        const name = labels.length >= 2 ? labels[labels.length - 2] : site;
        const parts = [];
        if (name.length >= 3)
            parts.push(`(^|[^a-zа-яё0-9])${name.replace(/[^a-z0-9-]/g, "")}([^a-zа-яё0-9]|$)`);
        if (titleAliases[site])
            parts.push(titleAliases[site]);
        return { site: site, re: parts.length ? new RegExp(parts.join("|"), "i") : null };
    }).filter(m => m.re)

    property var lastTabClose: ({}) // window address -> time
    function checkTab(c) {
        if (!tabsBlocking || !browsers.some(b => (c.class ?? "").toLowerCase().includes(b)))
            return;
        // Without the browser's name at the end ("… — Zen Browser").
        const title = (c.title ?? "").replace(/\s[—–-]\s[^—–-]*$/, "");
        const hit = siteMatchers.find(m => m.re.test(title));
        if (!hit)
            return;
        // The title lags behind the closed tab for a moment; don't close a second one.
        const now = Date.now();
        if (now - (lastTabClose[c.address] ?? 0) < 1500)
            return;
        const all = Object.assign({}, lastTabClose);
        all[c.address] = now;
        lastTabClose = all;
        Hyprland.dispatch(`hl.dsp.send_shortcut({ mods = "CTRL", key = "W", window = "address:${c.address}" })`);
        const entry = DesktopEntries.heuristicLookup(c.class);
        noticeAs(hit.site, entry?.icon ?? "");
        // The next tab may be a blocked one too.
        titleCheck.restart();
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
                const cut = root.targets.map(t => t.slice(0, 15));
                const named = new Set();
                for (const line of text.split("\n")) {
                    const m = line.trim().match(/^(\d+)\s+(.+)$/);
                    if (!m)
                        continue;
                    const comm = m[2].toLowerCase();
                    const n = root.norm(comm);
                    if (!cut.includes(n) || root.safeProcesses.includes(comm))
                        continue;
                    Quickshell.execDetached(["kill", "-TERM", m[1]]);
                    if (!named.has(n)) {
                        named.add(n);
                        root.notice(comm);
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
        noticeAs(entry?.name ?? id, entry?.icon ?? "");
    }
    function noticeAs(name, icon) {
        const now = Date.now();
        if (now - (lastNotice["@" + name] ?? 0) < 4000)
            return;
        const all = Object.assign({}, lastNotice);
        all["@" + name] = now;
        lastNotice = all;
        blocked(name, icon);
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
