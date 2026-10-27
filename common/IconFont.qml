pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The icon font, cut down to the icons the shell uses (services/icon_font.py): ~160 KB
// instead of the full 15 MB Material Symbols, which Qt maps once per variant. Loaded
// from the cache at once; the script checks it in the background and rebuilds it when
// the shell's icons or the font change. Without it (no python-fonttools, another icon
// font that isn't installed) the full font is used.
Singleton {
    id: root

    readonly property string family: Config.options.appearance.fonts.icon
    readonly property string dir: `${Paths.cache}/icons`
    property int version: 0

    // "" until the small font is ready.
    readonly property string name: loader.status === FontLoader.Ready && loader.name.startsWith(`${family} hi-shell `) ? loader.name : ""

    FontLoader {
        id: loader
        source: `file://${root.dir}/icons.ttf?v=${root.version}`
    }

    onFamilyChanged: check.running = true

    Process {
        id: check
        running: true
        command: ["python3", Quickshell.shellDir + "/services/icon_font.py", "--family", root.family,
            "--scan", Quickshell.shellDir, "--out", root.dir]
        stdout: StdioCollector {
            // Made just now (the first time, or after the font failed to load).
            onStreamFinished: if (text.trim() && root.name === "") root.version++
        }
        stderr: StdioCollector {
            // Rebuilt: the shell's icons or the font changed.
            onStreamFinished: {
                if (text.includes("icon_font:")) {
                    console.info(text.trim());
                    root.version++;
                }
            }
        }
    }
}
