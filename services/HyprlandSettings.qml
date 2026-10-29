pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Hyprland settings for the settings app. Changes apply at once (hyprctl eval)
// and are kept in Config hyprland.*, from which ~/.config/hi-shell/hyprland.lua
// is generated; hypr/hi-shell/overrides.lua loads that file, so they survive restarts.
Singleton {
    id: root

    readonly property var overrides: Config.options.hyprland
    readonly property string luaFile: `${Config.dir}/hyprland.lua`

    // From `hyprctl monitors all -j`
    property var monitors: []
    // option path ("general.gaps_in") -> current value
    property var values: ({})

    // Options shown in settings: [path, type]
    readonly property var known: [
        ["general.gaps_in", "int"], ["general.gaps_out", "int"], ["general.border_size", "int"],
        ["decoration.rounding", "int"], ["decoration.blur.enabled", "bool"], ["decoration.blur.size", "int"],
        ["decoration.blur.passes", "int"], ["decoration.shadow.enabled", "bool"], ["animations.enabled", "bool"],
        ["input.sensitivity", "float"], ["input.touchpad.natural_scroll", "bool"], ["input.follow_mouse", "int"]
    ]

    function refresh() {
        monitorQuery.running = true;
        optionQuery.running = true;
    }

    // --- Options ---
    function setOption(path, value) {
        if (values[path] === value)
            return;
        const next = Object.assign({}, values);
        next[path] = value;
        values = next;
        const opts = Object.assign({}, overrides.options);
        opts[path] = value;
        overrides.options = opts;
        apply(`hl.config(${lua(nest({ [path]: value }))})`);
        writeLua();
    }

    // --- Monitors ---
    // A new resolution, orientation or scale is tried first: it's applied at once but kept
    // only when confirmed (Keep); otherwise, after `confirmSeconds` or on Revert, the monitor
    // goes back to how it was. Nothing is saved until it's kept.
    readonly property int confirmSeconds: 15
    // The monitor being tried ("" = none), the rule it had before, the rule being tried, seconds left.
    property string pendingName: ""
    property var pendingPrevious: null
    property var pendingRule: null
    property int countdown: 0

    function liveRule(m) {
        return {
            mode: `${m.width}x${m.height}@${m.refreshRate.toFixed(2)}`,
            position: `${m.x}x${m.y}`,
            scale: m.scale,
            transform: m.transform
        };
    }

    function keepPending() {
        if (pendingName === "")
            return;
        const all = Object.assign({}, overrides.monitors);
        all[pendingName] = pendingRule;
        overrides.monitors = all;
        writeLua();
        clearPending();
    }

    function revertPending() {
        if (pendingName === "")
            return;
        apply(`hl.monitor(${lua(Object.assign({ output: pendingName }, pendingPrevious))})`);
        clearPending();
        refreshLater.restart();
    }

    function clearPending() {
        countdownTimer.stop();
        pendingName = "";
        pendingPrevious = null;
        pendingRule = null;
        countdown = 0;
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (--root.countdown <= 0)
                root.revertPending();
        }
    }

    // rule: { mode: "1920x1080@60", position: "0x0", scale: 1, transform: 0 }
    function setMonitor(name, changes) {
        const m = monitors.find(x => x.name === name);
        if (!m)
            return;
        const trying = pendingName === name;
        const current = trying ? pendingRule : (overrides.monitors[name] ?? liveRule(m));
        const rule = Object.assign({}, current, changes);
        if (trying || "mode" in changes || "transform" in changes || "scale" in changes) {
            // Another monitor still waiting for an answer is settled first (kept as it is).
            if (pendingName !== "" && !trying)
                keepPending();
            if (!trying) {
                pendingName = name;
                pendingPrevious = liveRule(m);
            }
            pendingRule = rule;
            if ("mode" in changes || "transform" in changes || "scale" in changes) {
                countdown = confirmSeconds;
                countdownTimer.restart();
            }
            apply(`hl.monitor(${lua(Object.assign({ output: name }, rule))})`);
            refreshLater.restart();
            return;
        }
        const all = Object.assign({}, overrides.monitors);
        all[name] = rule;
        overrides.monitors = all;
        apply(`hl.monitor(${lua(Object.assign({ output: name }, rule))})`);
        writeLua();
        refreshLater.restart();
    }

    function resetAll() {
        clearPending();
        overrides.monitors = {};
        overrides.options = {};
        writeLua();
        Quickshell.execDetached(["hyprctl", "reload"]);
        refreshLater.restart();
    }

    // Re-apply everything in Config hyprland.* (e.g. after a preset import).
    function applyOverrides() {
        if (Object.keys(overrides.options).length)
            apply(`hl.config(${lua(nest(overrides.options))})`);
        writeLua();
        refreshLater.restart();
    }

    function apply(code) {
        Quickshell.execDetached(["hyprctl", "eval", code]);
    }

    // { "a.b.c": 1 } -> { a: { b: { c: 1 } } }
    function nest(flat) {
        const out = {};
        for (const path in flat) {
            const keys = path.split(".");
            let o = out;
            keys.slice(0, -1).forEach(k => o = o[k] = o[k] ?? {});
            o[keys[keys.length - 1]] = flat[path];
        }
        return out;
    }

    // The autostart commands (Settings > Autostart): save a new list, and write it into the generated file.
    function setAutostart(list) {
        overrides.autostart = list;
        writeLua();
    }

    // Start a command now, the way Hyprland would at its start.
    function runNow(cmd) {
        if ((cmd ?? "").trim() !== "")
            apply(`hl.exec_cmd(${lua(cmd.trim())})`);
    }

    // JS value -> Lua literal
    function lua(v) {
        if (typeof v === "string")
            return JSON.stringify(v);
        if (typeof v === "number" || typeof v === "boolean")
            return String(v);
        return `{ ${Object.keys(v).map(k => `${k} = ${lua(v[k])}`).join(", ")} }`;
    }

    function writeLua() {
        const lines = ["-- Generated by hi-shell settings; edits here are overwritten.", ""];
        for (const name in overrides.monitors)
            lines.push(`hl.monitor(${lua(Object.assign({ output: name }, overrides.monitors[name]))})`);
        if (Object.keys(overrides.options).length)
            lines.push(`hl.config(${lua(nest(overrides.options))})`);
        // Autostart (Settings > Autostart): like exec-once, once when Hyprland starts.
        const commands = (overrides.autostart ?? []).filter(e => e.enabled && (e.cmd ?? "").trim() !== "");
        if (commands.length) {
            lines.push("hl.on(\"hyprland.start\", function()");
            commands.forEach(e => lines.push(`    hl.exec_cmd(${lua(e.cmd.trim())})`));
            lines.push("end)");
        }
        luaWriter.setText(lines.join("\n") + "\n");
    }

    FileView {
        id: luaWriter
        path: root.luaFile
        printErrors: false
        blockLoading: true
    }

    Timer {
        id: refreshLater
        interval: 800
        onTriggered: root.refresh()
    }

    Process {
        id: monitorQuery
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    // One line per option: path<TAB>json
    Process {
        id: optionQuery
        command: ["sh", "-c", 'for o in "$@"; do printf "%s\\t" "$o"; hyprctl getoption "$(echo "$o" | tr . :)" -j | tr -d "\\n"; echo; done', "sh", ...root.known.map(k => k[0])]
        stdout: StdioCollector {
            onStreamFinished: {
                const next = {};
                for (const line of text.trim().split("\n")) {
                    const [path, json] = line.split("\t");
                    try {
                        const o = JSON.parse(json);
                        const type = root.known.find(k => k[0] === path)?.[1];
                        // gaps come back as css ("4 4 4 4"); take the first value
                        next[path] = type === "bool" ? o.int === 1 || o.bool === true
                                   : o.int ?? o.float ?? (o.css ? Number(o.css.split(" ")[0]) : undefined) ?? o.bool;
                    } catch (e) {}
                }
                root.values = next;
            }
        }
    }
}
