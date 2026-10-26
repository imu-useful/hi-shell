import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.services
import qs.common.widgets
import qs.modules.calendar

// Calendar popup under the bar clock: the month.
// Toggle: click the clock, or `qs -c hi-shell ipc call calendar toggle`.
Scope {
    id: root

    readonly property bool open: ShellState.calendarOpen

    function setOpen(value) {
        ShellState.calendarOpen = value;
    }

    Connections {
        target: ShellState
        function onCalendarOpenChanged() {
            if (ShellState.calendarOpen)
                Calendar.resetMonth();
        }
    }

    IpcHandler {
        target: "calendar"

        function toggle(): void {
            root.setOpen(!root.open);
        }
        function open(): void {
            root.setOpen(true);
        }
        function close(): void {
            root.setOpen(false);
        }
    }

    PanelLoader {
        id: loader
        shown: root.open

        PanelWindow {
            id: window

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

            // Open next to the bar: from the bottom when the bar is at the bottom.
            readonly property bool atBottom: Config.options.bar.position === "bottom"
            anchors.top: !atBottom
            anchors.bottom: atBottom
            exclusiveZone: 0
            margins.top: Appearance.sizes.barMargin
            margins.bottom: Appearance.sizes.barMargin
            implicitWidth: 340
            implicitHeight: 360
            color: "transparent"

            WlrLayershell.namespace: "hi-shell-calendar"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            HyprlandFocusGrab {
                windows: [window]
                active: root.open
                onCleared: root.setOpen(false)
            }

            Shortcut {
                sequence: "Escape"
                onActivated: root.setOpen(false)
            }

            Rectangle {
                id: card

                anchors.fill: parent
                radius: Appearance.rounding.extraLarge
                color: Appearance.translucent(Colors.m3surfaceContainer)
                border.width: 1
                border.color: Colors.m3outlineVariant

                opacity: loader.revealed ? 1 : 0
                scale: loader.revealed ? 1 : 0.85
                transformOrigin: window.atBottom ? Item.Bottom : Item.Top
                Behavior on opacity { EffectAnim {} }
                Behavior on scale { SpringAnim {} }

                MonthGrid {
                    anchors.fill: parent
                    anchors.margins: 16
                }
            }
        }
    }
}
