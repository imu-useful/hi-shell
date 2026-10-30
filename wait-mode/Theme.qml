pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What Wait Mode borrows from hi-shell (it's a separate process, so it only reads files):
// the palette (~/.local/state/hi-shell/colors.json), the wallpaper (wallpaper.txt) and the
// interface language (~/.config/hi-shell/config.json). Everything has a fallback, so it
// works without hi-shell having run.
Singleton {
    id: root

    readonly property string state: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/hi-shell"
    readonly property string config: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/hi-shell/config.json"

    property var colors: ({})
    // What wallpaper.txt says, and a picture of it when it's a video (wallpaper-still.txt).
    property string wallpaperFile: ""
    property string still: ""
    readonly property string wallpaper: still !== "" ? still : wallpaperFile
    property string language: "en"

    function color(name, fallback) {
        return colors[name] ?? fallback;
    }

    readonly property color background: color("background", "#14121a")
    readonly property color surface: color("surface_container", "#211f26")
    readonly property color primary: color("primary", "#d0bcff")
    readonly property color onPrimary: color("on_primary", "#381e72")
    readonly property color text: color("on_surface", "#e6e0e9")
    readonly property color muted: color("on_surface_variant", "#cac4d0")
    readonly property color outline: color("outline", "#938f99")

    readonly property bool russian: language === "ru"
    function tr(en, ru) {
        return russian ? ru : en;
    }

    FileView {
        path: `${root.state}/colors.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.colors = JSON.parse(text()).colors ?? ({});
            } catch (e) {}
        }
    }
    FileView {
        path: `${root.state}/wallpaper.txt`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.wallpaperFile = text().trim()
    }
    // A live wallpaper (video) has a picture of it for this: wallpaper-still.txt, when it exists.
    FileView {
        id: stillFile
        path: `${root.state}/wallpaper-still.txt`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.still = text().trim()
    }
    FileView {
        path: root.config
        onLoaded: {
            try {
                const l = JSON.parse(text()).language ?? "auto";
                root.language = l === "auto" ? (Quickshell.env("LANG") || "").slice(0, 2) : l;
            } catch (e) {}
        }
    }
}
