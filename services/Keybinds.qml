pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// The keybinds of the Hyprland config, for Settings > Keybinds: every `hl.bind("KEYS", ...)` of the
// .lua files under ~/.config/hypr (hi-shell's own included) and of ~/.config/hi-shell/binds.lua, where
// new ones go. services/binds.py finds them and rewrites the lines; this keeps the list and runs the
// changes, one at a time.
Singleton {
    id: root

    readonly property string hyprDir: `${Quickshell.env("XDG_CONFIG_HOME") || Paths.home + "/.config"}/hypr`
    readonly property string bindsFile: `${Config.dir}/binds.lua`

    // [{ file, rel, line, end, orig, keys, cmd (null when the action is code), action, desc, enabled,
    //    own, nested, readonly, why }]
    property var entries: []
    property int total: 0
    property bool exists: true
    property bool loaded: true
    property string error: ""

    readonly property string script: `${Quickshell.shellDir}/services/binds.py`

    function refresh() {
        scan.running = true;
    }

    function add(keys, cmd, desc) {
        run(["add", `--binds=${bindsFile}`, `--value=${keys}`, `--cmd=${cmd}`, `--desc=${desc ?? ""}`]);
    }

    function change(what, entry, value) {
        run([what, `--file=${entry.file}`, `--line=${entry.line}`, `--orig=${entry.orig}`, `--value=${value}`]);
    }

    function setKeys(entry, keys) {
        change("keys", entry, keys);
    }

    function setCommand(entry, cmd) {
        change("cmd", entry, cmd);
    }

    function setDescription(entry, text) {
        change("desc", entry, text);
    }

    function setEnabled(entry, on) {
        run(["toggle", `--file=${entry.file}`, `--line=${entry.line}`, `--orig=${entry.orig}`, `--on=${on ? 1 : 0}`]);
    }

    function remove(entry) {
        run(["delete", `--file=${entry.file}`, `--line=${entry.line}`, `--orig=${entry.orig}`]);
    }

    // One change at a time, each followed by the list again (lines may have moved, or it failed).
    property var queue: []
    property bool working: false

    function run(args) {
        queue = [...queue, args];
        next();
    }

    function next() {
        if (working || queue.length === 0)
            return;
        working = true;
        const args = queue[0];
        queue = queue.slice(1);
        const proc = changeComponent.createObject(root, { command: ["python3", script, ...args] });
        proc.exited.connect(() => {
            proc.destroy();
            // The generated hyprland.lua loads binds.lua; make sure it says so.
            HyprlandSettings.writeLua();
            root.refresh();
            root.working = false;
            root.next();
        });
        proc.running = true;
    }

    Component {
        id: changeComponent
        Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        root.error = JSON.parse(text).error ?? "";
                    } catch (e) {
                        console.warn("Keybinds: unexpected answer", text);
                        root.error = Translation.tr("Couldn't change it (see the shell's log)");
                    }
                }
            }
        }
    }

    Process {
        id: scan
        command: ["python3", root.script, "scan", `--hypr=${root.hyprDir}`, `--binds=${root.bindsFile}`, `--shell-hypr=${Quickshell.shellDir}/hypr`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    root.entries = r.entries;
                    root.total = r.total;
                    root.exists = r.exists;
                    root.loaded = r.loaded;
                } catch (e) {
                    console.warn("Keybinds: couldn't read the list", e);
                }
            }
        }
    }
}
