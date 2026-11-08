import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.common
import qs.services

// The lock screen (Settings > Lock screen > hi-shell): a Wayland session lock drawn by the shell
// itself, with the card of widgets in LockSurface. Locks from `qs -c hi-shell ipc call lock lock`,
// Session.lock() and the idle lock. `unlock` is for a stuck lock, run from a TTY.
Scope {
    id: root

    readonly property alias locked: sessionLock.locked

    WlSessionLock {
        id: sessionLock

        signal unlock

        LockSurface {
            lock: sessionLock
            pam: passwordCheck
        }
    }

    Pam {
        id: passwordCheck
        lock: sessionLock
    }

    Binding {
        target: ShellState
        property: "locked"
        value: sessionLock.locked
    }

    Connections {
        target: LockScreen
        function onLockRequested() {
            sessionLock.locked = true;
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void { sessionLock.locked = true; }
        function unlock(): void { sessionLock.unlock(); }
        function isLocked(): bool { return sessionLock.locked; }
    }
}
