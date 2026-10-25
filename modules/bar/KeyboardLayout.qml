import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.common
import qs.common.widgets

// Active keyboard layout of the main keyboard ("EN", "RU"); click = next layout.
BarWidget {
    id: root

    property string layout: ""
    // "English (US)" -> "EN", "Russian" -> "RU"
    readonly property string code: layout.slice(0, 2).toUpperCase()

    shown: layout !== ""
    clickable: true
    padding: 8
    contentWidth: label.implicitWidth
    contentHeight: label.implicitHeight
    onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])

    StyledText {
        id: label
        anchors.centerIn: parent
        text: root.code
        font.pixelSize: Appearance.font.size.labelMedium + 1
        font.weight: Font.DemiBold
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
