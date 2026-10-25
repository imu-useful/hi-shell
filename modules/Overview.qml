import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.common.widgets

// Workspace overview: the current group of workspaces (bar.workspaces.shown)
// with window previews. Click a window to focus it, a workspace to switch,
// drag a window onto another workspace to move it. Esc closes.
// Toggle: Super+Tab or `qs -c hi-shell ipc call overview toggle`.
Scope {
    id: root

    readonly property bool open: ShellState.overviewOpen
    readonly property int perGroup: Math.max(1, Config.options.bar.workspaces.shown)
    readonly property int columns: Math.ceil(perGroup / 2)

    function setOpen(value) {
        ShellState.overviewOpen = value;
    }

    onOpenChanged: if (open) Hyprland.refreshToplevels()

    function dispatch(code) {
        Hyprland.dispatch(code);
    }

    IpcHandler {
        target: "overview"

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

            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
            readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
            readonly property int first: Math.floor((Math.max(1, activeId) - 1) / root.perGroup) * root.perGroup + 1
            // Workspace thumbnails keep the screen's aspect ratio.
            readonly property real cellWidth: Math.min((width - 160) / root.columns, (height - 200) / 2 * width / height)
            readonly property real cellHeight: cellWidth * height / width
            readonly property real k: cellWidth / width

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            WlrLayershell.namespace: "hi-shell-overview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Shortcut {
                sequence: "Escape"
                onActivated: root.setOpen(false)
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Colors.m3surface, 0.55)
                opacity: loader.revealed ? 1 : 0
                Behavior on opacity { EffectAnim {} }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.setOpen(false)
                }
            }

            Grid {
                id: grid
                anchors.centerIn: parent
                columns: root.columns
                spacing: 16
                opacity: loader.revealed ? 1 : 0
                scale: loader.revealed ? 1 : 0.94
                Behavior on opacity { EffectAnim {} }
                Behavior on scale { EffectAnim {} }

                Repeater {
                    model: root.perGroup

                    Rectangle {
                        id: cell

                        required property int index
                        readonly property int wsId: window.first + index
                        readonly property bool isActive: wsId === window.activeId
                        readonly property var toplevels: Hyprland.toplevels.values.filter(t => t.workspace?.id === wsId)

                        width: window.cellWidth
                        height: window.cellHeight
                        radius: Appearance.rounding.large
                        clip: true
                        color: drop.containsDrag ? Colors.m3primaryContainer : Colors.m3surfaceContainer
                        border.width: isActive ? 2 : 1
                        border.color: isActive ? Colors.m3primary : Qt.alpha(Colors.m3outlineVariant, 0.8)

                        StyledText {
                            anchors.centerIn: parent
                            visible: cell.toplevels.length === 0
                            text: cell.wsId
                            font.pixelSize: Appearance.font.size.headlineLarge
                            color: Colors.m3outline
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.dispatch(`hl.dsp.focus({ workspace = ${cell.wsId} })`);
                                root.setOpen(false);
                            }
                        }

                        DropArea {
                            id: drop
                            anchors.fill: parent
                            keys: ["window"]
                            onDropped: drag => {
                                root.dispatch(`hl.dsp.window.move({ window = "address:0x${drag.source.address}", workspace = ${cell.wsId}, follow = false })`);
                                refresh.restart();
                            }
                        }

                        Repeater {
                            model: cell.toplevels

                            Item {
                                id: win

                                required property HyprlandToplevel modelData
                                readonly property var ipc: modelData.lastIpcObject
                                readonly property string address: modelData.address
                                readonly property real mx: window.monitor?.x ?? 0
                                readonly property real my: window.monitor?.y ?? 0

                                x: ((ipc?.at?.[0] ?? 0) - mx) * window.k
                                y: ((ipc?.at?.[1] ?? 0) - my) * window.k
                                width: Math.max(24, (ipc?.size?.[0] ?? 200) * window.k)
                                height: Math.max(18, (ipc?.size?.[1] ?? 150) * window.k)
                                z: dragArea.drag.active ? 10 : (ipc?.floating ? 2 : 1)

                                Drag.active: dragArea.drag.active
                                Drag.keys: ["window"]
                                Drag.source: win
                                Drag.hotSpot.x: width / 2
                                Drag.hotSpot.y: height / 2

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: Colors.m3surfaceContainerHighest
                                    clip: true
                                    border.width: hover.hovered ? 2 : 0
                                    border.color: Colors.m3primary

                                    ScreencopyView {
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        captureSource: root.open ? win.modelData.wayland : null
                                        live: false
                                        constraintSize: Qt.size(width * 2, height * 2)
                                    }
                                }

                                HoverHandler {
                                    id: hover
                                }

                                MouseArea {
                                    id: dragArea
                                    anchors.fill: parent
                                    drag.target: win
                                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    onReleased: {
                                        if (drag.active) {
                                            win.Drag.drop();
                                        } else {
                                            root.dispatch(`hl.dsp.focus({ window = "address:0x${win.address}" })`);
                                            root.setOpen(false);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: grid.bottom
                anchors.topMargin: 24
                text: Translation.tr("Click a window to focus it · drag it to another workspace · Esc to close")
                color: Colors.m3onSurfaceVariant
            }

            // Re-read window positions after a move.
            Timer {
                id: refresh
                interval: 300
                onTriggered: Hyprland.refreshToplevels()
            }
        }
    }
}
