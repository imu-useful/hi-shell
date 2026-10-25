pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Active keyboard layout of the main keyboard ("English (US)" -> code "EN").
Singleton {
    id: root

    property string layout: ""
    readonly property string code: layout.slice(0, 2).toUpperCase()

    function next() {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    }

    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const main = JSON.parse(text).keyboards.find(k => k.main);
                    if (main)
                        root.layout = main.active_keymap;
                } catch (e) {}
            }
        }
    }

    // "activelayout" data: "<keyboard>,<layout name>"
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout")
                root.layout = event.data.split(",").slice(1).join(",");
        }
    }
}
