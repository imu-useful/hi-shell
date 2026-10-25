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

// Calendar popup under the bar clock: month grid + Google Calendar agenda.
// Toggle: click the clock, or `qs -c hi-shell ipc call calendar toggle`.
Scope {
    id: root

    readonly property bool open: ShellState.calendarOpen
    property string selectedDay: ""

    function setOpen(value) {
        ShellState.calendarOpen = value;
    }

    Connections {
        target: ShellState
        function onCalendarOpenChanged() {
            if (ShellState.calendarOpen) {
                root.selectedDay = "";
                Calendar.resetMonth();
                Calendar.refresh();
            }
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
        function refresh(): void {
            Calendar.refresh();
        }
    }

    PanelLoader {
        id: loader
        shown: root.open

        PanelWindow {
            id: window

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

            anchors.top: true
            exclusiveZone: 0
            margins.top: Appearance.sizes.barMargin
            implicitWidth: 720
            implicitHeight: 400
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
                scale: loader.revealed ? 1 : 0.95
                transformOrigin: Item.Top
                Behavior on opacity { EffectAnim {} }
                Behavior on scale { EffectAnim {} }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16

                    MonthGrid {
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: 300
                        Layout.maximumWidth: 300
                        selectedDay: root.selectedDay
                        onDaySelected: day => root.selectedDay = day
                    }

                    Rectangle {
                        Layout.fillHeight: true
                        implicitWidth: 1
                        color: Colors.m3outlineVariant
                    }

                    Agenda {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        selectedDay: root.selectedDay
                    }
                }
            }
        }
    }
}
