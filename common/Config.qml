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

            // Interface language: auto (from $LANG), en, ru
            property string language: "auto"

            property JsonObject appearance: JsonObject {
                // Translucent surfaces (the compositor blurs what's behind them).
                property bool transparency: true
                property real transparencyLevel: 0.12
                // The playing track's cover, blurred, behind the media cards.
                property bool coverBackdrop: true
                property JsonObject fonts: JsonObject {
                    property string main: "Google Sans Flex"
                    property string title: "Google Sans Flex"
                    property string mono: "JetBrains Mono"
                    property string icon: "Material Symbols Rounded"
                }
                // Global multiplier for animation durations (0 disables animations).
                property real animationSpeed: 1
                // matugen scheme: tonal-spot, content, expressive, fidelity, fruit-salad, monochrome, neutral, rainbow, vibrant
                property string scheme: "tonal-spot"
                // Switch dark / light at sunset / sunrise (from the weather service's location).
                property bool autoMode: false
                // Also switch GTK apps (org.gnome.desktop.interface color-scheme) with dark / light.
                property bool gtkColorScheme: true
                // Rounded black screen corners, radius in px (0 = off).
                property int screenCorners: 16
                // Context menus (the system tray's): material = the shell's own Material You menu,
                // standard = the one the system draws.
                property string contextMenu: "material"
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
                // systemIcons, notifications, utilButtons, networkSpeed, battery, updates, keyboardLayout, power, visualizer, divider
                property list<string> left: ["launcher", "activeWindow"]
                property list<string> center: ["resources", "media", "workspaces", "clock", "utilButtons", "weather"]
                property list<string> right: ["tray", "keyboardLayout", "battery", "notifications", "systemIcons", "power"]

                property JsonObject workspaces: JsonObject {
                    property int shown: 10
                    property bool numbers: false
                    property bool appIcons: true
                    // Icons shown per workspace; the apps beyond it are counted as "+N"
                    property int appsPerWorkspace: 3
                    // How the active pill moves: "slide" or "stretch" (it stretches over the slots in between, like a snake)
                    property string switchStyle: "slide"
                }
                property JsonObject clock: JsonObject {
                    // Qt date format strings
                    property string timeFormat: "HH:mm"
                    property string dateFormat: "ddd, dd/MM"
                }
                property JsonObject media: JsonObject {
                    property int maxWidth: 220
                    // Spin the cover art while playing.
                    property bool spinArt: true
                }
                property JsonObject resources: JsonObject {
                    // cpu, ram, swap, gpu, disk
                    property list<string> shown: ["cpu", "ram"]
                }
                property JsonObject utilButtons: JsonObject {
                    // screenshot, colorPicker, darkMode, wallpaper, mic
                    property list<string> shown: ["screenshot", "colorPicker", "wallpaper", "darkMode"]
                }
                property JsonObject updates: JsonObject {
                    property bool hideWhenNone: true
                }
            }

            property JsonObject sidebar: JsonObject {
                property JsonObject quickToggles: JsonObject {
                    // android: two-column pills with labels | classic: round icon buttons
                    property string style: "android"
                    // Order matters. Available: wifi, bluetooth, darkMode, nightLight, dnd, keepAwake, mic,
                    // gameMode, vpn, colorPicker, screenshot, coverMode, focusMode, displayMode, focusSession,
                    // waitMode (hidden by default: add it in the sidebar's tile editor)
                    property list<string> shown: ["wifi", "bluetooth", "darkMode", "nightLight", "dnd", "keepAwake", "mic", "gameMode", "focusSession", "colorPicker", "screenshot"]
                }
                // Night light color temperature (K) for hyprsunset.
                property int nightLightTemperature: 4500
                // The game in the empty notification center: dino, snake or minesweeper
                property string game: "dino"
            }

            property JsonObject spotify: JsonObject {
                // Client ID from developer.spotify.com/dashboard (not a secret: login uses PKCE).
                property string clientId: ""
            }

            property JsonObject wallpapers: JsonObject {
                property list<string> directories: ["~/Pictures/Wallpapers"]
                // Online pictures are saved here before being set.
                property string downloadDirectory: "~/Pictures/Wallpapers/online"
                // Unsplash needs a free access key (unsplash.com/developers); Wallhaven works without one.
                property string unsplashKey: ""
                // Optional Wallhaven API key (only needed for NSFW / account features).
                property string wallhavenKey: ""
                // Shape the wallpaper is shown in on the desktop ("" = full screen): any id from `frames` in common/shapes/Shapes.js: sunny, cookie9, hexagon, star, blob, ...
                property string frame: ""
                // The frame turns and pulses to the music while something plays.
                property bool frameDance: true
                // Where the frame's center sits, as fractions of the screen (0.5 / 0.5 = the middle).
                // Moved by dragging it in the desktop's edit mode.
                property real frameX: 0.5
                property real frameY: 0.5
                // The frame's size, as a fraction of the screen's shorter side.
                property real frameSize: 0.62
            }

            property JsonObject desktop: JsonObject {
                // Draw the wallpaper (the theme's current one) behind the widgets.
                property bool wallpaper: true
                property bool widgets: true
                // Screen name (e.g. "eDP-1") for the widgets; empty = first screen.
                property string monitor: ""
                // Widget id -> { enabled, x, y } with x / y as fractions of the screen;
                // missing ids use the defaults in modules/desktop/Layout.js. Edit mode writes this.
                property var layout: ({})
                // Where the edit toolbar was dragged to, as fractions of the free space on the
                // screen (-1 = the default, bottom center).
                property JsonObject toolbar: JsonObject {
                    property real x: -1
                    property real y: -1
                }
                property list<string> worldClocks: ["Europe/London", "America/New_York", "Asia/Tokyo", "Australia/Sydney"]
                // Picture for the image frame widget (empty = the wallpaper).
                property string image: ""
                // Focus mode: with windows open, the wallpaper is sharp and widgets and frame hide.
                property bool focusMode: true
                // Cover mode: the playing track's cover instead of the wallpaper (and its colors).
                property bool coverMode: false
                // Full-width audio visualizer along the bottom while media plays (needs cava).
                property bool visualizer: true
                // The big digital clock also shows the seconds (HH:MM:SS).
                property bool clockSeconds: false
            }

            // The lock screen (services/LockScreen.qml): what it shows and how it looks.
            property JsonObject lock: JsonObject {
                property bool clock: true
                property bool date: true
                property bool greeting: true
                property bool avatar: true
                property bool nowPlaying: true
                property bool battery: true
                property bool keyboardLayout: true
                property bool capsLockHint: true
                // Clock height in px, and its format for `date` (letters and % only).
                property int clockSize: 120
                property string clockFormat: "%H:%M"
                // The wallpaper behind the lock screen (off: the plain surface color).
                property bool wallpaper: true
                property int blurPasses: 3
                property int blurSize: 8
                // 0..1, how much the picture is dimmed.
                property real brightness: 0.55
            }

            // Power saving (services/PowerSaver.qml): turned on by hand. `saved` keeps the
            // values it changed, to put back when it's turned off.
            property JsonObject powerSaving: JsonObject {
                property bool enabled: false
                property var saved: ({})
            }

            property JsonObject ai: JsonObject {
                // claude CLI model alias: "" (CLI default), opus, sonnet, haiku
                property string model: ""
                // Off: no AI chat tab, no palette (Super+Y), nothing asks a model. The welcome
                // screen and Settings > General switch it.
                property bool enabled: true
                // "claude" (the CLI) or a provider id from services/AiProviders.js: openrouter, openai,
                // gemini, groq, deepseek, mistral, ollama, custom
                property string provider: "claude"
                // Per provider id: API key, chosen model, and the server address where it isn't the
                // default (Ollama's port, a custom server)
                property var keys: ({})
                property var models: ({})
                property var urls: ({})
                // Before the per-provider maps: OpenRouter's key and model (still read as a fallback)
                property string openrouterKey: ""
                property string openrouterModel: ""
            }

            property JsonObject translator: JsonObject {
                property string target: "en"
                // Shown as quick picks in the translator.
                property list<string> languages: ["en", "ru", "de", "fr", "es", "uk", "ja", "zh"]
            }

            property JsonObject clipboard: JsonObject {
                // Start `wl-paste --watch cliphist store` (text and images) with the shell.
                property bool watch: true
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

            // Written by the settings app's Hyprland page (see services/HyprlandSettings.qml).
            property JsonObject hyprland: JsonObject {
                // output name -> { mode, position, scale, transform }
                property var monitors: ({})
                // option path ("general.gaps_in") -> value
                property var options: ({})
                // Updates leave ~/.config/hypr/hi-shell/ (keybinds, rules) alone (update.sh, install.sh read this)
                property bool keepFiles: false
                // Commands Hyprland runs when it starts (Settings > Autostart; written into the generated
                // file as hl.exec_cmd on "hyprland.start"): [{ cmd: "discord --start-minimized", enabled: true }]
                property var autostart: ([])
            }

            property JsonObject dock: JsonObject {
                property bool enabled: false
                property bool autoHide: true
                property bool magnify: true
                property int iconSize: 44
                // Screen name; empty = first screen.
                property string monitor: ""
                // App ids (desktop file names / window classes), right click an icon to pin.
                property list<string> pinned: ["firefox", "kitty", "org.gnome.Nautilus"]
            }

            property JsonObject capture: JsonObject {
                // tesseract languages for OCR, e.g. "eng+rus"; auto = every installed one
                // (install tesseract-data-rus for Russian)
                property string ocrLanguages: "auto"
                // Sound of a screen recording: "off", "system" (what plays through the speakers)
                // or "mic" (the default microphone)
                property string recordSound: "off"
            }

            // How update.sh updates: "git" (the latest main) or "release" (the latest tagged release).
            // Chosen at install (install.sh --channel); installs from before this one follow git.
            property JsonObject update: JsonObject {
                property string channel: "git"
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
