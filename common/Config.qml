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
    property bool filledIn: false

    FileView {
        id: file
        path: root.path
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeTimer.restart()
        // Write back once per start so options added in newer versions show up in the file.
        onLoaded: {
            if (!root.filledIn) {
                root.filledIn = true;
                writeTimer.restart();
            }
        }
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
                // top | bottom | left | right
                property string position: "top"
                // hug: edge to edge | float: detached, rounded | islands: one pill per section | m3: edge to edge, tonal groups
                property string style: "float"
                // Bar thickness (height, or width for a vertical bar) and gap to the screen edge.
                property int height: 40
                property int margin: 6
                // Widget ids: launcher, workspaces, activeWindow, media, resources, clock, weather, tray,
                // systemIcons, utilButtons, networkSpeed, battery, updates, keyboardLayout, power, visualizer, divider
                property list<string> left: ["launcher", "activeWindow"]
                property list<string> center: ["resources", "media", "workspaces", "clock", "utilButtons", "weather"]
                property list<string> right: ["tray", "keyboardLayout", "battery", "systemIcons", "power"]

                property JsonObject workspaces: JsonObject {
                    property int shown: 10
                    property bool numbers: false
                    property bool appIcons: true
                }
                property JsonObject clock: JsonObject {
                    // Qt date format strings
                    property string timeFormat: "HH:mm"
                    property string dateFormat: "ddd, dd/MM"
                }
                property JsonObject media: JsonObject {
                    property int maxWidth: 220
                }
                property JsonObject resources: JsonObject {
                    // cpu, ram, swap, gpu, disk
                    property list<string> shown: ["cpu", "ram"]
                }
                property JsonObject utilButtons: JsonObject {
                    // screenshot, colorPicker, darkMode, mic
                    property list<string> shown: ["screenshot", "colorPicker", "darkMode"]
                }
                property JsonObject updates: JsonObject {
                    property bool hideWhenNone: true
                }
            }

            property JsonObject weather: JsonObject {
                property bool enabled: true
                // Empty city and 0/0 coordinates = locate by IP address.
                property string city: ""
                property real latitude: 0
                property real longitude: 0
                property bool imperial: false
                property int refreshMinutes: 15
            }

            property JsonObject battery: JsonObject {
                property int low: 20
                property int critical: 10
                property bool warnings: true
            }

            property JsonObject notifications: JsonObject {
                // Popup timeout (ms) when the app doesn't set one.
                property int defaultTimeout: 6000
                property int historyLimit: 100
            }

            property JsonObject updates: JsonObject {
                property bool enabled: true
                property int intervalMinutes: 60
                // Also count AUR updates (needs yay or paru).
                property bool aur: true
            }

            property JsonObject tray: JsonObject {
                // Item ids (see `qs -c hi-shell ipc call tray list`) to leave out of the bar.
                property list<string> hidden: []
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
