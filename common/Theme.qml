pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Keeps the Material 3 palette in sync with the wallpaper by running
// services/theme_updater.py at startup, when the wallpaper changes, and when
// the dark/light mode is toggled. Colors.qml picks up the result live.
Singleton {
    id: root

    // illogical-impulse records the current wallpaper here on every change.
    // Hyprland has no wallpaper event, so this file is the change signal.
    readonly property string wallpaperFile: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/quickshell/user/generated/wallpaper/path.txt`

    readonly property bool busy: updater.running
    property var pendingArgs: null

    function update(extraArgs) {
        const args = extraArgs ?? [];
        if (updater.running) {
            pendingArgs = args;
            return;
        }
        updater.command = ["python3", Quickshell.shellDir + "/services/theme_updater.py", "--output", Colors.path, ...args];
        updater.running = true;
    }

    function setMode(mode) {
        update(["--mode", mode]);
    }

    function toggleMode() {
        setMode(Colors.dark ? "light" : "dark");
    }

    Process {
        id: updater
        stderr: SplitParser {
            onRead: line => console.info(line)
        }
        onExited: {
            // The file watcher misses a palette file that didn't exist yet, so reload explicitly.
            Colors.reload();
            if (root.pendingArgs !== null) {
                const args = root.pendingArgs;
                root.pendingArgs = null;
                root.update(args);
            }
        }
    }

    FileView {
        path: root.wallpaperFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.update()
    }

    // Also run once at startup (covers setups without the illogical-impulse file).
    Component.onCompleted: update()

    IpcHandler {
        target: "theme"

        function update(): void {
            root.update(["--force"]);
        }
        function setMode(mode: string): void {
            root.setMode(mode);
        }
        function toggleMode(): void {
            root.toggleMode();
        }
        function setWallpaper(path: string): void {
            root.update(["--wallpaper", path]);
        }
    }
}
