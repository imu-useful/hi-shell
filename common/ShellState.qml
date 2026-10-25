pragma Singleton

import QtQuick
import Quickshell

// Shell-wide UI state shared between modules (e.g. bar button -> panel).
Singleton {
    property bool controlCenterOpen: false
    property bool calendarOpen: false
    property bool launcherOpen: false
}
