//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.common
import qs.services
import qs.modules

ShellRoot {
    // Singletons load lazily; create the background services (and their IPC
    // handlers) at startup: palette, notification daemon, battery warnings, ...
    readonly property list<QtObject> services: [Theme, Notifications, Battery, Brightness, Mpris, Weather, Updates, Tray, HyprlandXkb]

    Variants {
        model: Quickshell.screens

        Bar {}
    }

    Launcher {}

    AIWidget {}

    ControlCenter {}

    CalendarPopup {}

    NotificationPopups {}

    OnScreenDisplay {}
}
