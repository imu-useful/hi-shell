import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.common
import qs.common.widgets

// Dock (Config dock.*): pinned and running apps with window dots and hover
// magnification. Click = launch or focus (cycles windows), middle click = new
// window, right click = pin / unpin. Auto-hide: shows when the pointer
// reaches the bottom edge.
Variants {
    // One dock: on dock.monitor, or the first screen.
    model: Config.options.dock.enabled ? Quickshell.screens.filter(s => !Config.options.dock.monitor || s.name === Config.options.dock.monitor).slice(0, 1) : []

    PanelWindow {
        id: window

        required property ShellScreen modelData
        readonly property var options: Config.options.dock
        readonly property int iconSize: options.iconSize
        readonly property bool shown: !options.autoHide || hover.hovered || ShellState.overviewOpen

        // Pinned ids first, then running apps that aren't pinned.
        readonly property var apps: {
            const running = new Map();
            for (const t of Hyprland.toplevels.values) {
                const id = (t.wayland?.appId ?? "").toLowerCase();
                if (!id)
                    continue;
                if (!running.has(id))
                    running.set(id, []);
                running.get(id).push(t);
            }
            const pinned = options.pinned.map(id => id.toLowerCase());
            const ids = [...pinned, ...[...running.keys()].filter(id => !pinned.includes(id))];
            return ids.map(id => ({ id, pinned: pinned.includes(id), windows: running.get(id) ?? [], entry: DesktopEntries.heuristicLookup(id) }));
        }

        screen: modelData
        anchors.bottom: true
        exclusiveZone: options.autoHide ? 0 : dock.height + 12
        implicitWidth: dock.width + 40
        implicitHeight: iconSize * 1.6 + 40
        // Only the dock (or, hidden, a thin strip at the bottom edge) takes input.
        mask: Region { item: window.shown ? dock : trigger }
        color: "transparent"

        WlrLayershell.namespace: "hi-shell-dock"
        WlrLayershell.layer: WlrLayer.Top

        function activate(app) {
            if (app.windows.length === 0) {
                app.entry?.execute();
                return;
            }
            // Cycle through the app's windows, starting after the focused one.
            const active = Hyprland.activeToplevel;
            const i = app.windows.indexOf(active);
            const next = app.windows[(i + 1) % app.windows.length];
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${next.address}" })`);
        }
        function togglePin(app) {
            const list = options.pinned.filter(id => id.toLowerCase() !== app.id);
            options.pinned = app.pinned ? list : [...list, app.id];
        }

        Item {
            id: trigger
            anchors.bottom: parent.bottom
            width: parent.width
            height: 3
        }

        HoverHandler {
            id: hover
        }

        Rectangle {
            id: dock

            readonly property real mouseX: dockHover.hovered ? dockHover.point.position.x : -1000

            anchors.horizontalCenter: parent.horizontalCenter
            y: window.shown ? parent.height - height - 8 : parent.height + 4
            width: row.implicitWidth + 20
            height: window.iconSize + 20
            radius: Appearance.rounding.extraLarge
            color: Appearance.translucent(Colors.m3surfaceContainer)
            border.width: 1
            border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)

            Behavior on y { SpatialAnim { duration: Appearance.anim.normal } }

            HoverHandler {
                id: dockHover
            }

            Row {
                id: row
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Repeater {
                    model: window.apps

                    Item {
                        id: item

                        required property var modelData
                        // Magnification by distance from the pointer.
                        readonly property real center: x + width / 2
                        readonly property real distance: Math.abs(dock.mouseX - row.x - center)
                        readonly property real magnify: window.options.magnify ? Math.max(0, 1 - distance / (window.iconSize * 2.5)) * 0.45 : 0
                        readonly property real size: window.iconSize * (1 + magnify)

                        width: size
                        height: window.iconSize
                        Behavior on width { NumberAnimation { duration: 90 } }

                        IconImage {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            implicitSize: item.size
                            source: Quickshell.iconPath(item.modelData.entry?.icon ?? item.modelData.id, "application-x-executable")
                        }

                        // Open-window dots
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.bottom
                            anchors.topMargin: 3
                            spacing: 3
                            Repeater {
                                model: Math.min(3, item.modelData.windows.length)
                                Rectangle {
                                    width: item.modelData.windows.includes(Hyprland.activeToplevel) ? 10 : 5
                                    height: 4
                                    radius: 2
                                    color: Colors.m3primary
                                }
                            }
                        }

                        MouseArea {
                            id: area
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton)
                                    window.togglePin(item.modelData);
                                else if (mouse.button === Qt.MiddleButton)
                                    item.modelData.entry?.execute();
                                else
                                    window.activate(item.modelData);
                            }
                        }

                        StyledPopup {
                            target: item
                            hovered: area.containsMouse
                            edge: Edges.Top
                            openDelay: 400
                            padding: 10
                            StyledText {
                                text: `${item.modelData.entry?.name ?? item.modelData.id}${item.modelData.pinned ? "" : " · right click to pin"}`
                            }
                        }
                    }
                }
            }
        }
    }
}
