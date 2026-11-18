import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// One kind of theme of Settings → Themes and Store (one of these each in Stores): the installed ones
// with a few samples each, and a store to install from: the KDE Store (store.kde.org: Full Icon
// Themes, Cursors, GTK3/4 Themes) or Google Fonts. Applying an icon theme writes KDE's, GTK's and
// qt*ct's; the shell then restarts itself (IconThemeWatcher) so its own icons pick it up. Applying a
// cursor theme writes GTK's, KDE's and gsettings', sets it in Hyprland and keeps it in
// appearance.cursorTheme, which CursorKeeper sets again at every start. A GTK theme goes to GTK's
// settings and gsettings. Fonts aren't applied here: the page sets them as the shell's fonts.
// The work is done by services/icon_themes.py, cursor_themes.py, gtk_themes.py and font_store.py.
Scope {
    id: root

    // icons | cursors | gtk | fonts
    property string kind: "icons"
    readonly property bool cursors: kind === "cursors"
    readonly property string script: `${Quickshell.shellDir}/services/${({ icons: "icon_themes", cursors: "cursor_themes", gtk: "gtk_themes", fonts: "font_store" })[kind]}.py`

    // Installed: [{ id, name, path, removable, samples: [file paths] }]
    property var themes: []
    property string current: ""
    readonly property bool loading: listProc.running

    // The store: the results so far (pages are appended), how many there are in all.
    property var results: []
    property int total: 0
    property int page: 0
    property string query: ""
    property string sort: "popular"
    // Fonts only: a category (sans-serif, serif, monospace, display, handwriting); "" = all.
    property string filter: ""
    readonly property bool searching: searchProc.running
    readonly property bool hasMore: results.length < total

    // The install in progress: its store id, 0..1 (-1 while the size isn't known), and the last error.
    property string installing: ""
    property real fraction: -1
    property string status: ""
    property string error: ""
    // Store id → the theme folders installed from it (state/icon-store.json).
    property var fromStore: ({})

    function refresh() {
        if (!listProc.running)
            listProc.running = true;
        storeFile.reload();
    }

    function search(q, s, f) {
        query = q ?? query;
        sort = s ?? sort;
        filter = f ?? filter;
        results = [];
        total = 0;
        page = 0;
        runSearch();
    }

    function more() {
        if (searching || !hasMore)
            return;
        page += 1;
        runSearch();
    }

    function runSearch() {
        error = "";
        searchProc.running = false;
        searchProc.command = ["python3", "-I", script, "search", "--query", query, "--sort", sort, "--page", String(page)].concat(filter !== "" ? ["--filter", filter] : []);
        searchProc.running = true;
    }

    function install(item, fileIndex) {
        if (installProc.running)
            return;
        installing = item.id;
        fraction = -1;
        status = Translation.tr("Downloading…");
        error = "";
        const args = ["python3", "-I", script, "install", item.id];
        if (fileIndex !== undefined && fileIndex >= 0)
            args.push("--file", String(fileIndex));
        installProc.command = args;
        installProc.running = true;
    }

    function cancelInstall() {
        installProc.running = false;
    }

    function apply(theme) {
        error = "";
        run(cursors ? ["apply", theme, "--size", String(Config.options.appearance.cursorSize)] : ["apply", theme]);
    }

    function remove(theme) {
        error = "";
        run(["remove", theme]);
    }

    // Installed themes from a store entry that are still there: the ones installed from here, and
    // the ones named like one of its variants (put there by hand or a package).
    function installedFrom(id, variants) {
        const names = (fromStore[id] ?? []).concat(variants ?? []);
        return themes.filter(t => names.includes(t.id)).map(t => t.id);
    }

    function parse(text) {
        try {
            return JSON.parse(text.trim().split("\n").pop());
        } catch (e) {
            return { error: Translation.tr("Unexpected answer from %1").arg(script.split("/").pop()) };
        }
    }

    function run(args) {
        runner.createObject(root, { command: ["python3", "-I", script, ...args] }).running = true;
    }

    Component {
        id: runner
        Process {
            id: proc
            stdout: StdioCollector {
                onStreamFinished: {
                    const r = root.parse(text);
                    if (r.error)
                        root.error = r.error;
                    if (r.applied) {
                        root.current = r.applied;
                        if (root.cursors)
                            Config.options.appearance.cursorTheme = r.applied;
                    }
                    root.refresh();
                    proc.destroy();
                }
            }
        }
    }

    Process {
        id: listProc
        command: ["python3", "-I", root.script, "installed"]
        stdout: StdioCollector {
            onStreamFinished: {
                const r = root.parse(text);
                if (r.error) {
                    root.error = r.error;
                    return;
                }
                root.themes = r.themes ?? [];
                root.current = r.current ?? "";
            }
        }
    }

    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "")
                    return;
                const r = root.parse(text);
                if (r.error) {
                    root.error = Translation.tr("Couldn't reach the store: %1").arg(r.error);
                    return;
                }
                root.total = r.total ?? 0;
                root.results = root.results.concat(r.items ?? []);
            }
        }
    }

    Process {
        id: installProc
        stdout: SplitParser {
            onRead: line => {
                let ev;
                try {
                    ev = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (ev.error !== undefined)
                    root.error = ev.error;
                else if (ev.installed !== undefined)
                    root.status = "";
                else if (ev.status === "unpacking")
                    root.status = Translation.tr("Unpacking…");
                else if (ev.progress !== undefined)
                    root.fraction = ev.progress;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && root.error === "")
                root.error = Translation.tr("The download stopped.");
            root.installing = "";
            root.status = "";
            root.refresh();
        }
    }

    FileView {
        id: storeFile
        path: `${Paths.state}/${({ icons: "icon", cursors: "cursor", gtk: "gtk", fonts: "font" })[root.kind]}-store.json`
        printErrors: false
        onLoaded: {
            try {
                root.fromStore = JSON.parse(text());
            } catch (e) {
                root.fromStore = {};
            }
        }
        onLoadFailed: root.fromStore = {}
    }
}
