pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Shell-wide UI state shared between modules (e.g. bar button -> panel).
Singleton {
    id: root

    property bool sidebarRightOpen: false
    // Right sidebar bottom tab: notifications | calendar | todo | timers
    property string sidebarTab: "notifications"
    property bool sidebarLeftOpen: false
    // Left sidebar tab: home | claude | translator | clipboard
    property string sidebarLeftTab: "home"
    property bool calendarOpen: false
    property bool desktopEditing: false
    // Windows cover the desktop widgets (their screen's workspace has windows):
    // second-by-second clocks, lyrics and the visualizer pause.
    property bool desktopCovered: false
    property bool wallpaperSelectorOpen: false
    property bool settingsOpen: false
    property bool sessionOpen: false
    property bool overviewOpen: false
    // Set to screenshot / ocr / record to open the region selector.
    property string captureRequest: ""
    // quick | general | bar | desktop | interface | services | hyprland | about
    property string settingsPage: "quick"
    property bool launcherOpen: false
    // Set shortly after startup: the bar, wallpaper, frame and widgets animate in.
    property bool started: false

    // Open the first-run welcome again (five taps on the avatar in Settings).
    signal showWelcome()

    // Display mode picker (the display key, the quick toggle, Settings).
    property bool displayModeOpen: false
    // Bar hidden on every screen (`qs -c hi-shell ipc call bar toggle`).
    property bool barHidden: false
    // Text for the translator to take (region "translate"); consumed by the page.
    property string translatorInput: ""

    IpcHandler {
        target: "bar"

        function toggle(): void {
            root.barHidden = !root.barHidden;
        }
        function show(): void {
            root.barHidden = false;
        }
        function hide(): void {
            root.barHidden = true;
        }
        // For bug reports: what decides whether the bar shows (`qs -c hi-shell ipc call bar status`).
        function status(): string {
            return JSON.stringify({
                started: root.started,
                barHidden: root.barHidden,
                zen: root.zen,
                animationSpeed: Appearance.anim.speed,
                barStyle: Config.options.bar.style,
                barPosition: Config.options.bar.position,
                barHeight: Config.options.bar.height,
                screens: Quickshell.screens.map(s => `${s.name} ${s.width}x${s.height}`),
                wallpaper: Config.options.desktop.wallpaper,
                widgets: [Config.options.bar.left.length, Config.options.bar.center.length, Config.options.bar.right.length]
            });
        }
    }
    // Text to start the launcher with (IPC launcher search), consumed on open.
    property string launcherQuery: ""

    // A Focus Mode session runs (services/Focus.qml): the bar keeps only workspaces,
    // system icons and the clock / timer, desktop widgets hide, animations, blur and
    // cover mode are off, and Settings, the left sidebar and the wallpaper picker stay
    // closed.
    property bool zen: false
    // A short message on the on-screen display (e.g. "locked during Focus Mode").
    signal osdMessage(string icon, string label)
}
