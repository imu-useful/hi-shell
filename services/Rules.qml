pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.common
import qs.common.widgets
import "../common/RulesEngine.js" as Engine

// Config rules: "when this is true, do that" (see common/RulesEngine.js for the format). The facts the conditions look
// at are gathered here; a rule whose condition turns true runs its `then` actions, and when it turns false the config
// values it set go back (if nobody changed them meanwhile) and its `else` actions run. Which rules are on is kept in
// ~/.local/state/hi-shell/rules.json, so a restart in the middle of a rule still puts things back later.
Singleton {
    id: root

    readonly property string statePath: `${Paths.state}/rules.json`

    // The rules from the config as plain objects (the adapter hands out array-likes), those that are well formed and
    // those that aren't ([{ id, error }]).
    readonly property var parsed: {
        const raw = JSON.parse(JSON.stringify(Config.options.rules ?? []));
        const good = [], bad = [];
        const seen = {};
        for (const r of raw) {
            const error = Engine.validateRule(r) || (seen[r.id] ? "the id is used twice" : "");
            if (error)
                bad.push({ id: r?.id ?? "?", error });
            else
                good.push(r);
            if (r?.id)
                seen[r.id] = true;
        }
        return { good, bad };
    }
    readonly property var rules: parsed.good
    readonly property var invalid: parsed.bad

    // id -> { active, prev: { path: value before }, applied: { path: value set } }
    property var state: ({})
    property bool loaded: false
    readonly property var activeIds: Object.keys(state).filter(id => state[id].active)

    // --- Facts ---
    property int minutes: 0
    property int weekday: 0
    property var commandResults: ({})
    readonly property var commandList: {
        const out = [];
        for (const r of rules)
            Engine.commands(r.when, out);
        return out;
    }
    readonly property var facts: ({
        battery: { available: Battery.available, percent: Battery.percent, charging: Battery.charging, full: Battery.full, onBattery: Battery.onBattery },
        fullscreen: Fullscreen.screens.length > 0,
        screens: Quickshell.screens.map(s => s.name),
        time: minutes,
        weekday: weekday,
        app: Hyprland.activeToplevel?.lastIpcObject?.class ?? "",
        apps: Hyprland.toplevels.values.map(t => t.lastIpcObject?.class ?? "").filter(c => c !== ""),
        workspace: Hyprland.focusedWorkspace?.id ?? 0,
        dark: Colors.dark,
        playing: Mpris.playing,
        commands: commandResults
    })

    function tick() {
        const d = new Date();
        minutes = d.getHours() * 60 + d.getMinutes();
        weekday = d.getDay();
    }

    // --- Running ---
    function ipcCall(text) {
        Quickshell.execDetached(["qs", "-c", "hi-shell", "ipc", "call", ...text.trim().split(/\s+/)]);
    }

    function runActions(list) {
        for (const a of list ?? []) {
            if (a.ipc !== undefined)
                ipcCall(a.ipc);
            else if (a.run !== undefined)
                Quickshell.execDetached(["sh", "-c", a.run]);
            else if (a.notify !== undefined)
                Quickshell.execDetached(["notify-send", "-a", "hi-shell", "-i", "preferences-system", a.notify]);
        }
    }

    function sameValue(a, b) {
        return JSON.stringify(a) === JSON.stringify(b);
    }

    function activate(rule) {
        const prev = {}, applied = {};
        for (const a of rule.then) {
            if (a.set === undefined)
                continue;
            const before = Config.getPath(a.set);
            if (before === undefined) {
                console.warn(`Rules: ${rule.id}: no such option ${a.set}`);
                continue;
            }
            if (!(a.set in prev))
                prev[a.set] = JSON.parse(JSON.stringify(before));
            Config.setPath(a.set, a.value);
            // What the option holds now (the schema may have refused the value).
            applied[a.set] = JSON.parse(JSON.stringify(Config.getPath(a.set)));
        }
        Config.validate();
        runActions(rule.then);
        setState(rule.id, { active: true, prev: withoutKept(rule, prev), applied });
        console.info(`Rules: ${rule.id} on`);
    }

    // `keep: true` actions are not put back.
    function withoutKept(rule, prev) {
        const out = Object.assign({}, prev);
        for (const a of rule.then) {
            if (a.set !== undefined && a.keep === true)
                delete out[a.set];
        }
        return out;
    }

    function deactivate(id, rule) {
        const st = state[id];
        for (const path of Object.keys(st?.prev ?? {})) {
            // Only if the option still holds what the rule set: someone changed it since, so leave it.
            if (sameValue(Config.getPath(path), st.applied?.[path]))
                Config.setPath(path, st.prev[path]);
        }
        if (rule)
            runActions(rule.else);
        setState(id, { active: false });
        console.info(`Rules: ${id} off`);
    }

    function setState(id, value) {
        const next = Object.assign({}, state);
        if (value.active)
            next[id] = value;
        else
            delete next[id];
        state = next;
        save();
    }

    function evaluateAll() {
        if (!loaded || !Config.ready)
            return;
        const on = Config.options.rulesEnabled !== false;
        const byId = {};
        for (const r of rules)
            byId[r.id] = r;
        for (const r of rules) {
            const wanted = on && r.enabled !== false && Engine.evaluate(r.when, facts);
            const was = state[r.id]?.active === true;
            if (wanted && !was)
                activate(r);
            else if (!wanted && was)
                deactivate(r.id, r);
        }
        // A rule that was removed or is invalid now: put its values back.
        for (const id of Object.keys(state)) {
            if (!byId[id])
                deactivate(id, null);
        }
    }

    // Facts change in bursts (a window opens: app, apps, fullscreen), so evaluate once they settle.
    Timer {
        id: settle
        interval: 400
        onTriggered: root.evaluateAll()
    }
    onFactsChanged: settle.restart()
    onRulesChanged: settle.restart()
    Connections {
        target: Config
        function onReadyChanged() {
            settle.restart();
        }
    }

    Timer {
        interval: 30000
        running: root.rules.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.tick()
    }

    // Conditions that run a command: checked every 30 s, true when it exits with 0.
    Instantiator {
        model: root.commandList

        delegate: Poll {
            required property string modelData
            command: `${modelData} >/dev/null 2>&1`
            interval: 30
            onExitCodeChanged: root.setCommand(modelData, exitCode === 0)
            onRanChanged: if (ran) root.setCommand(modelData, exitCode === 0)
        }
    }
    function setCommand(command, ok) {
        if (commandResults[command] === ok)
            return;
        const next = Object.assign({}, commandResults);
        next[command] = ok;
        commandResults = next;
    }

    // --- Saved state ---
    FileView {
        id: file
        path: root.statePath
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                root.state = JSON.parse(text());
            } catch (e) {
                console.warn("Rules: bad state file", root.statePath);
            }
            root.loaded = true;
            settle.restart();
        }
        onLoadFailed: {
            root.loaded = true;
            settle.restart();
        }
    }
    function save() {
        file.setText(JSON.stringify(state, null, 2));
    }

    // --- IPC: hi rules ... ---
    function find(id) {
        return Array.from(Config.options.rules ?? []).findIndex(r => r?.id === id);
    }
    function plainRules() {
        return JSON.parse(JSON.stringify(Config.options.rules ?? []));
    }
    function putRule(rule) {
        const error = Engine.validateRule(rule);
        if (error)
            return error;
        const list = plainRules().filter(r => r?.id !== rule.id);
        list.push(rule);
        Config.setPath("rules", list);
        Config.flush();
        return "";
    }

    function setEnabled(id, on) {
        const list = plainRules();
        const r = list.find(x => x?.id === id);
        if (!r)
            return;
        r.enabled = on;
        Config.setPath("rules", list);
    }
    function removeRule(id) {
        Config.setPath("rules", plainRules().filter(r => r?.id !== id));
    }

    IpcHandler {
        target: "rules"

        // One line per rule: id, on / off, active now, name; then the rules that don't parse
        function list(): string {
            const lines = root.plainRules().map(r => {
                const bad = root.invalid.find(b => b.id === r.id);
                return `${r.id}\t${bad ? "INVALID" : r.enabled === false ? "off" : "on"}\t${root.activeIds.includes(r.id) ? "active" : "-"}\t${r.name ?? Engine.describe(r.when)}${bad ? "\t" + bad.error : ""}`;
            });
            return lines.join("\n");
        }
        function get(id: string): string {
            const r = root.plainRules().find(x => x?.id === id);
            return r ? JSON.stringify(r, null, 2) : "No such rule: " + id;
        }
        function put(json: string): string {
            let rule;
            try {
                rule = JSON.parse(json.trim());
            } catch (e) {
                return "Not JSON: " + e.message;
            }
            return root.putRule(rule) || "Saved " + rule.id;
        }
        function remove(id: string): string {
            if (root.find(id) < 0)
                return "No such rule: " + id;
            Config.setPath("rules", root.plainRules().filter(r => r?.id !== id));
            Config.flush();
            return "Removed " + id;
        }
        function enable(id: string, on: bool): string {
            const list = root.plainRules();
            const r = list.find(x => x?.id === id);
            if (!r)
                return "No such rule: " + id;
            r.enabled = on;
            Config.setPath("rules", list);
            Config.flush();
            return `${id} is ${on ? "on" : "off"}`;
        }
        function templates(): string {
            return Object.keys(Engine.templates).map(k => `${k}\t${Engine.templates[k].name}`).join("\n");
        }
        function addTemplate(name: string): string {
            const t = Engine.templates[name];
            if (!t)
                return "No such template: " + name;
            const rule = Object.assign({ id: name }, JSON.parse(JSON.stringify(t)));
            return root.putRule(rule) || "Added " + name;
        }
        function facts(): string {
            return JSON.stringify(root.facts, null, 2);
        }
        function check(): string {
            return root.invalid.map(b => `${b.id}: ${b.error}`).join("\n");
        }
    }

    Component.onCompleted: tick()
}
