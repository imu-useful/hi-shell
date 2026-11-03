pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The system's distribution, from /etc/os-release: its logo id (common/icons/distros), "" when unknown.
Singleton {
    id: root

    property string id: ""
    readonly property string logo: {
        if (id === "")
            return "";
        if (id === "arch")
            return "archlinux";
        if (id.startsWith("opensuse"))
            return "opensuse";
        return ["archlinux", "nixos", "debian", "fedora", "cachyos", "endeavouros", "blackarch", "void"].includes(id) ? id : "";
    }

    FileView {
        path: "/etc/os-release"
        printErrors: false
        onLoaded: {
            const line = text().split("\n").find(l => l.startsWith("ID="));
            root.id = line ? line.slice(3).replace(/"/g, "").trim() : "";
        }
    }
}
