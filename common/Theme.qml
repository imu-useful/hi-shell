pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Keeps the Material 3 palette in sync with the wallpaper, dark / light mode and
// the matugen scheme (Config appearance.scheme) by running services/theme_updater.py.
// Colors.qml picks up the result live. The wallpaper itself comes from the
// Wallpapers service (setWallpaper).
Singleton {
    id: root

    readonly property var options: Config.options.appearance
    readonly property bool busy: updater.running
    property var pendingArgs: null

    readonly property list<string> schemes: ["tonal-spot", "content", "expressive", "fidelity", "fruit-salad", "monochrome", "neutral", "rainbow", "vibrant"]

    function update(extraArgs) {
        const args = extraArgs ?? [];
        if (updater.running) {
            // Keep the latest request; a newer wallpaper / mode replaces an older one.
            pendingArgs = [...(pendingArgs ?? []), ...args];
            return;
        }
        const scheme = schemes.includes(options.scheme) ? options.scheme : "tonal-spot";
        updater.command = ["python3", Quickshell.shellDir + "/services/theme_updater.py", "--output", Colors.path, "--scheme", scheme, ...args];
        updater.running = true;
    }

    function setWallpaper(path) {
        update(["--wallpaper", path]);
    }

    function setMode(mode) {
        update(["--mode", mode]);
    }

    function toggleMode() {
        setMode(Colors.dark ? "light" : "dark");
    }

    Connections {
        target: root.options
        function onSchemeChanged() {
            root.update();
        }
    }

    // GTK apps follow dark / light through the freedesktop color-scheme setting.
    Connections {
        target: Colors
        function onModeChanged() {
            if (root.options.gtkColorScheme)
                Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", Colors.dark ? "prefer-dark" : "default"]);
        }
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
        // tonal-spot, content, expressive, fidelity, fruit-salad, monochrome, neutral, rainbow, vibrant
        function setScheme(scheme: string): void {
            root.options.scheme = scheme;
        }
    }
}
