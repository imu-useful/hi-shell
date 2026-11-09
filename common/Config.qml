pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "ConfigSchema.js" as Schema

// User configuration in ~/.config/hi-shell/config.json.
// Missing keys fall back to the defaults below; edits to the file apply live,
// and changes made from the UI (assigning to Config.options.*) are written back.
Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/hi-shell`
    readonly property string path: `${dir}/config.json`

    readonly property alias options: adapter
    readonly property bool ready: file.loaded
    property bool filledIn: false

    // Options reset to their defaults on the last check, as [{ path, value, reason, def }]
    // (a hand edit that broke a rule in common/ConfigSchema.js).
    property var lastProblems: []

    function getPath(path) {
        let o = adapter;
        for (const k of path.split(".")) {
            if (o === undefined || o === null)
                return undefined;
            o = o[k];
        }
        return o;
    }

    function setPath(path, value) {
        const parts = path.split(".");
        let o = adapter;
        for (const k of parts.slice(0, -1))
            o = o[k];
        o[parts[parts.length - 1]] = value;
    }

    // The same options with nothing read from the file: their values are the defaults.
    ConfigOptions {
        id: pristine
    }

    // Copy the defaults of `path` (a section such as "bar" or "bar.clock", or one option; empty = everything)
    // over the live values. Lists and maps are copied, not shared.
    function reset(path) {
        const parts = path ? path.split(".") : [];
        let live = adapter, def = pristine;
        for (const k of parts.slice(0, -1)) {
            live = live[k];
            def = def[k];
        }
        if (parts.length === 0) {
            copyDefaults(live, def);
            return true;
        }
        const last = parts[parts.length - 1];
        if (live === undefined || live[last] === undefined) {
            console.warn("Config: no such option or section:", path);
            return false;
        }
        if (isSection(def[last])) {
            copyDefaults(live[last], def[last]);
        } else {
            live[last] = JSON.parse(JSON.stringify(def[last]));
        }
        return true;
    }

    function isSection(v) {
        return v !== null && typeof v === "object" && !Array.isArray(v) && v.toString().indexOf("JsonObject") !== -1;
    }

    function copyDefaults(live, def) {
        for (const k in def) {
            const v = def[k];
            if (typeof v === "function" || k === "objectName" || k.endsWith("Changed") || k.startsWith("on") && k.length > 2 && k[2] === k[2].toUpperCase())
                continue;
            if (isSection(v))
                copyDefaults(live[k], v);
            else
                live[k] = Array.isArray(v) || (v && typeof v === "object") ? JSON.parse(JSON.stringify(v)) : v;
        }
    }

    // Put every option that breaks its rule back to its default and say so; the shell keeps running
    // with a sane value instead of a typo (bar.position: "lefft") breaking a panel.
    function validate() {
        const bad = Schema.check(getPath);
        for (const b of bad) {
            console.warn(`Config: ${b.path} = ${JSON.stringify(b.value)} ${b.reason}; using ${JSON.stringify(b.def)}`);
            setPath(b.path, b.def);
        }
        lastProblems = bad;
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: {
            validate();
            writeTimer.restart();
        }
        // Write back once per start so options added in newer versions show up in the file.
        onLoaded: {
            validate();
            if (!root.filledIn) {
                root.filledIn = true;
                writeTimer.restart();
            }
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                mkdir.running = true;
            } else {
                console.warn("Config: failed to load", root.path, FileViewError.toString(error));
            }
        }

        ConfigOptions {
            id: adapter
        }
    }

    // qs -c hi-shell ipc call config get bar.height   (hi-shell config get bar.height)
    IpcHandler {
        target: "config"

        function get(path: string): string {
            const v = path ? root.getPath(path) : undefined;
            if (path && v === undefined)
                return "No such option: " + path;
            if (!path)
                return "Give an option or a section, e.g. bar.height";
            return root.isSection(v) ? root.dump(path) : JSON.stringify(v);
        }

        // The value is JSON: 40, true, "top", ["a", "b"]; a bare word is taken as a string.
        function set(path: string, value: string): string {
            if (root.getPath(path) === undefined)
                return "No such option: " + path;
            if (root.isSection(root.getPath(path)))
                return path + " is a section; set one of its options";
            let v;
            try {
                v = JSON.parse(value);
            } catch (e) {
                v = value;
            }
            const before = root.getPath(path);
            root.setPath(path, v);
            root.validate();
            const now = root.getPath(path);
            return JSON.stringify(before) + " -> " + JSON.stringify(now) + (root.lastProblems.length ? " (" + root.lastProblems[0].reason + ", default used)" : "");
        }

        function reset(path: string): string {
            return root.reset(path) ? "Reset " + (path || "everything") + " to the defaults" : "No such option or section: " + path;
        }

        function path(): string {
            return root.path;
        }
    }

    function dump(path) {
        const out = {};
        const def = getPath(path);
        for (const k in def) {
            const v = def[k];
            if (typeof v === "function" || k === "objectName" || k.endsWith("Changed") || k.startsWith("on") && k.length > 2 && k[2] === k[2].toUpperCase())
                continue;
            out[k] = isSection(v) ? JSON.parse(dump(path + "." + k)) : v;
        }
        return JSON.stringify(out, null, 2);
    }

    // Coalesce bursts of changes (e.g. a slider drag) into one write.
    Timer {
        id: writeTimer
        interval: 300
        onTriggered: file.writeAdapter()
    }

    // First run: create the config directory, then write the defaults.
    Process {
        id: mkdir
        command: ["mkdir", "-p", root.dir]
        onExited: file.writeAdapter()
    }
}
