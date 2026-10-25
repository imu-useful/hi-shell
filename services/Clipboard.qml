pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Clipboard history via cliphist. Starts the `wl-paste --watch cliphist store`
// watchers (text and images) unless some are already running.
Singleton {
    id: root

    // [{ id, line, text, image: bool }]; `line` is cliphist's raw "id<TAB>preview".
    property var entries: []
    readonly property string thumbDir: Paths.cache + "/clipboard"

    function refresh() {
        lister.running = true;
    }

    function copy(entry) {
        run(['printf "%s" "$1" | cliphist decode | wl-copy', entry.line]);
    }

    function remove(entry) {
        entries = entries.filter(e => e.id !== entry.id);
        run(['printf "%s" "$1" | cliphist delete', entry.line]);
    }

    function wipe() {
        entries = [];
        run(["cliphist wipe"]);
    }

    // Decoded image for an image entry (created on first use).
    function thumbnail(entry) {
        return `${thumbDir}/${entry.id}.png`;
    }
    function decodeThumbnail(entry, done) {
        const proc = thumbComponent.createObject(root, {
            command: ["sh", "-c", 'mkdir -p "$2" && [ -s "$2/$3.png" ] || printf "%s" "$1" | cliphist decode > "$2/$3.png"', "sh", entry.line, thumbDir, entry.id]
        });
        proc.exited.connect(() => {
            done(`file://${thumbnail(entry)}`);
            proc.destroy();
        });
        proc.running = true;
    }

    function run(args) {
        const proc = thumbComponent.createObject(root, { command: ["sh", "-c", args[0], "sh", ...args.slice(1)] });
        proc.exited.connect(() => {
            proc.destroy();
            root.refresh();
        });
        proc.running = true;
    }

    Component {
        id: thumbComponent
        Process {}
    }

    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(l => l.includes("\t")).map(line => {
                    const tab = line.indexOf("\t");
                    const preview = line.slice(tab + 1);
                    return { id: line.slice(0, tab), line, text: preview, image: /^\[\[ binary data .* (png|jpe?g|webp|gif|bmp) /.test(preview) };
                });
            }
        }
    }

    // Watchers, unless another tool already runs them.
    property bool external: true
    Process {
        running: Config.options.clipboard.watch
        command: ["pgrep", "-f", "wl-paste .*--watch cliphist store"]
        onExited: code => root.external = code === 0
    }
    Process {
        running: Config.options.clipboard.watch && !root.external
        command: ["wl-paste", "--type", "text", "--watch", "cliphist", "store"]
    }
    Process {
        running: Config.options.clipboard.watch && !root.external
        command: ["wl-paste", "--type", "image", "--watch", "cliphist", "store"]
    }
}
