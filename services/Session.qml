pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.common

// Session actions used by the power menus and the session screen.
// Locking runs hyprlock with hi-shell's lock screen (services/LockScreen.qml).
// IPC: `qs -c hi-shell ipc call session lock` (logout, suspend, hibernate, reboot, poweroff, toggleScreen).
Singleton {
    id: root

    function lock() {
        LockScreen.lock();
    }
    function logout() {
        Hyprland.dispatch("hl.dsp.exit()");
    }
    function suspend() {
        Quickshell.execDetached(["systemctl", "suspend"]);
    }
    function hibernate() {
        Quickshell.execDetached(["systemctl", "hibernate"]);
    }
    function reboot() {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }
    function poweroff() {
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    IpcHandler {
        target: "session"

        function lock(): void { root.lock(); }
        function logout(): void { root.logout(); }
        function suspend(): void { root.suspend(); }
        function hibernate(): void { root.hibernate(); }
        function reboot(): void { root.reboot(); }
        function poweroff(): void { root.poweroff(); }
        function toggleScreen(): void {
            ShellState.sessionOpen = !ShellState.sessionOpen;
        }
    }
}
