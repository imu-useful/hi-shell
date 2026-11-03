pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The adult-site filter (Settings > Services): the domains of services/adult_domains.txt go into
// /etc/hosts, so every browser and app on this system can't reach them, until it's switched off.
// Changing /etc/hosts needs the password (pkexec). Whether it's on is read from /etc/hosts itself.
Singleton {
    id: root

    readonly property string marker: "# >>> hi-shell adult filter"
    readonly property string script: `${Quickshell.shellDir}/services/adult_filter.py`
    readonly property string list: `${Quickshell.shellDir}/services/adult_domains.txt`
    readonly property string python: Distro.id === "nixos" ? "/run/current-system/sw/bin/python3" : "/usr/bin/python3"

    property bool applied: false
    property bool busy: changer.running
    property string error: ""

    function set(on) {
        if (changer.running || on === applied)
            return;
        error = "";
        changer.wanted = on;
        changer.command = ["pkexec", python, script, on ? "on" : "off", ...(on ? [list] : [])];
        changer.running = true;
    }

    FileView {
        path: "/etc/hosts"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applied = text().includes(root.marker)
    }

    Process {
        id: changer
        property bool wanted: false
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("AdultFilter:", text.trim())
        }
        onExited: code => {
            if (code === 0) {
                root.applied = changer.wanted;
            } else {
                // 126 / 127: pkexec's "cancelled" / "no such authorization".
                root.error = code === 126 || code === 127 ? Translation.tr("Not changed: the password wasn't given") : Translation.tr("Couldn't change /etc/hosts (see the shell's log)");
            }
        }
    }
}
