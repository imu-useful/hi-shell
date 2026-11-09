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
// Middle click: a new window. The first button opens the full-screen list of every app. Wheel over an app: its windows in turn. Right click: a menu (pin,
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
        readonly property string position: ["top", "left", "right"].includes(options.position) ? options.position : "bottom"
        readonly property bool vertical: position === "left" || position === "right"
        readonly property int edgeMargin: options.edgeMargin
        function mix(a, b, t) {
            return a + (b - a) * t;
        }
        // Which windows exist (app id + address) and the pins. A string, so it only changes when the
        // dock's contents do, not on every window title update.
        readonly property string appsKey: options.pinned.join(",") + "|" + options.showRunning + "|" + DesktopEntries.applications.values.length + "|"
            + Hyprland.toplevels.values.map(t => `${t.wayland?.appId ?? ""}@${t.address}`).join(",")

        // Pinned ids first (in their order), then running apps that aren't pinned.
        property var apps: []
        onAppsKeyChanged: apps = buildApps()
        Component.onCompleted: apps = buildApps()
        onAppsChanged: syncModel()

        // The icons' delegates live in a model of ids that is edited in place, so an icon that stays
        // keeps its item (and its animations) when another app opens, closes or is pinned.
        readonly property ListModel appIds: ListModel {}
        // The last data seen for every id: a closing delegate reads it for the moment it is still there.
        property var known: ({})
        function appFor(id) {
            return apps.find(a => a.id === id) ?? known[id];
        }
        function syncModel() {
            const ids = apps.map(a => a.id);
            for (let i = appIds.count - 1; i >= 0; i--) {
                if (!ids.includes(appIds.get(i).appId))
                    appIds.remove(i);
            }
            ids.forEach((id, i) => {
                if (i < appIds.count && appIds.get(i).appId === id)
                    return;
                let from = -1;
                for (let k = i + 1; k < appIds.count && from < 0; k++) {
                    if (appIds.get(k).appId === id)
                        from = k;
                }
                if (from >= 0)
                    appIds.move(from, i, 1);
                else
                    appIds.insert(i, { appId: id });
            });
        }
        readonly property int pinnedCount: apps.filter(a => a.pinned).length

        // The app's .desktop entry. Ids are compared without case (Happ.desktop, class "happ"), and
        // a miss isn't kept: the entries may not be loaded yet.
        // The entries are looked up when they're needed, never kept in the app data: DesktopEntries
        // rescans and replaces its entry objects, and a kept one goes dead (a click did nothing).
        property var entryCache: ({})
        property int entriesRev: 0
        Connections {
            target: DesktopEntries.applications
            function onValuesChanged() {
                window.entryCache = {};
                window.entriesRev++;
            }
        }
        function entryFor(id) {
            if (entryCache[id])
                return entryCache[id];
            const apps = DesktopEntries.applications.values;
            const entry = DesktopEntries.heuristicLookup(id)
                ?? apps.find(a => a.id.toLowerCase() === id || a.id.toLowerCase() === `${id}.desktop` || a.startupClass?.toLowerCase() === id)
                ?? apps.find(a => a.name.toLowerCase() === id)
                ?? null;
            if (entry)
                entryCache[id] = entry;
            return entry;
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
            const built = ids.map(id => ({ id, pinned: pinned.includes(id), windows: running.get(id) ?? [] }));
            for (const a of built)
                known[a.id] = a;
            return built;
        }

        // Focus the app's next window (step -1 for the previous one); a closed app is launched.
        function cycle(app, step) {
            if (app.windows.length === 0) {
                launch(app);
                return;
            }
            const i = app.windows.indexOf(Hyprland.activeToplevel);
            const n = app.windows.length;
            const next = app.windows[((i < 0 ? 0 : i + step) % n + n) % n];
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${next.address}" })`);
        }
        function launch(app) {
            const entry = entryFor(app.id);
            if (entry)
                FocusBlocker.launch(entry);
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
        readonly property var menuEntry: {
            window.entriesRev;
            return menuApp ? entryFor(menuApp.id) : null;
        }
        // The icon's centre along the dock, in the window's coordinates.
        property real menuAlong: 0
        readonly property bool menuOpen: menuApp !== null
        function openMenu(app, item) {
            const p = item.mapToItem(null, item.width / 2, item.height / 2);
            menuAlong = vertical ? p.y : p.x;
            menuApp = app;
        }
        function closeMenu() {
            menuApp = null;
        }

        screen: modelData
        anchors.bottom: position === "bottom"
        anchors.top: position === "top"
        anchors.left: position === "left"
        anchors.right: position === "right"
        exclusiveZone: options.autoHide ? 0 : (vertical ? dock.targetWidth : dock.targetHeight) + edgeMargin + 4
        implicitWidth: vertical ? iconSize * 1.6 + 32 + edgeMargin + (menuOpen ? menu.width + menuGap : 0)
            : Math.max(dock.targetWidth + 40, menu.width + 16)
        implicitHeight: vertical ? Math.max(dock.targetHeight + 40, menu.height + 16)
            : iconSize * 1.6 + 32 + edgeMargin + (menuOpen ? menu.height + menuGap : 0)
        // Only the dock (or, hidden, a thin strip at the screen edge) and the open menu take input.
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
            x: window.position === "right" ? parent.width - width : 0
            y: window.position === "bottom" ? parent.height - height : 0
            width: window.vertical ? 3 : parent.width
            height: window.vertical ? parent.height : 3
        }

        HoverHandler {
            id: hover
        }

        Rectangle {
            id: dock

            // The pointer's position along the dock (-1000 when it's not over it): the icons grow toward it.
            readonly property real pointerAlong: !dockHover.hovered ? -1000
                : window.vertical ? dockHover.point.position.y - row.y : dockHover.point.position.x - row.x
            // 0 = tucked away behind the edge, 1 = shown.
            property real reveal: window.shown ? 1 : 0
            Behavior on reveal { SpatialAnim { duration: Appearance.anim.normal } }

            x: !window.vertical ? (parent.width - width) / 2
                : window.position === "left" ? window.mix(-width - 4, window.edgeMargin, reveal)
                : window.mix(parent.width + 4, parent.width - width - window.edgeMargin, reveal)
            y: window.vertical ? (parent.height - height) / 2
                : window.position === "top" ? window.mix(-height - 4, window.edgeMargin, reveal)
                : window.mix(parent.height + 4, parent.height - height - window.edgeMargin, reveal)
            // Where the size is going: the window follows this, the dock itself glides there.
            readonly property real targetWidth: window.vertical ? window.iconSize + 20 : row.implicitWidth + 20
            readonly property real targetHeight: window.vertical ? row.implicitHeight + 20 : window.iconSize + 20
            width: targetWidth
            height: targetHeight
            Behavior on width { SpatialAnim { duration: Appearance.anim.normal } }
            Behavior on height { SpatialAnim { duration: Appearance.anim.normal } }
            radius: Math.min(window.options.cornerRadius, Math.min(width, height) / 2)
            color: Appearance.translucent(Colors.m3surfaceContainer)
            border.width: Appearance.edge
            border.color: Appearance.edgeColor

            HoverHandler {
                id: dockHover
            }

            Grid {
                id: row
                anchors.centerIn: parent
                columns: window.vertical ? 1 : Math.max(1, window.appIds.count + (window.options.appsButton ? 1 : 0))
                spacing: window.options.spacing

                // The icons slide aside for one that comes or goes.
                move: Transition {
                    SpatialAnim { properties: "x,y"; duration: Appearance.anim.normal }
                }

                DockButton {
                    visible: window.options.appsButton
                    iconSize: window.iconSize
                    pointer: dock.pointerAlong
                    position: window.position
                    magnifies: window.options.magnify
                    magnifyAmount: window.options.magnifyAmount / 100
                    onClicked: {
                        ShellState.launcherOpen = false;
                        ShellState.appGridOpen = !ShellState.appGridOpen;
                    }
                }

                Repeater {
                    model: window.appIds

                    DockItem {
                        id: dockItem
                        required property string appId
                        required property int index
                        app: window.appFor(appId)
                        entry: { window.entriesRev; return window.entryFor(appId); }
                        iconSize: window.iconSize
                        pointer: dock.pointerAlong
                        position: window.position
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
            vertical: window.vertical
            x: !window.vertical ? Math.max(8, Math.min(window.width - width - 8, window.menuAlong - width / 2))
                : window.position === "left" ? dock.x + dock.width + window.menuGap
                : dock.x - width - window.menuGap
            y: window.vertical ? Math.max(8, Math.min(window.height - height - 8, window.menuAlong - height / 2))
                : window.position === "top" ? dock.y + dock.height + window.menuGap
                : dock.y - height - window.menuGap
            position: window.position
            app: window.menuApp
            canMoveLeft: window.menuApp?.pinned === true && window.options.pinned.findIndex(id => id.toLowerCase() === window.menuApp.id) > 0
            canMoveRight: window.menuApp?.pinned === true && window.options.pinned.findIndex(id => id.toLowerCase() === window.menuApp.id) < window.options.pinned.length - 1
            canOpen: menuEntry !== null
            actions: menuEntry?.actions ?? []
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
