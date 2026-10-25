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
    }
    // Text to start the launcher with (IPC launcher search), consumed on open.
    property string launcherQuery: ""
}
