//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.common
import qs.services
import qs.modules
import qs.modules.focus

ShellRoot {
    // Reloading on file changes is for development (HI_SHELL_DEV=1): this Quickshell
    // build can crash while reloading, and nothing in normal use needs it.
    settings.watchFiles: Quickshell.env("HI_SHELL_DEV") === "1"

    // Singletons load lazily; create the background services (and their IPC
    // handlers) at startup: palette, notification daemon, battery warnings, ...
    readonly property list<QtObject> services: [Theme, Notifications, Battery, Brightness, Mpris, Weather, Updates, Tray, HyprlandXkb, Toggles, Todo, Timers, Claude, Clipboard, Notes, WorldClock, Wallpapers, AutoMode, HyprlandSettings, Session, Presets, LockScreen, CoverMode, Displays, TerminalColors, Focus, FocusBlocker]

    // Startup animation: everything comes in once the wallpaper is on screen (Desktop
    // starts it); this is the fallback when there's no wallpaper or it's slow to load.
    Timer {
        running: true
        interval: 2500
        onTriggered: ShellState.started = true
    }

    Desktop {}

    DesktopVisualizer {}

    Variants {
        model: Quickshell.screens

        Bar {}
    }

    Launcher {}

    AIWidget {}

    SidebarRight {}

    SidebarLeft {}

    WallpaperSelector {}

    Settings {}

    SessionScreen {}

    PolkitDialog {}

    Overview {}

    WindowSwitcher {}

    DisplayMode {}

    RegionSelector {}

    Dock {}

    ScreenCorners {}

    CalendarPopup {}

    NotificationPopups {}

    OnScreenDisplay {}

    Welcome {}

    FocusSettingsWindow {}

    BlockedToast {}
}
