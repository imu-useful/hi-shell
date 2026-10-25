pragma Singleton

import QtQuick
import Quickshell

// Shell-wide UI state shared between modules (e.g. bar button -> panel).
Singleton {
    property bool sidebarRightOpen: false
    // Right sidebar bottom tab: notifications | calendar | todo | timers
    property string sidebarTab: "notifications"
    property bool sidebarLeftOpen: false
    // Left sidebar tab: home | claude | translator | clipboard
    property string sidebarLeftTab: "home"
    property bool calendarOpen: false
    property bool desktopEditing: false
    property bool wallpaperSelectorOpen: false
    property bool settingsOpen: false
    property bool sessionOpen: false
    property bool overviewOpen: false
    // Set to screenshot / ocr / record to open the region selector.
    property string captureRequest: ""
    // quick | general | bar | desktop | interface | services | hyprland | about
    property string settingsPage: "quick"
    property bool launcherOpen: false
    // Text to start the launcher with (IPC launcher search), consumed on open.
    property string launcherQuery: ""
}
