import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.common
import qs.common.widgets

// Workspace slots for this monitor, in groups of `bar.workspaces.shown`:
// empty = small dot, occupied = app icon (or dot), active = sliding pill.
// Click to switch, scroll to move to the previous / next workspace.
BarWidget {
    id: root

    readonly property var options: Config.options.bar.workspaces
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(bar?.screen ?? null)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    readonly property int shown: Math.max(1, options.shown)
    readonly property int first: Math.floor((Math.max(1, activeId) - 1) / shown) * shown + 1
    readonly property int slot: thickness - 6

    padding: 3
    scrollable: true
    contentWidth: shown * slot
    contentHeight: shown * slot

    // Hyprland 0.56+ only accepts Lua dispatchers.
    function focusWorkspace(target) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${JSON.stringify(target)} })`);
    }

    onScrolled: steps => focusWorkspace(steps > 0 ? "m-1" : "m+1")

    function workspace(id) {
        return Hyprland.workspaces.values.find(ws => ws.id === id) ?? null;
    }

    // appId -> icon path. heuristicLookup is a fuzzy search over every desktop
    // entry, too slow to repeat on each window change (titles update often).
    property var iconCache: ({})
    function appIcon(appId) {
        if (!appId)
            return "";
        if (!(appId in iconCache)) {
            const entry = DesktopEntries.heuristicLookup(appId);
            iconCache[appId] = Quickshell.iconPath(entry?.icon ?? appId, true);
        }
        return iconCache[appId];
    }

    // Active indicator, slides between slots.
    Rectangle {
        readonly property int index: Math.max(0, Math.min(root.shown - 1, root.activeId - root.first))
        x: root.vertical ? (parent.width - width) / 2 : index * root.slot
        y: root.vertical ? index * root.slot : (parent.height - height) / 2
        width: root.slot
        height: root.slot
        radius: Appearance.rounding.full
        color: Colors.m3primary

        Behavior on x { SpatialAnim { duration: Appearance.anim.slow } }
        Behavior on y { SpatialAnim { duration: Appearance.anim.slow } }
    }

    Grid {
        anchors.centerIn: parent
        columns: root.vertical ? 1 : root.shown

        Repeater {
            model: root.shown

            Item {
                id: cell

                required property int index
                readonly property int wsId: root.first + index
                readonly property var ws: root.workspace(wsId)
                readonly property bool occupied: (ws?.toplevels.values.length ?? 0) > 0
                readonly property bool isActive: wsId === root.activeId
                // A string, so the icon only updates when the app changes, not on every title change.
                readonly property string appId: occupied ? (ws.toplevels.values[0]?.wayland?.appId ?? "") : ""
                readonly property string icon: root.options.appIcons ? root.appIcon(appId) : ""

                width: root.slot
                height: root.slot

                Rectangle {
                    anchors.centerIn: parent
                    visible: !root.options.numbers && cell.icon === ""
                    width: cell.isActive ? 8 : cell.occupied ? 6 : 4
                    height: width
                    radius: width / 2
                    color: cell.isActive ? Colors.m3onPrimary : cell.occupied ? Colors.m3onSurfaceVariant : Colors.m3outline
                    Behavior on width { SpatialAnim { duration: Appearance.anim.normal } }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: root.options.numbers && cell.icon === ""
                    text: cell.wsId
                    font.pixelSize: Appearance.font.size.labelMedium
                    font.weight: cell.isActive ? Font.DemiBold : Font.Normal
                    color: cell.isActive ? Colors.m3onPrimary : cell.occupied ? Colors.m3onSurface : Colors.m3outline
                }

                IconImage {
                    anchors.centerIn: parent
                    visible: cell.icon !== ""
                    source: cell.icon
                    implicitSize: root.slot - 8
                    opacity: cell.isActive ? 1 : 0.85
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.focusWorkspace(cell.wsId)
                }
            }
        }
    }
}
