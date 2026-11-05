import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.common
import qs.common.widgets
import qs.services
import qs.modules.dock

// Dock (Config dock.*): pinned and running apps. Click: launch, or focus (cycles the app's windows).
// Middle click: a new window. Wheel over an app: its windows in turn. Right click: a menu (pin,
// move, new window, app actions, close). Icons grow toward the pointer. Auto-hide: shows when the pointer reaches the bottom, or when the workspace has no windows.
Variants {
    // One dock: on dock.monitor, or the first screen.
    model: Config.options.dock.enabled ? Quickshell.screens.filter(s => !Config.options.dock.monitor || s.name === Config.options.dock.monitor).slice(0, 1) : []

    PanelWindow {
        id: window

        required property ShellScreen modelData
        readonly property var options: Config.options.dock
        readonly property int iconSize: options.iconSize
        // No window on the workspace this screen shows.
        readonly property var monitor: Hyprland.monitorFor(modelData)
        readonly property bool workspaceEmpty: !Hyprland.toplevels.values.some(t => t.workspace?.id === monitor?.activeWorkspace?.id)
        readonly property bool shown: !options.autoHide || hover.hovered || ShellState.overviewOpen || menu.open
            || (options.showWhenEmpty && workspaceEmpty)
        readonly property int menuGap: 10
        // Which windows exist (app id + address) and the pins. A string, so it only changes when the
        // dock's contents do, not on every window title update.
        readonly property string appsKey: options.pinned.join(",") + "|" + options.showRunning + "|"
            + Hyprland.toplevels.values.map(t => `${t.wayland?.appId ?? ""}@${t.address}`).join(",")

        // Pinned ids first (in their order), then running apps that aren't pinned.
        property var apps: []
        onAppsKeyChanged: apps = buildApps()
        Component.onCompleted: apps = buildApps()
        readonly property int pinnedCount: apps.filter(a => a.pinned).length

        property var entryCache: ({})
        function entryFor(id) {
            if (!(id in entryCache))
                entryCache[id] = DesktopEntries.heuristicLookup(id);
            return entryCache[id];
        }

        function buildApps() {
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
            const extra = options.showRunning ? [...running.keys()].filter(id => !pinned.includes(id)) : [];
            const ids = [...pinned, ...extra];
            return ids.map(id => ({ id, pinned: pinned.includes(id), windows: running.get(id) ?? [], entry: entryFor(id) }));
        }

        // Focus the app's next window (step -1 for the previous one); a closed app is launched.
        function cycle(app, step) {
            if (app.windows.length === 0) {
                if (app.entry)
                    FocusBlocker.launch(app.entry);
                return;
            }
            const i = app.windows.indexOf(Hyprland.activeToplevel);
            const n = app.windows.length;
            const next = app.windows[((i < 0 ? 0 : i + step) % n + n) % n];
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${next.address}" })`);
        }
        function launch(app) {
            if (app.entry)
                FocusBlocker.launch(app.entry);
        }
        function togglePin(app) {
            const list = options.pinned.filter(id => id.toLowerCase() !== app.id);
            options.pinned = app.pinned ? list : [...list, app.id];
        }
        // Swaps a pinned app with its neighbour in the pins.
        function movePin(app, step) {
            const pins = options.pinned.slice();
            const i = pins.findIndex(id => id.toLowerCase() === app.id);
            const j = i + step;
            if (i < 0 || j < 0 || j >= pins.length)
                return;
            [pins[i], pins[j]] = [pins[j], pins[i]];
            options.pinned = pins;
        }

        function closeWindows(app) {
            for (const t of app.windows)
                Hyprland.dispatch(`hl.dsp.window.close({ window = "address:0x${t.address}" })`);
        }

        // The menu of an app, opened above its icon.
        property var menuApp: null
        property real menuX: 0
        readonly property bool menuOpen: menuApp !== null
        function openMenu(app, item) {
            const p = item.mapToItem(dock, item.width / 2, 0);
            menuX = Math.max(8, Math.min(width - menu.width - 8, dock.x + p.x - menu.width / 2));
            menuApp = app;
        }
        function closeMenu() {
            menuApp = null;
        }

        screen: modelData
        anchors.bottom: true
        exclusiveZone: options.autoHide ? 0 : dock.height + options.edgeMargin + 4
        implicitWidth: Math.max(dock.width + 40, menu.width + 16)
        implicitHeight: iconSize * 1.6 + 32 + options.edgeMargin + (menuOpen ? menu.height + menuGap : 0)
        // Only the dock (or, hidden, a thin strip at the bottom edge) and the open menu take input.
        mask: Region {
            Region { item: window.shown ? dock : trigger }
            Region { item: menu }
        }
        color: "transparent"

        WlrLayershell.namespace: "hi-shell-dock"
        WlrLayershell.layer: WlrLayer.Top

        // A click outside the menu closes it.
        HyprlandFocusGrab {
            windows: [window]
            active: window.menuOpen
            onCleared: window.closeMenu()
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

            // The pointer's x in the row (-1000 when it's not over the dock): the icons grow toward it.
            readonly property real pointerX: dockHover.hovered ? dockHover.point.position.x - row.x : -1000

            anchors.horizontalCenter: parent.horizontalCenter
            y: window.shown ? parent.height - height - window.options.edgeMargin : parent.height + 4
            width: row.implicitWidth + 20
            height: window.iconSize + 20
            radius: Math.min(window.options.cornerRadius, height / 2)
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
                spacing: window.options.spacing

                Repeater {
                    model: window.apps

                    DockItem {
                        id: dockItem
                        required property var modelData
                        required property int index
                        app: modelData
                        iconSize: window.iconSize
                        pointer: dock.pointerX
                        magnifies: window.options.magnify
                        magnifyAmount: window.options.magnifyAmount / 100
                        showIndicators: window.options.showIndicators
                        dividerAfter: window.pinnedCount > 0 && index === window.pinnedCount - 1 && window.apps.length > window.pinnedCount

                        onClicked: button => {
                            if (button === Qt.RightButton)
                                window.openMenu(app, dockItem);
                            else if (button === Qt.MiddleButton)
                                window.launch(app);
                            else
                                window.cycle(app, 1);
                            if (button !== Qt.RightButton && (app.windows.length === 0 || button === Qt.MiddleButton))
                                dockItem.bounce();
                        }
                        onWheeled: step => window.cycle(app, step)
                    }
                }
            }
        }

        DockMenu {
            id: menu
            x: window.menuX
            y: dock.y - height - window.menuGap
            visible: window.menuOpen
            app: window.menuApp
            canMoveLeft: window.menuApp?.pinned === true && window.options.pinned.findIndex(id => id.toLowerCase() === window.menuApp.id) > 0
            canMoveRight: window.menuApp?.pinned === true && window.options.pinned.findIndex(id => id.toLowerCase() === window.menuApp.id) < window.options.pinned.length - 1
            canOpen: window.menuApp?.entry !== null && window.menuApp?.entry !== undefined
            actions: window.menuApp?.entry?.actions ?? []
            windowCount: window.menuApp?.windows.length ?? 0
            onRunAction: action => {
                action.execute();
                window.closeMenu();
            }
            onCloseWindows: {
                window.closeWindows(window.menuApp);
                window.closeMenu();
            }
            onPin: {
                window.togglePin(window.menuApp);
                window.closeMenu();
            }
            onMove: step => {
                window.movePin(window.menuApp, step);
                window.closeMenu();
            }
            onOpen: {
                window.launch(window.menuApp);
                window.closeMenu();
            }
        }
    }
}
