import QtQuick
import Quickshell
import qs.common

// The cursor theme picked in Settings (appearance.cursorTheme), set in Hyprland again at every start:
// a Hyprland config that sets its own (hyprctl setcursor in an exec) would win otherwise. GTK, KDE
// and gsettings keep it in their own files.
Scope {
    id: root

    readonly property string theme: Config.options.appearance.cursorTheme
    readonly property int size: Config.options.appearance.cursorSize

    // After the config's own execs have run.
    Timer {
        running: Config.ready && root.theme !== ""
        interval: 3000
        onTriggered: Quickshell.execDetached(["hyprctl", "setcursor", root.theme, String(root.size)])
    }
}
