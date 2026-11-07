import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.services

// Process manager: a searchable list sorted by CPU / memory / name / PID, end or force-kill.
// Toggle: Ctrl+Shift+Escape or `qs -c hi-shell ipc call processes toggle`; Settings > General can
// point the key at another program (btop...) instead.
Scope {
    id: root

    readonly property bool open: ShellState.processesOpen
    property string query: ""
    readonly property var rows: {
        const q = query.toLowerCase().trim();
        const all = Processes.list;
        return (q ? all.filter(p => p.name.toLowerCase().includes(q) || String(p.pid) === q) : all).slice(0, 200);
    }

    function setOpen(value) {
        ShellState.processesOpen = value;
    }

    // The key / IPC: hi-shell's own manager, or the program chosen in Settings > General.
    readonly property var o: Config.options.processes
    readonly property bool custom: o.mode === "command" && o.command.trim() !== ""
    function request() {
        if (!custom) {
            setOpen(!open);
            return;
        }
        const cmd = o.command.trim();
        Quickshell.execDetached(o.inTerminal ? [Config.options.apps.terminal, "-e", "sh", "-c", cmd] : ["sh", "-c", cmd]);
    }

    onOpenChanged: {
        Processes.active = open;
        if (!open)
            query = "";
    }

    IpcHandler {
        target: "processes"

        function toggle(): void {
            root.request();
        }
        function open(): void {
            if (root.custom)
                root.request();
            else
                root.setOpen(true);
        }
        function close(): void {
            root.setOpen(false);
        }
    }

    component SortChip: Chip {
        required property string key
        selected: Processes.sortKey === key
        onClicked: Processes.setSort(key)
    }

    PanelLoader {
        id: loader
        shown: root.open

        PanelWindow {
            id: window

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            exclusiveZone: 0
            implicitWidth: 560
            implicitHeight: 600
            color: "transparent"

            WlrLayershell.namespace: "hi-shell-processes"
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

            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.extraLarge
                color: Colors.m3surfaceContainer
                border.width: 1
                border.color: Colors.m3outlineVariant

                opacity: loader.revealed ? 1 : 0
                scale: loader.revealed ? 1 : 0.9
                Behavior on opacity { EffectAnim {} }
                Behavior on scale { SpringAnim {} }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    RowLayout {
                        spacing: 10
                        MaterialIcon {
                            icon: "memory"
                            iconSize: 22
                            color: Colors.m3primary
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Processes")
                            font.pixelSize: Appearance.font.size.titleMedium
                        }
                        StyledText {
                            text: Translation.tr("CPU %1% · RAM %2%").arg(Math.round(SystemStats.cpuUsage * 100)).arg(Math.round(SystemStats.memUsage * 100))
                            color: Colors.m3onSurfaceVariant
                            font.pixelSize: Appearance.font.size.labelMedium
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: Appearance.rounding.full
                        color: Colors.m3surfaceContainerHigh

                        TextInput {
                            id: search
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: Appearance.font.main
                            font.pixelSize: 14
                            color: Colors.m3onSurface
                            clip: true
                            focus: root.open
                            onTextChanged: root.query = text

                            StyledText {
                                visible: !search.text
                                anchors.verticalCenter: parent.verticalCenter
                                text: Translation.tr("Search by name or PID")
                                color: Colors.m3onSurfaceVariant
                            }
                        }
                    }

                    RowLayout {
                        spacing: 6
                        SortChip { key: "cpu"; text: "CPU" }
                        SortChip { key: "mem"; text: "RAM" }
                        SortChip { key: "name"; text: Translation.tr("Name") }
                        SortChip { key: "pid"; text: "PID" }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: root.rows
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            width: ListView.view.width
                            height: 40
                            radius: Appearance.rounding.medium
                            color: hover.hovered ? Colors.m3surfaceContainerHigh : "transparent"

                            HoverHandler { id: hover }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 4
                                spacing: 10

                                StyledText {
                                    Layout.fillWidth: true
                                    text: row.modelData.name
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    text: row.modelData.pid
                                    color: Colors.m3onSurfaceVariant
                                    font.pixelSize: Appearance.font.size.labelSmall
                                    Layout.preferredWidth: 52
                                    horizontalAlignment: Text.AlignRight
                                }
                                StyledText {
                                    text: row.modelData.cpu.toFixed(1) + "%"
                                    Layout.preferredWidth: 52
                                    horizontalAlignment: Text.AlignRight
                                    color: row.modelData.cpu > 50 ? Colors.m3error : Colors.m3onSurface
                                }
                                StyledText {
                                    text: row.modelData.rssMiB >= 1024 ? (row.modelData.rssMiB / 1024).toFixed(1) + " GiB" : Math.round(row.modelData.rssMiB) + " MiB"
                                    Layout.preferredWidth: 72
                                    horizontalAlignment: Text.AlignRight
                                    color: Colors.m3onSurfaceVariant
                                }
                                IconButton {
                                    icon: "close"
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    onClicked: Processes.kill(row.modelData.pid, "TERM")
                                }
                                IconButton {
                                    icon: "skull"
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    iconColor: Colors.m3error
                                    onClicked: Processes.kill(row.modelData.pid, "KILL")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
