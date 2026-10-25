import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.services
import qs.modules.sidebarLeft

// Left sidebar: home (greeting, media + lyrics, weather), Claude chat,
// translator, clipboard history.
// Toggle: Super+Z (hypr/hi-shell.lua), the bar's sidebar button, or
// `qs -c hi-shell ipc call sidebarLeft toggle` / `openTab claude`.
Scope {
    id: root

    readonly property bool open: ShellState.sidebarLeftOpen
    readonly property list<string> tabs: ["home", "claude", "translator", "clipboard"]

    function setOpen(value) {
        ShellState.sidebarLeftOpen = value;
    }

    IpcHandler {
        target: "sidebarLeft"

        function toggle(): void {
            root.setOpen(!root.open);
        }
        function open(): void {
            root.setOpen(true);
        }
        function close(): void {
            root.setOpen(false);
        }
        // home, claude, translator, clipboard
        function openTab(tab: string): void {
            ShellState.sidebarLeftTab = tab;
            root.setOpen(true);
        }
    }

    PanelLoader {
        id: loader
        shown: root.open

        PanelWindow {
            id: window

            readonly property int panelWidth: 460

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            exclusiveZone: 0
            margins.top: Appearance.sizes.barMargin
            margins.bottom: Appearance.sizes.barMargin
            margins.left: Appearance.sizes.barMargin
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
                onActivated: Claude.busy && ShellState.sidebarLeftTab === "claude" ? Claude.cancel() : root.setOpen(false)
            }

            Rectangle {
                id: panel

                x: loader.revealed ? 0 : -window.panelWidth - 8
                width: window.panelWidth
                height: parent.height
                radius: Appearance.rounding.extraLarge
                color: Appearance.translucent(Colors.m3surfaceContainerLow)
                border.width: 1
                border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)

                Behavior on x { SpatialAnim { duration: Appearance.anim.slow; easing.bezierCurve: Appearance.anim.emphasizedDecel } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    SegmentedButton {
                        Layout.fillWidth: true
                        model: [
                            { icon: "home", text: "Home" },
                            { icon: "auto_awesome", text: "Claude" },
                            { icon: "translate", text: "Translate" },
                            { icon: "content_paste", text: "Clipboard" }
                        ]
                        currentIndex: Math.max(0, root.tabs.indexOf(ShellState.sidebarLeftTab))
                        onSelected: index => ShellState.sidebarLeftTab = root.tabs[index]
                    }

                    Loader {
                        id: page
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        sourceComponent: ({ home: home, claude: claude, translator: translator, clipboard: clipboard })[ShellState.sidebarLeftTab] ?? home
                        // Put the cursor where you'd type.
                        onLoaded: if (item.focusInput) Qt.callLater(() => item.focusInput())
                    }
                }

                Component { id: home; HomePage {} }
                Component { id: claude; ChatPage {} }
                Component { id: translator; TranslatorPage {} }
                Component {
                    id: clipboard
                    ClipboardPage {
                        onCopied: root.setOpen(false)
                    }
                }
            }
        }
    }
}
