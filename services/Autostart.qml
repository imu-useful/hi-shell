pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// The commands Hyprland runs when it starts, for Settings > Autostart: everything that's a plain
// `hl.exec_cmd("...")` line in the Hyprland config (any .lua file under ~/.config/hypr) and in
// hi-shell's own exec.lua, where new ones go. services/execs.py finds them and rewrites the lines;
// this keeps the list and runs the changes.
Singleton {
    id: root

    readonly property string hyprDir: `${Quickshell.env("XDG_CONFIG_HOME") || Paths.home + "/.config"}/hypr`
    readonly property string execFile: `${Config.dir}/exec.lua`

    // [{ file, rel, line, orig, cmd, enabled, kind: "start" | "reload", own, readonly, why }]
    property var entries: []
    // More found than listed (the scan stops at a limit in a huge config).
    property int total: 0
    // The Hyprland folder exists, and hi-shell's part of its config is loaded from it (else the
    // commands added here never run).
    property bool exists: true
    property bool loaded: true
    property string error: ""

    readonly property string script: `${Quickshell.shellDir}/services/execs.py`

    function refresh() {
        scan.running = true;
    }

    // Values go as --name=value: a commented-out line starts with dashes, which a separate
    // argument would be taken for an option.
    function add(cmd) {
        run(["add", `--exec=${execFile}`, `--cmd=${cmd}`]);
    }

    function edit(entry, cmd) {
        run(["edit", `--file=${entry.file}`, `--line=${entry.line}`, `--orig=${entry.orig}`, `--cmd=${cmd}`]);
    }

    function setEnabled(entry, on) {
        run(["toggle", `--file=${entry.file}`, `--line=${entry.line}`, `--orig=${entry.orig}`, `--on=${on ? 1 : 0}`]);
    }

    function remove(entry) {
        run(["delete", `--file=${entry.file}`, `--line=${entry.line}`, `--orig=${entry.orig}`]);
    }

    // Changes go one at a time (two writing the same file would trip over each other), each
    // followed by the list again: lines may have moved, or the change failed.
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
            // The generated hyprland.lua loads exec.lua; make sure it says so.
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
                        // Not what the script prints: it crashed, or python3 isn't there.
                        console.warn("Autostart: unexpected answer", text);
                        root.error = Translation.tr("Couldn't change it (see the shell's log)");
                    }
                }
            }
        }
    }

    Process {
        id: scan
        command: ["python3", root.script, "scan", `--hypr=${root.hyprDir}`, `--exec=${root.execFile}`, `--shell-hypr=${Quickshell.shellDir}/hypr`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    root.entries = r.entries;
                    root.total = r.total;
                    root.exists = r.exists;
                    root.loaded = r.loaded;
                } catch (e) {
                    console.warn("Autostart: couldn't read the list", e);
                }
            }
        }
    }
}
