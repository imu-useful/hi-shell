pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Focus Mode settings: profiles and session tasks in ~/.config/hi-shell/focus_profiles.json
// (see SPEC_FOCUS.md). A profile holds the Pomodoro timer, the wallpaper, the block /
// allow lists and the exit condition; selecting one makes it the active profile, and
// edits go to the active profile. Built-in profiles (Study, Work) can be edited and
// reset; your own ones get a name and an icon of their choice and can be deleted. Tasks
// are the shell's to-do list (services/Todo.qml); this file only keeps which of them are
// picked for the session.
//
// A session (start / stop) puts the shell in Zen mode (ShellState.zen): a minimal bar,
// no desktop widgets, no animations, blur or cover mode, the profile's wallpaper, and
// Settings, the left sidebar, the wallpaper picker and the Focus settings window locked.
// What it changes is kept in ~/.local/state/hi-shell/focus_session.json, so a restart
// of the shell stays in the session and stopping puts everything back.
Singleton {
    id: root

    readonly property string path: `${Config.dir}/focus_profiles.json`

    // A session runs; the settings window stays closed while it's true.
    property bool active: false
    property real startedAt: 0
    property var sessionProfile: ({}) // the profile as it was when the session started
    // Values to put back on stop: { wallpaper, blur, animations }
    property var restore: ({})
    property bool settingsOpen: false
    property string settingsTab: "timer" // timer, wallpaper, lists, profiles, todo, exit

    property var profiles: ({})
    property string activeId: "study"
    property var sessionTasks: [] // Todo item `time`s picked for the session
    property bool loaded: false

    readonly property var profile: profiles[activeId] ?? profiles.study ?? defaults().study
    readonly property var profileIds: Object.keys(profiles).sort((a, b) => order(a) - order(b))

    function order(id) {
        return id === "study" ? 0 : id === "work" ? 1 : 10;
    }

    // Icons to choose from for your own profiles.
    readonly property var icons: ["bookmark", "edit_note", "code", "science", "translate", "calculate",
        "brush", "music_note", "fitness_center", "menu_book", "draw", "terminal", "design_services",
        "rocket_launch", "spa", "local_cafe", "lightbulb", "favorite"]

    // Starting point for a new profile.
    function blank() {
        return {
            timer: { focus: 25, shortBreak: 5, longBreak: 15, cycles: 4 },
            wallpaper: "",
            lists: { mode: "blacklist", blacklist: { apps: [], sites: [] }, whitelist: { apps: [], sites: [] } },
            exit: "manual"
        };
    }

    function defaults() {
        const lists = (blockApps, blockSites) => ({
            mode: "blacklist", // blacklist | whitelist
            blacklist: { apps: blockApps, sites: blockSites },
            whitelist: { apps: [], sites: [] }
        });
        return {
            study: {
                name: "Study", icon: "school", builtin: true,
                timer: { focus: 25, shortBreak: 5, longBreak: 15, cycles: 4 },
                wallpaper: "",
                lists: lists(["steam", "discord", "telegram-desktop", "spotify"],
                             ["youtube.com", "tiktok.com", "instagram.com", "twitter.com", "x.com", "reddit.com", "twitch.tv", "vk.com"]),
                exit: "timer" // manual | timer | tasks
            },
            work: {
                name: "Work", icon: "work", builtin: true,
                timer: { focus: 50, shortBreak: 10, longBreak: 20, cycles: 3 },
                wallpaper: "",
                lists: lists(["steam", "osu!"],
                             ["youtube.com", "tiktok.com", "instagram.com", "reddit.com", "twitch.tv"]),
                exit: "tasks"
            }
        };
    }

    // --- Profiles ---
    function select(id) {
        if (!profiles[id])
            return;
        activeId = id;
        save();
    }

    // Change one value of the active profile: set("timer.focus", 30)
    function set(path, value) {
        const p = JSON.parse(JSON.stringify(profile));
        const keys = path.split(".");
        let o = p;
        keys.slice(0, -1).forEach(k => o = o[k] = o[k] ?? {});
        o[keys[keys.length - 1]] = value;
        const all = Object.assign({}, profiles);
        all[activeId] = p;
        profiles = all;
        save();
    }

    // A new profile of your own, blank or a copy of the active one; returns its id.
    function add(name, icon, copy) {
        const id = "profile-" + Date.now().toString(36);
        const p = JSON.parse(JSON.stringify(copy ? profile : blank()));
        p.name = name.trim() || Translation.tr("New profile");
        p.icon = icon || "bookmark";
        p.builtin = false;
        const all = Object.assign({}, profiles);
        all[id] = p;
        profiles = all;
        activeId = id;
        save();
        return id;
    }

    // Name and icon of your own profiles: update(id, { name, icon })
    function update(id, changes) {
        if (!profiles[id] || profiles[id].builtin || changes.name?.trim() === "")
            return;
        if (changes.name)
            changes.name = changes.name.trim();
        const all = Object.assign({}, profiles);
        all[id] = Object.assign({}, all[id], changes);
        profiles = all;
        save();
    }

    function remove(id) {
        if (!profiles[id] || profiles[id].builtin)
            return;
        const all = Object.assign({}, profiles);
        delete all[id];
        profiles = all;
        if (activeId === id)
            activeId = "study";
        save();
    }

    // Built-in profiles back to their defaults.
    function reset(id) {
        const d = defaults()[id];
        if (!d)
            return;
        const all = Object.assign({}, profiles);
        all[id] = d;
        profiles = all;
        save();
    }

    // --- Lists of the active profile (kind: apps | sites) ---
    function listItems(kind) {
        const l = profile.lists;
        return l[l.mode]?.[kind] ?? [];
    }
    function addListItem(kind, value) {
        const v = value.trim().toLowerCase().replace(/^https?:\/\//, "").replace(/\/.*$/, "");
        if (!v || listItems(kind).includes(v))
            return;
        set(`lists.${profile.lists.mode}.${kind}`, [...listItems(kind), v]);
    }
    function removeListItem(kind, value) {
        set(`lists.${profile.lists.mode}.${kind}`, listItems(kind).filter(x => x !== value));
    }

    // --- Tasks (Todo items, keyed by their `time`) ---
    function isSessionTask(item) {
        return sessionTasks.includes(item.time);
    }
    function setSessionTask(item, on) {
        const rest = sessionTasks.filter(t => t !== item.time && Todo.items.some(i => i.time === t));
        sessionTasks = on ? [...rest, item.time] : rest;
        save();
    }
    // Added from the Focus window: picked for the session right away.
    function addTask(text) {
        const before = Todo.items.length;
        Todo.add(text);
        if (Todo.items.length > before)
            setSessionTask(Todo.items[Todo.items.length - 1], true);
    }

    // --- File ---
    function save() {
        if (loaded)
            saveTimer.restart();
    }
    Timer {
        id: saveTimer
        interval: 300
        onTriggered: file.setText(JSON.stringify({
            version: 1,
            activeProfile: root.activeId,
            profiles: root.profiles,
            sessionTasks: root.sessionTasks
        }, null, 2) + "\n")
    }

    // --- Session ---
    function start() {
        if (active || !loaded)
            return;
        active = true;
        startedAt = Date.now();
        sessionProfile = JSON.parse(JSON.stringify(profile));
        restore = { wallpaper: Wallpapers.current };
        settingsOpen = false;
        ShellState.settingsOpen = ShellState.sidebarLeftOpen = ShellState.wallpaperSelectorOpen = false;
        ShellState.desktopEditing = false;
        ShellState.zen = true;
        // Hyprland's values first, to put them back afterwards; then turn them off.
        hyprQuery.running = true;
        if (sessionProfile.wallpaper && sessionProfile.wallpaper !== Wallpapers.current)
            Wallpapers.set(sessionProfile.wallpaper);
        writeSession();
        ShellState.osdMessage(sessionProfile.icon, Translation.tr("Focus Mode: %1").arg(profileName(sessionProfile)));
    }

    function stop() {
        if (!active)
            return;
        // Only if it's still the focus wallpaper (not changed some other way since).
        if (restore.wallpaper && sessionProfile.wallpaper && Wallpapers.current === sessionProfile.wallpaper)
            Wallpapers.set(restore.wallpaper);
        hyprOff(false);
        active = false;
        ShellState.zen = false;
        sessionFile.setText("{}\n");
        ShellState.osdMessage("check_circle", Translation.tr("Focus Mode is over"));
    }

    function profileName(p) {
        return p.builtin ? Translation.tr(p.name) : p.name;
    }

    // Blur and animations off (or back to what they were).
    function hyprOff(off) {
        const blur = off ? false : (restore.blur ?? true);
        const animations = off ? false : (restore.animations ?? true);
        HyprlandSettings.apply(`hl.config({ decoration = { blur = { enabled = ${blur} } }, animations = { enabled = ${animations} } })`);
    }

    function writeSession() {
        sessionFile.setText(JSON.stringify({
            active: true,
            startedAt: startedAt,
            profileId: activeId,
            profile: sessionProfile,
            restore: restore
        }, null, 2) + "\n");
    }

    Process {
        id: hyprQuery
        command: ["sh", "-c", "hyprctl getoption decoration:blur:enabled -j; hyprctl getoption animations:enabled -j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const r = Object.assign({}, root.restore);
                for (const line of text.split("\n").filter(l => l.trim())) {
                    try {
                        const o = JSON.parse(line);
                        const v = o.bool ?? !!o.int;
                        if (o.option === "decoration:blur:enabled")
                            r.blur = v;
                        else if (o.option === "animations:enabled")
                            r.animations = v;
                    } catch (e) {}
                }
                root.restore = r;
                if (root.active) {
                    root.hyprOff(true);
                    root.writeSession();
                }
            }
        }
    }

    // Back in the session after a shell restart.
    FileView {
        id: sessionFile
        path: `${Paths.state}/focus_session.json`
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (!d.active)
                    return;
                root.startedAt = d.startedAt;
                root.sessionProfile = d.profile;
                root.restore = d.restore ?? {};
                root.active = true;
                ShellState.zen = true;
                // Hyprland may have been reloaded meanwhile.
                root.hyprOff(true);
            } catch (e) {
                console.warn("Focus: bad session file", e);
            }
        }
    }

    // Locked while a session runs: opening any of these just says so.
    Connections {
        target: ShellState
        function locked() {
            ShellState.osdMessage("lock", Translation.tr("Locked during Focus Mode"));
        }
        function onSettingsOpenChanged() {
            if (ShellState.zen && ShellState.settingsOpen) {
                ShellState.settingsOpen = false;
                locked();
            }
        }
        function onSidebarLeftOpenChanged() {
            if (ShellState.zen && ShellState.sidebarLeftOpen) {
                ShellState.sidebarLeftOpen = false;
                locked();
            }
        }
        function onWallpaperSelectorOpenChanged() {
            if (ShellState.zen && ShellState.wallpaperSelectorOpen) {
                ShellState.wallpaperSelectorOpen = false;
                locked();
            }
        }
    }
    onSettingsOpenChanged: {
        if (active && settingsOpen) {
            settingsOpen = false;
            ShellState.osdMessage("lock", Translation.tr("Locked during Focus Mode"));
        }
    }

    function apply(data) {
        const d = defaults();
        // Keep the built-in ones even if the file lost them; fill in missing keys. A
        // built-in profile that isn't one anymore (the old "custom") is dropped.
        const merged = Object.assign({}, d);
        for (const id in data.profiles ?? {}) {
            const p = data.profiles[id];
            if (p.builtin && !d[id])
                continue;
            const base = d[id] ?? blank();
            const lists = Object.assign({}, base.lists, p.lists);
            for (const mode of ["blacklist", "whitelist"])
                lists[mode] = Object.assign({ apps: [], sites: [] }, lists[mode]);
            merged[id] = Object.assign({}, base, p, {
                builtin: !!d[id],
                timer: Object.assign({}, base.timer, p.timer),
                lists: lists
            });
        }
        profiles = merged;
        activeId = merged[data.activeProfile] ? data.activeProfile : "study";
        sessionTasks = Array.isArray(data.sessionTasks) ? data.sessionTasks : [];
    }

    FileView {
        id: file
        path: root.path
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                root.apply(JSON.parse(text()));
            } catch (e) {
                console.warn("Focus: bad", root.path, e);
                root.apply({});
            }
            root.loaded = true;
        }
        onLoadFailed: error => {
            // First run: write the defaults.
            root.apply({});
            root.loaded = true;
            if (error === FileViewError.FileNotFound)
                root.save();
        }
    }

    IpcHandler {
        target: "focus"

        // Focus Mode settings window (not while a session runs).
        function settings(): void {
            root.settingsOpen = true;
        }
        // A session with the active profile; stop puts everything back.
        function start(): void {
            root.start();
        }
        function stop(): void {
            root.stop();
        }
        function status(): string {
            return root.active ? `active\t${root.sessionProfile.name}\t${Math.round((Date.now() - root.startedAt) / 1000)}s` : "inactive";
        }
        // A tab of it: timer, wallpaper, lists, profiles, todo, exit
        function openTab(tab: string): void {
            root.settingsTab = tab;
            settings();
        }
        function closeSettings(): void {
            root.settingsOpen = false;
        }
        // study, work or a profile id
        function profile(id: string): void {
            root.select(id);
        }
        // A blank profile of your own (icon: a Material Symbols name, empty for the default)
        function addProfile(name: string, icon: string): string {
            return root.add(name, icon, false);
        }
        function current(): string {
            return `${root.activeId}\t${root.profile.name}`;
        }
    }
}
