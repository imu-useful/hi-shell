pragma Singleton

import QtQuick
import Quickshell

// The icon themes and the cursor themes of Settings → Icons & cursors (see ThemeStore.qml).
Singleton {
    readonly property ThemeStore icons: ThemeStore {
        kind: "icons"
    }
    readonly property ThemeStore cursors: ThemeStore {
        kind: "cursors"
    }
}
