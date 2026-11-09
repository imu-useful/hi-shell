pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Bar widgets you write yourself: every ~/.config/hi-shell/widgets/<name>.qml is a widget type called <name>, to be
// used in a bar list like the built-in ones ("<name>" or "<name>#copy"). A file that changed is loaded again (the folder is
// checked every two seconds), so the bar shows an edit as soon as it is saved. A file that fails to load is reported
// once (a notification) and listed with its error in Settings > Bar and `hi widgets`.
Singleton {
    id: root

    readonly property string dir: `${Config.dir}/widgets`
    // The type names the bar knows itself; a file with one of these names is ignored.
    readonly property var reserved: ["launcher", "workspaces", "activeWindow", "media", "resources", "clock", "weather", "tray", "systemIcons", "utilButtons", "networkSpeed", "battery", "updates", "keyboardLayout", "power", "notifications", "visualizer", "divider", "focus", "zoneClock", "script"]

    // name -> { name, file, component | null, error: "" }
    property var widgets: ({})
    readonly property var names: Object.keys(widgets).sort()
    readonly property int failed: names.filter(n => widgets[n].error !== "").length

    function component(name) {
        return widgets[name]?.component ?? null;
    }

    function load(rows) {
        const next = {};
        for (const r of rows) {
            const name = r.file.replace(/\.qml$/, "");
            if (!/^[A-Za-z][A-Za-z0-9_]*$/.test(name)) {
                next[name] = { name, file: r.file, component: null, error: "The name must be letters, digits and _, starting with a letter" };
                continue;
            }
            if (reserved.includes(name)) {
                next[name] = { name, file: r.file, component: null, error: "The name is a built-in widget's; rename the file" };
                continue;
            }
            // The modification time in the URL: the engine caches a file by its URL, so an edit needs a new one.
            const comp = Qt.createComponent(`file://${dir}/${r.file}?v=${r.modified}`, Component.PreferSynchronous);
            const error = comp.status === Component.Ready ? "" : comp.errorString().trim().replace(/file:\/\/[^\s]*\/([^\/\s?]+)\?v=\d+/g, "$1") || "Not loaded";
            const before = widgets[name];
            // A file that broke keeps showing its last working version until it is fixed.
            next[name] = { name, file: r.file, component: error ? (before?.component ?? null) : comp, error };
            if (error && before?.error !== error) {
                console.warn(`UserWidgets: ${r.file}: ${error}`);
                Quickshell.execDetached(["notify-send", "-a", "hi-shell", "-u", "normal", "-i", "dialog-warning", Translation.tr("Widget %1 didn't load").arg(name), error.split("\n")[0]]);
            }
        }
        widgets = next;
    }

    // Load every file again now (the watcher restarts and prints the folder afresh).
    function reload() {
        watcher.running = false;
        watcher.running = true;
    }

    function openFolder() {
        Quickshell.execDetached(["sh", "-c", `mkdir -p '${dir}' && xdg-open '${dir}'`]);
    }

    // One long-running shell that looks at the folder every two seconds and prints the file names and modification
    // times when they differ from the last time ("name mtime" lines, then "---").
    Process {
        id: watcher
        running: Config.ready
        command: ["sh", "-c", 'mkdir -p "$1"; prev=x; while :; do cur=$(for f in "$1"/*.qml; do [ -f "$f" ] && echo "$(basename "$f") $(stat -c %Y "$f")"; done); if [ "$cur" != "$prev" ]; then printf "%s\\n---\\n" "$cur"; prev=$cur; fi; sleep 2; done', "sh", root.dir]
        stdout: SplitParser {
            splitMarker: "---\n"
            onRead: block => {
                const rows = block.split("\n").filter(l => l.trim() !== "").map(l => {
                    const sp = l.lastIndexOf(" ");
                    return { file: l.slice(0, sp), modified: Number(l.slice(sp + 1)) };
                });
                root.load(rows);
            }
        }
    }

    IpcHandler {
        target: "widgets"

        // "name ok" or "name error: ..." per line
        function list(): string {
            return root.names.map(n => root.widgets[n].error ? `${n} ERROR ${root.widgets[n].error.split("\n")[0]}` : `${n} ok`).join("\n");
        }
        function reload(): string {
            root.reload();
            return root.names.length + " widgets, " + root.failed + " with errors";
        }
        function path(): string {
            return root.dir;
        }
    }
}
