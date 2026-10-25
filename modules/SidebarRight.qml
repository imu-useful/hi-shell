import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.services
import qs.modules.sidebar

// Right sidebar: header, quick toggles, sliders and notifications / calendar /
// to-do / timers; Wi-Fi, Bluetooth and audio open as sub-pages.
// Toggle: bar system icons, Hyprland keybind (hypr/hi-shell.lua) or
// `qs -c hi-shell ipc call sidebarRight toggle`.
Scope {
    id: root

    readonly property bool open: ShellState.sidebarRightOpen
    // "" = main page, or wifi / bluetooth / audio
    property string page: ""
    property bool editing: false

    function setOpen(value) {
        ShellState.sidebarRightOpen = value;
    }

    onOpenChanged: {
        if (open) {
            if (ShellState.sidebarTab === "notifications")
                Notifications.markAllRead();
        } else {
            page = "";
            editing = false;
        }
    }

    IpcHandler {
        target: "sidebarRight"

        function toggle(): void {
            root.setOpen(!root.open);
        }
        function open(): void {
            root.setOpen(true);
        }
        function close(): void {
            root.setOpen(false);
        }
        // notifications, calendar, todo, timers
        function openTab(tab: string): void {
            ShellState.sidebarTab = tab;
            root.page = "";
            root.setOpen(true);
        }
        // wifi, bluetooth, audio
        function openPage(page: string): void {
            root.page = page;
            root.setOpen(true);
        }
    }

    PanelLoader {
        id: loader
        shown: root.open

        PanelWindow {
            id: window

            readonly property int panelWidth: 440

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            anchors.top: true
            anchors.bottom: true
            anchors.right: true
            // Sit next to the bars (respect their exclusive zones) without reserving space.
            exclusiveZone: 0
            margins.top: Appearance.sizes.barMargin
            margins.bottom: Appearance.sizes.barMargin
            margins.right: Appearance.sizes.barMargin
            implicitWidth: panelWidth
            color: "transparent"

            WlrLayershell.namespace: "hi-shell-sidebar"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            HyprlandFocusGrab {
                windows: [window]
                active: root.open
                onCleared: root.setOpen(false)
            }

            Shortcut {
                sequence: "Escape"
                onActivated: root.page !== "" ? root.page = "" : root.setOpen(false)
            }

            Rectangle {
                id: panel

                x: loader.revealed ? 0 : window.panelWidth + 8
                width: window.panelWidth
                height: parent.height
                radius: Appearance.rounding.extraLarge
                color: Appearance.translucent(Colors.m3surfaceContainerLow)
                border.width: 1
                border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)

                Behavior on x { SpatialAnim { duration: Appearance.anim.slow; easing.bezierCurve: Appearance.anim.emphasizedDecel } }

                // Main page
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14
                    visible: root.page === ""

                    Header {
                        Layout.fillWidth: true
                        editing: root.editing
                        onEditingChanged: root.editing = editing
                        onCloseRequested: root.setOpen(false)
                    }

                    QuickToggles {
                        Layout.fillWidth: true
                        editing: root.editing
                        onOpenPage: page => root.page = page
                        onCloseRequested: root.setOpen(false)
                    }

                    QuickSliders {
                        Layout.fillWidth: true
                        onOpenPage: page => root.page = page
                    }

                    BottomGroup {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }

                // Sub-pages
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8
                    visible: root.page !== ""

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        IconButton {
                            icon: "arrow_back"
                            onClicked: root.page = ""
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.page === "wifi" ? Translation.tr("Wi-Fi") : root.page === "bluetooth" ? Translation.tr("Bluetooth") : Translation.tr("Sound")
                            font.pixelSize: Appearance.font.size.titleLarge
                        }
                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        sourceComponent: root.page === "wifi" ? wifiPage : root.page === "bluetooth" ? btPage : root.page === "audio" ? audioPage : null
                    }
                }

                Component { id: wifiPage; WifiPage {} }
                Component { id: btPage; BluetoothPage {} }
                Component { id: audioPage; AudioPage {} }
            }
        }
    }
}
