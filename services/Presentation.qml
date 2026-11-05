pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Presentation mode: for sharing the screen or presenting. While it's on, notifications are held (nobody
// sees a private message pop up), the screen stays on, the night light is off (true colors) and the
// desktop widgets are hidden; the bar can hide too. Each part is a setting (Config presentation.*).
// Turn it on in the right panel (the Presentation quick toggle), in Settings, or with
// `qs -c hi-shell ipc call presentation toggle`. Off, everything goes back the way it was.
Singleton {
    id: root

    readonly property var options: Config.options.presentation

    property bool active: false
    property bool wasBarHidden: false
    property bool wasDnd: false
    property bool wasNightLight: false

    // Read by the desktop to hide its widgets.
    readonly property bool hideWidgets: active && options.hideDesktopWidgets

    function toggle() {
        set(!active);
    }

    function set(on) {
        if (on === active)
            return;
        active = on;
        if (on) {
            if (options.hideBar) {
                wasBarHidden = ShellState.barHidden;
                ShellState.barHidden = true;
            }
            if (options.holdNotifications) {
                wasDnd = Notifications.dnd;
                Notifications.dnd = true;
            }
            if (options.nightLightOff) {
                wasNightLight = Toggles.nightLight;
                if (wasNightLight)
                    Toggles.setNightLight(false);
            }
            if (options.keepAwake)
                keepAwake.running = true;
        } else {
            // Only undo what was done on the way in, whatever the settings say now.
            if (didHideBar)
                ShellState.barHidden = wasBarHidden;
            if (didHoldNotifications)
                Notifications.dnd = wasDnd;
            if (wasNightLight)
                Toggles.setNightLight(true);
            keepAwake.running = false;
        }
        didHideBar = on && options.hideBar;
        didHoldNotifications = on && options.holdNotifications;
    }

    property bool didHideBar: false
    property bool didHoldNotifications: false

    Process {
        id: keepAwake
        command: ["systemd-inhibit", "--what=idle", "--who=hi-shell", "--why=Presentation mode", "sleep", "infinity"]
    }

    IpcHandler {
        target: "presentation"

        function toggle(): void {
            root.toggle();
        }
        function on(): void {
            root.set(true);
        }
        function off(): void {
            root.set(false);
        }
        function status(): string {
            return JSON.stringify({ active: root.active });
        }
    }
}
