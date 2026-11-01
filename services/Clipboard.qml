pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Clipboard history via cliphist. Starts the `wl-paste --watch cliphist store`
// watchers (text and images) unless some are already running.
// Pinned entries are kept apart from cliphist: a copy of each one's data in the state folder,
// so clearing the history leaves them alone.
Singleton {
    id: root

    // [{ id, line, text, image: bool }]; `line` is cliphist's raw "id<TAB>preview".
    property var entries: []
    readonly property string thumbDir: Paths.cache + "/clipboard"
    readonly property string pinDir: Paths.state + "/clipboard-pins"

    // [{ id, line, label, kind: "text" | "image", mime, file }]: `id` is the cliphist id it was pinned from.
    property var pins: []
    // The pinned ones in the shape of `entries`, and the history without them.
    readonly property var pinnedEntries: pins.map(p => ({ id: p.id, line: p.line, text: p.label, image: p.kind === "image", pinned: true, file: p.file, mime: p.mime }))
    readonly property var history: entries.filter(e => !isPinned(e.id))

    function isPinned(id) {
        return pins.some(p => p.id === id);
    }

    function togglePin(entry) {
        if (isPinned(entry.id))
            unpin(entry.id);
        else
            pin(entry);
    }

    function pin(entry) {
        const image = /binary data .* (png|jpe?g|webp|gif|bmp) /.exec(entry.text);
        const ext = image ? image[1].replace("jpeg", "jpg") : "txt";
        const record = { id: entry.id, line: entry.line, label: entry.text, kind: image ? "image" : "text", mime: image ? `image/${image[1].replace("jpg", "jpeg")}` : "text/plain", file: `${pinDir}/${entry.id}.${ext}` };
        const proc = thumbComponent.createObject(root, {
            command: ["sh", "-c", 'mkdir -p "$1" && printf "%s" "$2" | cliphist decode > "$3"', "sh", pinDir, entry.line, record.file]
        });
        proc.exited.connect(code => {
            proc.destroy();
            if (code === 0) {
                pins = [...pins.filter(p => p.id !== record.id), record];
                pinStore.setText(JSON.stringify(pins, null, 2));
            }
        });
        proc.running = true;
    }

    function unpin(id) {
        const gone = pins.find(p => p.id === id);
        pins = pins.filter(p => p.id !== id);
        pinStore.setText(JSON.stringify(pins, null, 2));
        if (gone)
            run(['rm -f "$1"', gone.file]);
    }

    FileView {
        id: pinStore
        path: Paths.state + "/clipboard-pins.json"
        printErrors: false
        onLoaded: {
            try {
                root.pins = JSON.parse(text());
            } catch (e) {
                console.warn("Clipboard: invalid pins", e);
            }
        }
    }

    function refresh() {
        lister.running = true;
    }

    function copy(entry) {
        if (entry.pinned)
            run(['wl-copy --type "$2" < "$1"', entry.file, entry.mime]);
        else
            run(['printf "%s" "$1" | cliphist decode | wl-copy', entry.line]);
    }

    // Deleting a pinned entry unpins it as well.
    function remove(entry) {
        if (isPinned(entry.id))
            unpin(entry.id);
        entries = entries.filter(e => e.id !== entry.id);
        run(['printf "%s" "$1" | cliphist delete', entry.line]);
    }

    // Clears the history; pinned entries stay.
    function wipe() {
        entries = [];
        run(["cliphist wipe"]);
    }

    // Decoded image for an image entry (created on first use).
    function thumbnail(entry) {
        return `${thumbDir}/${entry.id}.png`;
    }
    function decodeThumbnail(entry, done) {
        if (entry.pinned) {
            done(`file://${entry.file}`);
            return;
        }
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
