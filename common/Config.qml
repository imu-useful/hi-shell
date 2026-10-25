pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// User configuration in ~/.config/hi-shell/config.json.
// Missing keys fall back to the defaults below; edits to the file apply live,
// and changes made from the UI (assigning to Config.options.*) are written back.
Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/hi-shell`
    readonly property string path: `${dir}/config.json`

    readonly property alias options: adapter
    readonly property bool ready: file.loaded

    FileView {
        id: file
        path: root.path
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeTimer.restart()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                mkdir.running = true;
            } else {
                console.warn("Config: failed to load", root.path, FileViewError.toString(error));
            }
        }

        JsonAdapter {
            id: adapter

            property JsonObject appearance: JsonObject {
                // Translucent surfaces (the compositor blurs what's behind them).
                property bool transparency: true
                property real transparencyLevel: 0.12
                property JsonObject fonts: JsonObject {
                    property string main: "Google Sans Flex"
                    property string title: "Google Sans Flex"
                    property string mono: "JetBrains Mono"
                    property string icon: "Material Symbols Rounded"
                }
                // Global multiplier for animation durations (0 disables animations).
                property real animationSpeed: 1
            }

            property JsonObject bar: JsonObject {
                property int height: 40
                property int margin: 6
            }

            property JsonObject apps: JsonObject {
                // Used for desktop entries with Terminal=true
                property string terminal: "kitty"
            }
        }
    }

    // Coalesce bursts of changes (e.g. a slider drag) into one write.
    Timer {
        id: writeTimer
        interval: 300
        onTriggered: file.writeAdapter()
    }

    // First run: create the config directory, then write the defaults.
    Process {
        id: mkdir
        command: ["mkdir", "-p", root.dir]
        onExited: file.writeAdapter()
    }
}
