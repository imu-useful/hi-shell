pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// XDG locations for hi-shell's files; the directories are created at startup.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string state: `${Quickshell.env("XDG_STATE_HOME") || home + "/.local/state"}/hi-shell`
    readonly property string cache: `${Quickshell.env("XDG_CACHE_HOME") || home + "/.cache"}/hi-shell`

    Process {
        running: true
        command: ["mkdir", "-p", root.state, root.cache]
    }
}
