import QtQuick
import Quickshell.Io

// Every option of ~/.config/hi-shell/config.json with its default. Config.qml has two of these: the live
// one, filled from the file, and a pristine one that "reset" copies the defaults from.
JsonAdapter {

    // Interface language: auto (from $LANG), en, ru
    property string language: "auto"
    // Languages made with AI (Settings > General > Language): [{ code, name }]; their files are
    // in ~/.config/hi-shell/translations.
    property var customLanguages: []

    property JsonObject appearance: JsonObject {
        // App icons in one color, the palette's primary (dock, workspaces, launcher).
        property bool themedIcons: false
        // Restart the shell when KDE's icon theme changes (the icons break in a running process otherwise).
        property bool restartOnIconTheme: true
        // Translucent surfaces (the compositor blurs what's behind them).
        property bool transparency: true
        // How see-through the panels are when transparency is on: 0 = solid, 0.5 = half.
        property real transparencyLevel: 0.12
        // The playing track's cover, blurred, behind the media cards.
        property bool coverBackdrop: true
        property JsonObject fonts: JsonObject {
            // The interface font.
            property string main: "Google Sans Flex"
            // The font of titles and headings.
            property string title: "Google Sans Flex"
            // The monospace font (code, terminal-like text).
            property string mono: "JetBrains Mono"
            // The icon font; the shell makes its own cut-down copy of it at start.
            property string icon: "Material Symbols Rounded"
        }
        // Scales for the design tokens (common/Appearance.qml): 0 = square corners, 1 = Material's.
        property real cornerScale: 1
        // Multiplier for every text size (0.6 – 2).
        property real fontScale: 1
        // compact | comfortable | spacious: the spacing between and inside elements.
        property string density: "comfortable"
        // A color (#rrggbb) to make the palette from instead of the wallpaper; empty = from the wallpaper.
        property string seedColor: ""
        // -1 (soft) .. 1 (strong): the palette's contrast.
        property real contrast: 0
        // Colors of your own over the palette: role -> "#rrggbb", e.g. { "primary": "#ff6a00", "surface": "#101010" }.
        // The roles are the names in the palette file (~/.local/state/hi-shell/colors.json).
        property var colorOverrides: ({})
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
        // The logo of the bar's first button: "auto" (this system's) or a distribution id (common/icons/distros).
        property string logo: "auto"
        // Bar thickness (height, or width for a vertical bar) and gap to the screen edge.
        property int height: 40
        // The gap between a floating bar and the screen edge, in px.
        property int margin: 6
        // Widget ids: launcher, workspaces, activeWindow, media, resources, clock, weather, tray,
        // systemIcons, notifications, utilButtons, networkSpeed, battery, updates, keyboardLayout, power, visualizer, divider
        property list<string> left: ["launcher", "activeWindow"]
        // Widget ids of the bar's center section (see `left`).
        property list<string> center: ["resources", "media", "workspaces", "clock", "utilButtons", "weather"]
        // Widget ids of the bar's right section (see `left`).
        property list<string> right: ["tray", "keyboardLayout", "battery", "notifications", "systemIcons", "power"]

        // Per screen: screen name (hyprctl monitors) -> overrides of this bar's { enabled, position, style, height,
        // margin, left, center, right }; what a screen doesn't set comes from the options here.
        property var monitors: ({})
        // More bars: [{ id, monitors: ["eDP-1"] (empty = every screen), position, style, height, margin, left, center, right }]
        // (what an entry doesn't set comes from the options here, the widget lists default to empty).
        property var extra: []
        // Several copies of a widget with options of their own: "type#name" in a widget list, e.g. "resources#disks",
        // set here as { "resources#disks": { "shown": ["disk"] } }. Types: resources, utilButtons, workspaces, media, zoneClock.
        property var instances: ({})

        property JsonObject workspaces: JsonObject {
            // How many workspaces the bar shows at once.
            property int shown: 10
            // Show the workspace numbers.
            property bool numbers: false
            // Show the icons of the apps on a workspace.
            property bool appIcons: true
            // Icons shown per workspace; the apps beyond it are counted as "+N"
            property int appsPerWorkspace: 3
            // How the active pill moves: "slide" or "stretch" (it stretches over the slots in between, like a snake)
            property string switchStyle: "slide"
        }
        property JsonObject clock: JsonObject {
            // Qt date format strings
            property string timeFormat: "HH:mm"
            // Qt date format of the clock's date.
            property string dateFormat: "ddd, dd/MM"
        }
        // Dynamic Island = the clock widget: it also shows the music player, notifications and the
        // camera / microphone indicator, and floats over fullscreen windows.
        property JsonObject island: JsonObject {
            // Turn the Dynamic Island (the clock widget that also shows music and notifications) on.
            property bool enabled: true
            // While it shows music or a notification the other widgets leave the bar (they go towards the island and fade).
            property bool hideBar: true
            // How long a press must be held to switch its state (ms).
            property int holdDuration: 2000
            // The music player state (a hold switches to it).
            property bool music: true
            // Show notifications in the island instead of as popup cards.
            property bool notifications: true
            // Volume, brightness, microphone and keyboard layout changes, instead of the display's own pill.
            property bool osd: true
            // The camera / microphone indicator.
            property bool privacy: true
            // Float at the top of the screen over a fullscreen window (the bar is hidden there).
            property bool fullscreen: true
        }
        property JsonObject media: JsonObject {
            // The widest the media widget gets, in px.
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
            // Hide the updates widget while there is nothing to update.
            property bool hideWhenNone: true
        }
    }

    property JsonObject sidebar: JsonObject {
        property JsonObject quickToggles: JsonObject {
            // android: two-column pills with labels | classic: round icon buttons
            property string style: "android"
            // Tiles per page in the android style (the rest go to further pages); 0 = all on one page
            property int perPage: 6
            // Slide between pages (off: switch instantly)
            property bool slide: true
            // Order matters. Available: wifi, bluetooth, darkMode, nightLight, dnd, keepAwake, mic,
            // gameMode, vpn, happ, colorPicker, screenshot, coverMode, focusMode, displayMode, focusSession,
            // waitMode (hidden by default: add it in the sidebar's tile editor)
            property list<string> shown: ["wifi", "bluetooth", "darkMode", "nightLight", "dnd", "keepAwake", "mic", "gameMode", "focusSession", "colorPicker", "screenshot"]
        }
        // What the right sidebar shows under its header and in what order: quickToggles, quickSliders, tabs.
        // Leave one out to hide it.
        property list<string> sections: ["quickToggles", "quickSliders", "tabs"]
        // The tabs of the "tabs" section, in order: notifications, calendar, todo, timers.
        property list<string> tabs: ["notifications", "calendar", "todo", "timers"]
        // Night light color temperature (K) for hyprsunset.
        property int nightLightTemperature: 4500
        // The game in the empty notification center: dino, snake, minesweeper, game2048, flappy, memory, tictactoe, puzzle or lightsout
        property string game: "dino"
    }

    // Rules: [{ id, name, enabled, when, then, else }] (see common/RulesEngine.js): when `when` turns true, `then` runs;
    // when it turns false, what `then` set is put back and `else` runs. rulesEnabled: false stops them all.
    property var rules: []
    // Settings shows the rarely needed rows too (Settings › Quick). Off hides them; the search always finds them.
    property bool settingsAdvanced: false
    // Off stops every rule and puts back what they changed.
    property bool rulesEnabled: true

    property JsonObject launcher: JsonObject {
        // The prefixes that switch the source, in the order of the chips under the empty search:
        // = calculator, > run a command, < keybinds, : emoji, ; clipboard, / settings, ~ files.
        property list<string> prefixes: ["=", ">", "<", ":", ";", "/", "~"]
        // What a plain search looks through, and in what order the results come: math (a typed calculation),
        // focus (Focus Mode), windows (open windows), settings (settings pages), apps, emoji.
        property list<string> sources: ["math", "focus", "windows", "settings", "apps", "emoji"]
    }

    property JsonObject spotify: JsonObject {
        // Client ID from developer.spotify.com/dashboard (not a secret: login uses PKCE).
        property string clientId: ""
    }

    property JsonObject wallpapers: JsonObject {
        // Folders the wallpaper picker looks in.
        property list<string> directories: ["~/Pictures/Wallpapers"]
        // A slideshow: a random picture from the folders every this many minutes (0 = off).
        property int slideshowMinutes: 0
        // Online pictures are saved here before being set.
        property string downloadDirectory: "~/Pictures/Wallpapers/online"
        // Unsplash needs a free access key (unsplash.com/developers); Wallhaven works without one.
        property string unsplashKey: ""
        // Optional Wallhaven API key (only needed for NSFW / account features).
        property string wallhavenKey: ""
        // Play a video or gif wallpaper (off: its still picture is shown). It pauses while a window covers the desktop.
        property bool animate: true
        // Shape the wallpaper is shown in on the desktop ("" = full screen): any id from `frames` in common/shapes/Shapes.js: sunny, cookie9, hexagon, star, blob, ...
        property string frame: ""
        // The frame turns and pulses to the music while something plays.
        property bool frameDance: true
        // On a beat the frame turns into another shape (it morphs), going through a set of shapes.
        property bool frameBeatShape: true
        // Where the frame's center sits, as fractions of the screen (0.5 / 0.5 = the middle).
        // Moved by dragging it in the desktop's edit mode.
        property real frameX: 0.5
        // The vertical center of the wallpaper frame, as a fraction of the screen height.
        property real frameY: 0.5
        // The frame's size, as a fraction of the screen's shorter side.
        property real frameSize: 0.62
        // Screen name -> a picture of its own for that screen (a path; images and gifs). The palette still follows `current`.
        property var perScreen: ({})
    }

    property JsonObject desktop: JsonObject {
        // Draw the wallpaper (the theme's current one) behind the widgets.
        property bool wallpaper: true
        // Show the desktop widgets.
        property bool widgets: true
        // Screen name (e.g. "eDP-1") for the widgets; empty = first screen.
        property string monitor: ""
        // The screens that show the widgets: names, or ["*"] for every screen. Empty = `monitor`, else the first screen.
        property list<string> monitors: []
        // Screen name -> a layout of its own (same shape as `layout`); a screen not in here uses `layout`.
        property var layouts: ({})
        // Widget id -> { enabled, x, y } with x / y as fractions of the screen;
        // missing ids use the defaults in modules/desktop/Layout.js. Edit mode writes this.
        property var layout: ({})
        // Where the edit toolbar was dragged to, as fractions of the free space on the
        // screen (-1 = the default, bottom center).
        property JsonObject toolbar: JsonObject {
            // Where the desktop edit toolbar was dragged to (horizontal); -1 = the default place.
            property real x: -1
            // Where the desktop edit toolbar was dragged to (vertical); -1 = the default place.
            property real y: -1
        }
        // IANA time zones the world clock widget shows.
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
        // The player card's progress bar: a travelling wave while playing (off: a plain bar),
        // and the wave kicks to the beat (needs cava).
        property bool waveProgress: true
        // The player card's wave kicks to the beat (needs cava).
        property bool waveBeat: true
    }

    // What Ctrl+Shift+Escape opens: hi-shell's process manager, or a program of your own
    // (btop in a terminal, a system monitor...).
    property JsonObject processes: JsonObject {
        property string mode: "builtin" // builtin | command
        // The program Ctrl+Shift+Escape runs when mode is `command`.
        property string command: "btop"
        // Run that program inside a terminal window.
        property bool inTerminal: true
    }

    // The palette for other apps (services/AppThemes.qml), each one opt-in.
    property JsonObject appThemes: JsonObject {
        // Write the wallpaper's colors into GTK 3 and 4 apps' gtk.css.
        property bool gtk: false
        // Write the hi-shell color scheme for Neovim (`:colorscheme hi-shell`).
        property bool neovim: false
    }

    // Idle (services/Idle.qml): when off, your own hypridle config is left alone. When on, hi-shell
    // runs hypridle with a config made from these minutes (0 = never), on battery too if asked.
    property JsonObject idle: JsonObject {
        // Let hi-shell run hypridle with the times below; off leaves your own hypridle config alone.
        property bool manage: false
        // Minutes of inactivity before the screen locks (0 = never).
        property int lockMin: 5
        // Minutes of inactivity before the screen turns off (0 = never).
        property int screenOffMin: 10
        // Minutes of inactivity before the computer suspends (0 = never).
        property int suspendMin: 15
        // Use the three battery times below while on battery.
        property bool separateBattery: false
        // Lock after this many minutes on battery (0 = never).
        property int batLockMin: 2
        // Turn the screen off after this many minutes on battery (0 = never).
        property int batScreenOffMin: 3
        // Suspend after this many minutes on battery (0 = never).
        property int batSuspendMin: 5
    }

    // The lock screen (services/LockScreen.qml): what it shows and how it looks.
    property JsonObject lock: JsonObject {
        // "builtin": the shell's own lock screen (modules/lock); "hyprlock": hyprlock with a config made
        // from hi-shell's look (the elements below); "file": your hyprlock config (sourced);
        // "command": any other locker (swaylock, gtklock, ...), run by Lock.
        property string mode: "builtin"
        // Path of your hyprlock config, for mode `file`.
        property string customConfig: ""
        // The locker to run, for mode `command` (swaylock, gtklock, ...).
        property string customCommand: ""
        // Builtin: the notification list only says how many came in, not what they say.
        property bool hideNotifs: false
        // Show the clock on the lock screen.
        property bool clock: true
        // Show the date on the lock screen.
        property bool date: true
        // Show the greeting on the lock screen.
        property bool greeting: true
        // Show your avatar on the lock screen.
        property bool avatar: true
        // Show the playing track on the lock screen.
        property bool nowPlaying: true
        // Show the battery on the lock screen.
        property bool battery: true
        // Show the keyboard layout on the lock screen.
        property bool keyboardLayout: true
        // Show a hint while Caps Lock is on.
        property bool capsLockHint: true
        // Clock height in px, and its format for `date` (letters and % only).
        property int clockSize: 120
        // The clock's format, `date` letters and % only (%H:%M).
        property string clockFormat: "%H:%M"
        // The date line, for `date` (letters and % only).
        property string dateFormat: "%A, %-d %B"
        // Where the column sits: "center", "left" or "right".
        property string align: "center"
        // The color of the clock and the accents: "primary", "secondary" or "tertiary".
        property string accent: "primary"
        // A line of your own under the date (empty = none).
        property string message: ""
        // The avatar's size in px.
        property int avatarSize: 116
        // The password field: width in px, and "round" or "square" corners.
        property int fieldWidth: 320
        // Corners of the password field: `round` or `square`.
        property string fieldShape: "round"
        // Width in px of the password field's outline.
        property int fieldOutline: 2
        // Show a dot for every typed character.
        property bool fieldDots: true
        // The wallpaper behind the lock screen (off: the plain surface color).
        property bool wallpaper: true
        // How many times the wallpaper behind the lock screen is blurred.
        property int blurPasses: 3
        // The blur's size.
        property int blurSize: 8
        // 0..1, how much the picture is dimmed.
        property real brightness: 0.55
    }

    // Power saving (services/PowerSaver.qml): turned on by hand. `saved` keeps the
    // values it changed, to put back when it's turned off.
    property JsonObject contentFilter: JsonObject {
        // Close a browser tab whose title has one of these words (services/KeywordFilter.qml).
        property bool keywordsOn: false
        // The words that close a browser tab when `keywordsOn` is true.
        property list<string> keywords: ["porn", "hentai", "порно", "хентай"]
    }

    // The "Welcome back!" at every start (the very first start always plays its own animation).
    property JsonObject greeting: JsonObject {
        // Play the greeting at every start.
        property bool enabled: true
        // The greeting's text.
        property string text: "Welcome back!"
        // random, or one of: rise, drop, pop, slide, spin
        property string style: "random"
        // The animated logo with the text
        property bool logo: true
    }

    property JsonObject viewing: JsonObject {
        // Viewing mode by itself: a fullscreen window while something plays.
        property bool auto: true
    }

    property JsonObject presentation: JsonObject {
        // What Presentation mode does while it's on.
        property bool holdNotifications: true
        // Presentation mode keeps the screen awake.
        property bool keepAwake: true
        // Presentation mode turns the night light off.
        property bool nightLightOff: true
        // Presentation mode hides the desktop widgets.
        property bool hideDesktopWidgets: true
        // Presentation mode hides the bar.
        property bool hideBar: false
    }

    property JsonObject powerSaving: JsonObject {
        // Power saving is on (use `hi ipc powersaving on|off`, not this option, so the saved values are kept).
        property bool enabled: false
        // The values power saving changed, to put back when it is turned off (kept by the shell).
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
        // Per provider id: the chosen model.
        property var models: ({})
        // Per provider id: the server address, where it isn't the default.
        property var urls: ({})
        // Before the per-provider maps: OpenRouter's key and model (still read as a fallback)
        property string openrouterKey: ""
        // Older: OpenRouter's model, still read as a fallback for `models`.
        property string openrouterModel: ""
    }

    property JsonObject translator: JsonObject {
        // The language the translator translates into.
        property string target: "en"
        // Shown as quick picks in the translator.
        property list<string> languages: ["en", "ru", "de", "fr", "es", "uk", "ja", "zh"]
    }

    property JsonObject clipboard: JsonObject {
        // Start `wl-paste --watch cliphist store` (text and images) with the shell.
        property bool watch: true
    }

    property JsonObject weather: JsonObject {
        // Fetch and show the weather.
        property bool enabled: true
        // Empty city and 0/0 coordinates = locate by IP address.
        property string city: ""
        // Latitude of the place (with `longitude`, instead of `city`).
        property real latitude: 0
        // Longitude of the place.
        property real longitude: 0
        // Use °F and miles.
        property bool imperial: false
        // Minutes between weather updates.
        property int refreshMinutes: 15
    }

    property JsonObject battery: JsonObject {
        // The charge (%) that counts as low.
        property int low: 20
        // The charge (%) that counts as critical.
        property int critical: 10
        // Send notifications when the battery is low or critical.
        property bool warnings: true
    }

    property JsonObject focus: JsonObject {
        // Breathing on the breaks (Focus Mode): the bar's cue and the wallpaper frame follow it.
        property bool breathing: true
    }

    property JsonObject notifications: JsonObject {
        // Popup timeout (ms) when the app doesn't set one.
        property int defaultTimeout: 6000
        // How many notifications the notification center keeps.
        property int historyLimit: 100
        // Focus Mode: the notifications that arrive in a focus period wait for the break (Settings > Focus).
        property bool holdInFocus: true
    }

    property JsonObject updates: JsonObject {
        // Check for system updates.
        property bool enabled: true
        // Minutes between update checks.
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
    }

    property JsonObject dock: JsonObject {
        // Show a dock.
        property bool enabled: false
        // Screen edge: "bottom", "top", "left" or "right".
        property string position: "bottom"
        // Hide the dock until the pointer reaches the screen edge.
        property bool autoHide: true
        // Icons grow toward the pointer.
        property bool magnify: true
        // With auto-hide: also show the dock while the workspace has no windows.
        property bool showWhenEmpty: true
        // Running apps that aren't pinned get an icon too.
        property bool showRunning: true
        // A button first in the dock that opens the full-screen list of every app.
        property bool appsButton: true
        // The dots under an icon, one per window.
        property bool showIndicators: true
        // How much an icon grows toward the pointer (percent), the gap between icons,
        // the corner radius and the distance from the screen edge (px).
        property int magnifyAmount: 45
        // The gap between icons, in px.
        property int spacing: 2
        // The dock's corner radius, in px.
        property int cornerRadius: 28
        // The distance from the screen edge, in px.
        property int edgeMargin: 8
        // Icon size in px.
        property int iconSize: 44
        // Screen name; empty = first screen.
        property string monitor: ""
        // The screens that have a dock: names, or ["*"] for every screen. Empty = `monitor`, else the first screen.
        property list<string> monitors: []
        // Screen name -> overrides of position, autoHide, magnify, showWhenEmpty, showRunning, appsButton, showIndicators,
        // magnifyAmount, spacing, cornerRadius, edgeMargin and iconSize for that screen's dock. (The pinned apps are shared.)
        property var perScreen: ({})
        // App ids (desktop file names / window classes), right click an icon to pin.
        property list<string> pinned: ["firefox", "kitty", "org.gnome.Nautilus"]
    }

    property JsonObject sounds: JsonObject {
        // Event sounds (services/Sounds.qml): the freedesktop theme through pw-play.
        property bool enabled: true
        // "freedesktop" (the system theme) or a downloaded pack: miui, samsung, iphone, windows, win7, winxp, android
        property string pack: "freedesktop"
        // Volume of the event sounds, 0 – 1.
        property real volume: 0.7
        // Sound for notifications.
        property bool notifications: true
        // Sound for timers.
        property bool timers: true
        // Sound for battery warnings and the charger.
        property bool battery: true
        // Sound for screenshots and recordings.
        property bool capture: true
        // A tick while the volume changes.
        property bool volumeTick: true
        // Sound at login, logout and lock.
        property bool session: true
        // Sound when a device is plugged in or out.
        property bool devices: true
        // Silent while Do Not Disturb, Presentation or Wait mode is on, and in Focus Mode (but for the timers).
        property bool quiet: true
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
        // How update.sh updates: `git` (the latest main) or `release` (the latest tagged release); set at install.
        property string channel: "git"
        // The window about a new version when the shell starts
        property bool notify: true
    }

    property JsonObject apps: JsonObject {
        // Used for desktop entries with Terminal=true
        property string terminal: "kitty"
    }
}
