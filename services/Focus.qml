pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Focus Mode settings: profiles and session tasks in ~/.config/hi-shell/focus_profiles.json
// (see SPEC_FOCUS.md). A profile holds the Pomodoro timer, the wallpaper, the block /
// allow lists and the exit condition; selecting one makes it the active profile, and
// edits go to the active profile. Built-in profiles (Study, Work) can be edited and
// reset; your own ones get a name and an icon of their choice and can be deleted. Tasks are the shell's to-do list
// (services/Todo.qml); this file only keeps which of them are picked for the session.
// The settings window (modules/focus/FocusSettingsWindow.qml) can't be opened while a
// session is running (`active`, driven by the session logic of the later stages).
Singleton {
    id: root

    readonly property string path: `${Config.dir}/focus_profiles.json`

    // Session state (later stages); the settings window stays closed while it's true.
    property bool active: false
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
            if (!root.active)
                root.settingsOpen = true;
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
