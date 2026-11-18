pragma Singleton

import QtQuick
import Quickshell

// The themes of Settings → Themes and Store, one ThemeStore per kind (see ThemeStore.qml).
Singleton {
    readonly property ThemeStore icons: ThemeStore {
        kind: "icons"
    }
    readonly property ThemeStore cursors: ThemeStore {
        kind: "cursors"
    }
    readonly property ThemeStore gtk: ThemeStore {
        kind: "gtk"
    }
    readonly property ThemeStore fonts: ThemeStore {
        kind: "fonts"
    }

    // Restart the shell (a newly installed font is only known to a fresh process).
    function restartShell() {
        Quickshell.execDetached(["sh", "-c", `sleep 0.5; qs -c hi-shell kill; exec setsid "${Quickshell.shellDir}/run.sh" -d`]);
    }

    function of(kind) {
        return ({ icons, cursors, gtk, fonts })[kind] ?? icons;
    }
}
