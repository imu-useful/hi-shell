pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Presets: the config, wallpaper and color scheme in one archive
// (services/presets.py), kept in ~/.local/share/hi-shell/presets.
// Exports leave out API keys, location and the monitor layout.
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

    function exportPreset(name: string): void {
        const safe = (name || new Date().toISOString().slice(0, 16).replace("T", " ")).replace(/[\/\\]/g, "-").trim();
        error = "";
        exporter.command = ["python3", script, "export", `${dir}/${safe}.tar.gz`, "--config", Config.path,
            "--colors", Colors.path, "--wallpaper", Wallpapers.current];
        exporter.running = true;
    }

    function importPreset(path: string): void {
        error = "";
        importer.command = ["python3", script, "import", path.replace(/^~/, Paths.home), "--config", Config.path,
            "--wallpapers", `${Paths.home}/Pictures/Wallpapers/presets`,
            "--search", ...Config.options.wallpapers.directories, Config.options.wallpapers.downloadDirectory];
        importer.running = true;
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
            root.exportPreset(name);
        }
        function load(path: string): void {
            root.importPreset(path);
        }
        function list(): string {
            return root.list.map(p => p.path).join("\n");
        }
    }

    Component.onCompleted: refresh()
}
