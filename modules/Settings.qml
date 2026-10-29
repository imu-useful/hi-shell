import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.common.shapes
import qs.modules.settings
import "settings/Pages.js" as Pages

// Settings panel (Super+Escape, the ⚙ in the right sidebar, launcher search,
// or `qs -c hi-shell ipc call settings open bar`). Everything is saved to
// ~/.config/hi-shell/config.json as you change it.
Scope {
    id: root

    readonly property bool open: ShellState.settingsOpen && !ShellState.zen

    function setOpen(value) {
        ShellState.settingsOpen = value;
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            root.setOpen(!root.open);
        }
        // quick, general, bar, desktop, interface, services, hyprland, about
        function open(page: string): void {
            if (page)
                ShellState.settingsPage = page;
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
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            // The window takes clicks a little beyond the card too, so one that lands on its
            // edge isn't "outside" (which closes it, see the focus grab below).
            mask: Region { item: edge }

            WlrLayershell.namespace: "hi-shell-settings"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            HyprlandFocusGrab {
                windows: [window]
                active: root.open
                onCleared: root.setOpen(false)
            }

            Shortcut {
                sequence: "Escape"
                onActivated: root.setOpen(false)
            }

            Item {
                id: edge
                anchors.centerIn: parent
                width: card.width + 24
                height: card.height + 24

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }
            }

            Rectangle {
                id: card

                anchors.centerIn: parent
                width: Math.min(parent.width - 80, 1100)
                height: Math.min(parent.height - 100, 760)
                radius: Appearance.rounding.extraLarge
                color: Appearance.translucent(Colors.m3surfaceContainerLow)
                border.width: 1
                border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)

                opacity: loader.revealed ? 1 : 0
                scale: loader.revealed ? 1 : 0.85
                Behavior on opacity { EffectAnim {} }
                Behavior on scale { SpringAnim {} }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16

                    // --- Navigation rail ---
                    ColumnLayout {
                        // Nested layouts with filling children default to filling too.
                        Layout.fillWidth: false
                        Layout.preferredWidth: 220
                        Layout.maximumWidth: 220
                        Layout.fillHeight: true
                        spacing: 6

                        RowLayout {
                            Layout.margins: 6
                            spacing: 10
                            // Five quick taps on the avatar open the first-run welcome again
                            // (for when it was skipped), like Android's developer options.
                            ShapeImage {
                                id: avatar
                                implicitWidth: 44
                                implicitHeight: 44
                                shape: "cookie9"
                                source: `file://${Paths.home}/.face`

                                property int taps: 0
                                readonly property int needed: 5

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        avatar.taps++;
                                        tapReset.restart();
                                        bump.restart();
                                        if (avatar.taps >= avatar.needed) {
                                            avatar.taps = 0;
                                            root.setOpen(false);
                                            ShellState.showWelcome();
                                        }
                                    }
                                }
                                Timer {
                                    id: tapReset
                                    interval: 2000
                                    onTriggered: avatar.taps = 0
                                }
                                SequentialAnimation {
                                    id: bump
                                    NumberAnimation { target: avatar; property: "scale"; to: 0.86; duration: 70; easing.type: Easing.OutQuad }
                                    SpringAnim { target: avatar; property: "scale"; to: 1; duration: Appearance.anim.normal }
                                }
                            }
                            ColumnLayout {
                                spacing: 0
                                StyledText {
                                    text: Quickshell.env("USER")
                                    font.weight: Font.Medium
                                }
                                StyledText {
                                    // Counts down once the taps start.
                                    text: avatar.taps >= 2 ? Translation.trn("%1 more tap…", "%1 more taps…", avatar.needed - avatar.taps)
                                                           : Translation.tr("Arch Linux · Hyprland")
                                    font.pixelSize: Appearance.font.size.labelSmall
                                    color: Colors.m3onSurfaceVariant
                                }
                            }
                        }

                        M3Button {
                            Layout.margins: 6
                            tonal: true
                            icon: "edit"
                            text: Translation.tr("Config file")
                            onClicked: {
                                root.setOpen(false);
                                Qt.openUrlExternally(`file://${Config.path}`);
                            }
                        }

                        Item { implicitHeight: 6 }

                        Repeater {
                            model: Pages.pages

                            Rectangle {
                                required property var modelData
                                readonly property bool active: ShellState.settingsPage === modelData.id

                                Layout.fillWidth: true
                                implicitHeight: 48
                                radius: 24
                                color: active ? Colors.m3secondaryContainer : "transparent"
                                Behavior on color { ColorAnim {} }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    spacing: 14
                                    MaterialIcon {
                                        icon: modelData.icon
                                        fill: active ? 1 : 0
                                        iconSize: 20
                                        color: active ? Colors.m3onSecondaryContainer : Colors.m3onSurfaceVariant
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Translation.tr(modelData.title)
                                        font.weight: active ? Font.Medium : Font.Normal
                                        color: active ? Colors.m3onSecondaryContainer : Colors.m3onSurface
                                    }
                                }
                                StateLayer {
                                    onClicked: ShellState.settingsPage = modelData.id
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }

                    // --- Page ---
                    StyledFlickable {
                        id: flick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: page.implicitHeight + 24

                        Loader {
                            id: page
                            width: flick.width - 12
                            sourceComponent: ({
                                quick: quick, general: general, bar: bar, desktop: desktop,
                                interface: iface, services: services, hyprland: hyprland, autostart: autostart, about: about, lock: lock
                            })[ShellState.settingsPage] ?? quick
                            onLoaded: {
                                flick.targetY = 0;
                                flick.contentY = 0;
                            }
                        }

                        Component { id: quick; QuickPage {} }
                        Component { id: general; GeneralPage {} }
                        Component { id: bar; BarPage {} }
                        Component { id: desktop; DesktopPage {} }
                        Component { id: iface; InterfacePage {} }
                        Component { id: services; ServicesPage {} }
                        Component { id: hyprland; HyprlandPage {} }
                        Component { id: autostart; AutostartPage {} }
                        Component { id: about; AboutPage {} }
                        Component { id: lock; LockPage {} }
                    }
                }
            }
        }
    }
}
