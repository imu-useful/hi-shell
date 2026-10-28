import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.common
import qs.common.widgets

// Alt+Tab window switcher: windows in most-recently-used order with previews.
// Hold Alt and press Tab (Shift+Tab back), let go of Alt to switch. A quick tap
// switches to the previous window without showing anything. Driven by
// hypr/hi-shell/keybinds.lua: `qs -c hi-shell ipc call switcher next` (prev, commit, cancel).
Scope {
    id: root

    property bool active: false // between the first Tab and releasing Alt
    property bool shown: false // the panel, after a short delay
    property var windows: [] // [{ address, appId, title, workspace }], most recent first
    property int index: 0
    property bool loading: false
    property int pendingSteps: 0 // Tabs pressed before the list arrived
    property bool pendingCommit: false

    function step(delta) {
        if (!active) {
            active = true;
            index = 0;
            pendingSteps = delta;
            pendingCommit = false;
            loading = true;
            clients.running = true;
            showDelay.restart();
            return;
        }
        if (loading) {
            pendingSteps += delta;
            return;
        }
        if (windows.length)
            index = (index + delta + windows.length) % windows.length;
    }

    function commit() {
        if (!active)
            return;
        if (loading) {
            pendingCommit = true;
            return;
        }
        const w = windows[index];
        const wasShown = shown;
        close();
        if (!w)
            return;
        const code = `hl.dsp.focus({ window = "address:${w.address}" })`;
        // While the panel holds the keyboard (exclusive focus) Hyprland ignores a focus request:
        // wait until it has let go.
        if (wasShown) {
            focusLater.code = code;
            focusLater.restart();
        } else {
            Hyprland.dispatch(code);
        }
    }

    function close() {
        active = shown = loading = false;
        showDelay.stop();
    }

    // Live Wayland handle for a window's preview (Quickshell's address has no 0x).
    function toplevel(address) {
        return Hyprland.toplevels.values.find(t => `0x${t.address}` === address)?.wayland ?? null;
    }

    property var iconCache: ({})
    function icon(appId) {
        if (!appId)
            return "";
        if (!(appId in iconCache)) {
            const entry = DesktopEntries.heuristicLookup(appId);
            iconCache[appId] = Quickshell.iconPath(entry?.icon ?? appId, true);
        }
        return iconCache[appId];
    }

    Timer {
        id: focusLater
        property string code: ""
        interval: 80
        onTriggered: Hyprland.dispatch(code)
    }

    Timer {
        id: showDelay
        interval: 150
        onTriggered: if (root.active) root.shown = true
    }

    Process {
        id: clients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = JSON.parse(text)
                        .filter(c => c.mapped && !c.hidden && c.workspace.id !== -1)
                        .sort((a, b) => a.focusHistoryID - b.focusHistoryID)
                        .map(c => ({ address: c.address, appId: c.class, title: c.title, workspace: c.workspace.name }));
                } catch (e) {}
                root.windows = list;
                root.loading = false;
                const n = list.length;
                root.index = n ? ((root.pendingSteps % n) + n) % n : 0;
                if (root.pendingCommit)
                    root.commit();
                else if (n === 0)
                    root.close();
            }
        }
    }

    IpcHandler {
        target: "switcher"

        function next(): void {
            root.step(1);
        }
        function prev(): void {
            root.step(-1);
        }
        function commit(): void {
            root.commit();
        }
        function cancel(): void {
            root.close();
        }
    }

    PanelLoader {
        id: loader
        shown: root.shown

        PanelWindow {
            id: window

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            WlrLayershell.namespace: "hi-shell-switcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // Keys while the panel has focus (Alt itself is released through Hyprland).
            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape)
                        root.close();
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        root.commit();
                    else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down)
                        root.step(1);
                    else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up)
                        root.step(-1);
                    else
                        return;
                    event.accepted = true;
                }
            }

            // Click outside the card cancels.
            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }

            Rectangle {
                id: card

                readonly property int columns: Math.min(root.windows.length, 5)
                readonly property int tileWidth: 232

                anchors.centerIn: parent
                width: grid.implicitWidth + 32
                height: grid.implicitHeight + 32
                radius: Appearance.rounding.extraLarge
                color: Appearance.translucent(Colors.m3surfaceContainerLow)
                border.width: 1
                border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)

                opacity: loader.revealed ? 1 : 0
                scale: loader.revealed ? 1 : 0.85
                Behavior on opacity { EffectAnim { duration: Appearance.anim.fast } }
                Behavior on scale { SpringAnim {} }

                MouseArea {
                    anchors.fill: parent // keep clicks on the card from cancelling
                }

                GridLayout {
                    id: grid
                    anchors.centerIn: parent
                    columns: Math.max(1, card.columns)
                    columnSpacing: 10
                    rowSpacing: 10

                    Repeater {
                        model: root.windows

                        Rectangle {
                            id: tile
                            required property var modelData
                            required property int index
                            readonly property bool selected: index === root.index

                            implicitWidth: card.tileWidth
                            implicitHeight: 196
                            radius: Appearance.rounding.large
                            color: selected ? Colors.m3secondaryContainer : "transparent"
                            border.width: selected ? 2 : 0
                            border.color: Colors.m3primary
                            Behavior on color { ColorAnim { duration: Appearance.anim.fast } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                // Preview, letterboxed in a fixed box.
                                ClippingRectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 128
                                    radius: Appearance.rounding.medium
                                    color: Colors.m3surfaceContainerHighest

                                    ScreencopyView {
                                        anchors.centerIn: parent
                                        width: parent.width
                                        height: parent.height
                                        captureSource: root.shown ? root.toplevel(tile.modelData.address) : null
                                        live: false
                                        constraintSize: Qt.size(width * 2, height * 2)
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    IconImage {
                                        implicitSize: 24
                                        source: root.icon(tile.modelData.appId)
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: tile.modelData.title || tile.modelData.appId
                                            elide: Text.ElideRight
                                            font.weight: tile.selected ? Font.Medium : Font.Normal
                                            color: tile.selected ? Colors.m3onSecondaryContainer : Colors.m3onSurface
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: `${tile.modelData.appId} · ${tile.modelData.workspace}`
                                            elide: Text.ElideRight
                                            font.pixelSize: Appearance.font.size.labelSmall
                                            color: Colors.m3onSurfaceVariant
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.index = tile.index;
                                    root.commit();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
