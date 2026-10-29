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

    // [{ file, rel, line, orig, cmd, enabled, kind: "start" | "reload", own, readonly }]
    property var entries: []
    property string error: ""

    readonly property string script: `${Quickshell.shellDir}/services/execs.py`

    function refresh() {
        scan.running = true;
    }

    function add(cmd) {
        run(["add", "--exec", execFile, "--cmd", cmd]);
    }

    function edit(entry, cmd) {
        run(["edit", "--file", entry.file, "--line", String(entry.line), "--orig", entry.orig, "--cmd", cmd]);
    }

    function setEnabled(entry, on) {
        run(["toggle", "--file", entry.file, "--line", String(entry.line), "--orig", entry.orig, "--on", on ? "1" : "0"]);
    }

    function remove(entry) {
        run(["delete", "--file", entry.file, "--line", String(entry.line), "--orig", entry.orig]);
    }

    // A change, then the list again (it may have moved lines, or failed).
    function run(args) {
        const proc = changeComponent.createObject(root, { command: ["python3", script, ...args] });
        proc.exited.connect(() => {
            proc.destroy();
            // The generated hyprland.lua loads exec.lua; make sure it says so.
            HyprlandSettings.writeLua();
            root.refresh();
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
                        root.error = text.trim() ? text.trim() : "";
                    }
                }
            }
        }
    }

    Process {
        id: scan
        command: ["python3", root.script, "scan", "--hypr", root.hyprDir, "--exec", root.execFile]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.entries = JSON.parse(text);
                } catch (e) {
                    console.warn("Autostart: couldn't read the list", e);
                }
            }
        }
    }
}
