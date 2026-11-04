pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Which screens show a fullscreen window (the real fullscreen mode, not maximized: the bar stays
// visible over a maximized window), from Hyprland's IPC. Hyprland.toplevels keeps the windows'
// `fullscreen` field as of the last refresh, so a refresh follows every event that can change it.
Singleton {
    id: root

    // Names of the screens whose active workspace has a fullscreen window.
    readonly property var screens: {
        const names = [];
        const windows = Hyprland.toplevels.values;
        for (const m of Hyprland.monitors.values) {
            const ws = m.activeWorkspace?.id;
            if (ws !== undefined && windows.some(t => t.workspace?.id === ws && t.lastIpcObject?.fullscreen === 2))
                names.push(m.name);
        }
        return names;
    }

    function on(screenName: string): bool {
        return screens.includes(screenName);
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (["fullscreen", "openwindow", "closewindow", "movewindowv2", "workspacev2", "focusedmonv2", "activewindowv2"].includes(event.name))
                refresh.restart();
        }
    }

    // A burst of events gives one refresh.
    Timer {
        id: refresh
        interval: 30
        onTriggered: {
            Hyprland.refreshToplevels();
            Hyprland.refreshMonitors();
        }
    }
}
