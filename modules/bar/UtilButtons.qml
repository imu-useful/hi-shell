import QtQuick
import Quickshell
import qs.common
import qs.common.widgets

// Quick actions (bar.utilButtons.shown): screenshot, colorPicker, darkMode, wallpaper, mic.
BarWidget {
    id: root

    readonly property var all: ({
        // Region selector: screenshot / OCR / recording.
        screenshot: { icon: "screenshot_region", action: () => ShellState.captureRequest = "screenshot" },
        colorPicker: { icon: "colorize", command: ["hyprpicker", "-a"] },
        darkMode: { icon: Colors.dark ? "dark_mode" : "light_mode", action: () => Theme.toggleMode() },
        wallpaper: { icon: "wallpaper", action: () => ShellState.wallpaperSelectorOpen = !ShellState.wallpaperSelectorOpen },
        mic: { icon: "mic", command: ["wpctl", "set-mute", "@DEFAULT_SOURCE@", "toggle"] }
    })
    readonly property var buttons: Config.options.bar.utilButtons.shown.filter(k => all[k]).map(k => all[k])

    shown: buttons.length > 0
    padding: 4
    contentWidth: grid.implicitWidth
    contentHeight: grid.implicitHeight

    Grid {
        id: grid
        anchors.centerIn: parent
        columns: root.vertical ? 1 : root.buttons.length
        spacing: 2

        Repeater {
            model: root.buttons

            Rectangle {
                required property var modelData
                width: root.thickness - 8
                height: width
                radius: width / 2
                color: "transparent"

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: modelData.icon
                    iconSize: 17
                    color: Colors.m3onSurface
                }

                StateLayer {
                    onClicked: modelData.action ? modelData.action() : Quickshell.execDetached(modelData.command)
                }
            }
        }
    }
}
