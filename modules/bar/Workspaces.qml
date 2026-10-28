import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.common
import qs.common.widgets
import qs.services

// Workspace slots for this monitor, in groups of `bar.workspaces.shown`:
// empty = small dot, occupied = the icons of its apps, up to `appsPerWorkspace` of them and
// a "+N" for the rest (or a dot), active = sliding (or stretching) pill.
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
    contentWidth: grid.implicitWidth
    contentHeight: grid.implicitHeight

    // The active slot's edges along the bar, set by the slot itself (slots differ in length
    // with the number of icons in them).
    property real activeStart: 0
    property real activeEnd: slot

    // Hyprland 0.56+ only accepts Lua dispatchers.
    function focusWorkspace(target) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${JSON.stringify(target)} })`);
    }

    onScrolled: steps => focusWorkspace(steps > 0 ? "m-1" : "m+1")

    function workspace(id) {
        return Hyprland.workspaces.values.find(ws => ws.id === id) ?? null;
    }

    // Active indicator. Its two ends are animated on their own: when they move together it
    // slides between slots; in the "stretch" style the end it moves towards runs ahead and the
    // other one follows, so the pill stretches over the slots in between and then catches up.
    readonly property bool stretch: options.switchStyle === "stretch"

    Rectangle {
        // "head" animates fast, "tail" slowly; the pill spans both, so whichever end leads the
        // move is the fast one.
        property real headStart: root.activeStart
        property real headEnd: root.activeEnd
        property real tailStart: root.activeStart
        property real tailEnd: root.activeEnd
        readonly property real start: Math.min(headStart, tailStart)
        readonly property real length: Math.max(headEnd, tailEnd) - start

        x: root.vertical ? (parent.width - width) / 2 : grid.x + start
        y: root.vertical ? grid.y + start : (parent.height - height) / 2
        width: root.vertical ? root.slot : length
        height: root.vertical ? length : root.slot
        radius: Appearance.rounding.full
        color: Colors.m3primary

        Behavior on headStart { SpatialAnim { duration: root.stretch ? Appearance.anim.fast : Appearance.anim.slow } }
        Behavior on headEnd { SpatialAnim { duration: root.stretch ? Appearance.anim.fast : Appearance.anim.slow } }
        Behavior on tailStart { SpatialAnim { duration: root.stretch ? Appearance.anim.slow * 1.4 : Appearance.anim.slow } }
        Behavior on tailEnd { SpatialAnim { duration: root.stretch ? Appearance.anim.slow * 1.4 : Appearance.anim.slow } }
    }

    Grid {
        id: grid
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
                // The workspace's apps, one entry per app, as a string so the icons only update
                // when the apps change, not on every title change.
                readonly property string appKey: occupied ? [...new Set(ws.toplevels.values.map(t => t.wayland?.appId ?? "").filter(id => id))].join("\n") : ""
                readonly property var apps: appKey === "" ? [] : appKey.split("\n")
                readonly property int limit: Math.max(1, root.options.appsPerWorkspace)
                readonly property var icons: root.options.appIcons ? apps.slice(0, limit).map(id => AppIcons.path(id)).filter(path => path !== "") : []
                readonly property int extra: root.options.appIcons ? Math.max(0, apps.length - limit) : 0
                readonly property bool hasIcons: icons.length > 0
                readonly property int iconSize: root.slot - 8
                // Length along the bar: the icons and the "+N" with a margin, never below a slot.
                readonly property real length: hasIcons ? Math.max(root.slot, (root.vertical ? appRow.implicitHeight : appRow.implicitWidth) + 8) : root.slot

                width: root.vertical ? root.slot : length
                height: root.vertical ? length : root.slot

                Binding {
                    target: root
                    property: "activeStart"
                    value: root.vertical ? cell.y : cell.x
                    when: cell.isActive
                }
                Binding {
                    target: root
                    property: "activeEnd"
                    value: (root.vertical ? cell.y : cell.x) + cell.length
                    when: cell.isActive
                }

                Rectangle {
                    anchors.centerIn: parent
                    visible: !root.options.numbers && !cell.hasIcons
                    width: cell.isActive ? 8 : cell.occupied ? 6 : 4
                    height: width
                    radius: width / 2
                    color: cell.isActive ? Colors.m3onPrimary : cell.occupied ? Colors.m3onSurfaceVariant : Colors.m3outline
                    Behavior on width { SpatialAnim { duration: Appearance.anim.normal } }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: root.options.numbers && !cell.hasIcons
                    text: cell.wsId
                    font.pixelSize: Appearance.font.size.labelMedium
                    font.weight: cell.isActive ? Font.DemiBold : Font.Normal
                    color: cell.isActive ? Colors.m3onPrimary : cell.occupied ? Colors.m3onSurface : Colors.m3outline
                }

                Grid {
                    id: appRow
                    anchors.centerIn: parent
                    visible: cell.hasIcons
                    columns: root.vertical ? 1 : cell.icons.length + 1
                    spacing: 2
                    horizontalItemAlignment: Grid.AlignHCenter
                    verticalItemAlignment: Grid.AlignVCenter

                    Repeater {
                        model: cell.icons

                        IconImage {
                            required property string modelData
                            source: modelData
                            implicitSize: cell.iconSize
                            opacity: cell.isActive ? 1 : 0.85
                        }
                    }

                    // The apps over the limit.
                    StyledText {
                        visible: cell.extra > 0
                        text: `+${cell.extra}`
                        font.pixelSize: Appearance.font.size.labelSmall
                        font.weight: Font.DemiBold
                        color: cell.isActive ? Colors.m3onPrimary : Colors.m3onSurfaceVariant
                    }
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
