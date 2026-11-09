pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Presets: the config, wallpaper and color scheme in one archive
// (services/presets.py), kept in ~/.local/share/hi-shell/presets.
// Exports leave out API keys, location and the monitor layout. A *profile* also carries your rules, script widgets,
// QML widgets and keybinds; an import never brings those unless it is told to trust the file. Before an import
// the files it may overwrite are copied to a backup folder (`undo` puts the last one back).
Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("XDG_DATA_HOME") || Paths.home + "/.local/share"}/hi-shell/presets`
    readonly property string script: Quickshell.shellDir + "/services/presets.py"
    // [{ path, name, created, wallpaper }], newest first
    property var list: []
    property bool busy: exporter.running || importer.running
    property string error: ""

    function refresh(): void {
        lister.running = true;
    }

    readonly property string backupDir: `${Paths.state}/preset-backups`
    // The files a profile carries, and where they live.
    readonly property var profileArgs: ["--widgets-dir", UserWidgets.dir, "--binds", Keybinds.bindsFile]
    // What `diff` printed for `diffPath`.
    property string diffText: ""
    property string diffPath: ""

    function exportPreset(name: string, profile: bool): void {
        const safe = (name.trim() || new Date().toISOString().slice(0, 16).replace("T", " ")).replace(/[\/\\]/g, "-").trim();
        error = "";
        exporter.command = ["python3", script, "export", `${dir}/${safe}.tar.gz`, "--config", Config.path,
            "--colors", Colors.path, "--wallpaper", Wallpapers.current, ...(profile ? ["--profile", ...profileArgs] : [])];
        exporter.running = true;
    }

    // `only`: parts to apply ("bar,dock,colors"), empty = all. `trust`: also bring the rules, script widgets, widget
    // files and keybinds of a profile.
    function importPreset(path: string, trust: bool, only: string): void {
        error = "";
        importer.command = ["python3", script, "import", path.replace(/^~/, Paths.home), "--config", Config.path,
            "--wallpapers", `${Paths.home}/Pictures/Wallpapers/presets`, "--backup-dir", backupDir, ...profileArgs,
            ...(trust ? ["--trust"] : []), ...(only ? ["--only", only] : []),
            "--search", ...Config.options.wallpapers.directories, Config.options.wallpapers.downloadDirectory];
        importer.running = true;
    }

    // What an import of `path` would change (diffText when it is done).
    function previewPreset(path: string, trust: bool, only: string): void {
        diffPath = path;
        diffText = "";
        differ.command = ["python3", script, "diff", path.replace(/^~/, Paths.home), "--config", Config.path, ...profileArgs,
            ...(trust ? ["--trust"] : []), ...(only ? ["--only", only] : [])];
        differ.running = true;
    }

    // Put back the config (and keybinds, widget files) from before the last import.
    function undo(): void {
        error = "";
        undoer.command = ["python3", script, "undo", "--config", Config.path, "--backup-dir", backupDir, ...profileArgs];
        undoer.running = true;
    }

    function remove(path: string): void {
        Quickshell.execDetached(["rm", "-f", "--", path]);
        list = list.filter(p => p.path !== path);
    }

    Process {
        id: lister
        command: ["python3", root.script, "list", root.dir]
        stdout: StdioCollector {
            onStreamFinished: root.list = text.split("\n").filter(l => l).map(l => JSON.parse(l))
        }
    }

    Process {
        id: differ
        stdout: StdioCollector {
            onStreamFinished: root.diffText = text.trim()
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.diffText = text.trim()
        }
    }

    Process {
        id: undoer
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.error = text.trim().split("\n").pop()
        }
        onExited: code => {
            if (code === 0)
                Quickshell.execDetached(["notify-send", "-a", "hi-shell", "-i", "edit-undo", Translation.tr("Preset undone"), Translation.tr("The setup from before the last preset is back")]);
        }
    }

    Process {
        id: exporter
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.error = text.trim().split("\n").pop()
        }
        onExited: code => {
            if (code === 0)
                Quickshell.execDetached(["notify-send", "-a", "hi-shell", "-i", "document-save", Translation.tr("Preset saved"), command[3].replace(Paths.home, "~")]);
            root.refresh();
        }
    }

    Process {
        id: importer
        property var result: ({})
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    importer.result = JSON.parse(text);
                } catch (e) {
                    importer.result = {};
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.error = text.trim().split("\n").pop()
        }
        onExited: code => {
            if (code !== 0)
                return;
            if (result.wallpaper)
                Wallpapers.set(result.wallpaper);
            if (result.mode === "dark" || result.mode === "light")
                Theme.setMode(result.mode);
            // Config reloads from the file watcher; apply its Hyprland part after that.
            applyLater.restart();
        }
    }

    Timer {
        id: applyLater
        interval: 700
        onTriggered: HyprlandSettings.applyOverrides()
    }

    IpcHandler {
        target: "presets"

        // Name without extension; empty = date and time.
        function save(name: string): void {
            root.exportPreset(name, false);
        }
        // A profile also carries rules, script widgets, QML widgets and keybinds.
        function saveProfile(name: string): void {
            root.exportPreset(name, true);
        }
        function load(path: string): void {
            root.importPreset(path, false, "");
        }
        // parts: "bar,dock,colors" or "" for all; trust: also the code a profile carries
        function loadWith(path: string, parts: string, trust: bool): void {
            root.importPreset(path, trust, parts.trim());
        }
        function undo(): void {
            root.undo();
        }
        function list(): string {
            return root.list.map(p => p.path).join("\n");
        }
    }

    Component.onCompleted: refresh()
}
