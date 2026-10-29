pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The icon font, cut down to the icons the shell uses (services/icon_font.py): ~180 KB
// instead of the full 15 MB Material Symbols, which Qt maps once per variant. run.sh makes
// it before the shell starts, and it's loaded once, from the cache. Without it (no
// python-fonttools, another icon font that isn't installed) the full font is used.
//
// It's never swapped while the shell runs, not even for the full font: Qt keeps the glyph
// numbers of the font the texts were drawn with, so a different one shows other icons (the
// buttons' icons shuffled). If the icons or the font change meanwhile (an edit that adds an
// icon), the script rebuilds it in the background and the new one is used from the next start;
// the new icons are missing until then.
Singleton {
    id: root

    readonly property string family: Config.options.appearance.fonts.icon
    readonly property string dir: `${Paths.cache}/icons`

    // "" until the small font is ready, and when it can't be loaded.
    readonly property string name: loader.status === FontLoader.Ready && loader.name.startsWith(`${family} hi-shell `) ? loader.name : ""

    FontLoader {
        id: loader
        source: `file://${root.dir}/icons.ttf`
    }

    // For a start without run.sh, or after the shell's icons changed.
    Process {
        running: true
        command: ["python3", Quickshell.shellDir + "/services/icon_font.py", "--family", root.family,
            "--scan", Quickshell.shellDir, "--out", root.dir]
        stderr: StdioCollector {
            onStreamFinished: if (text.includes("icon_font:")) console.info(text.trim() + " (used from the next start)")
        }
    }
}
