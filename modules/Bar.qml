import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.modules.bar
import qs.services as Services
import "settings/BarWidgets.js" as BarWidgets

// One bar window (Variants in shell.qml makes the main bar for every screen and any extra bars). Layout, position and style
// come from Config bar.*: widget ids in left / center / right, position
// top | bottom | left | right, style hug | float | islands | m3.
PanelWindow {
    id: root

    // { screen: name, barId: "main" or the id of an extra bar }, see services/BarLayout.qml
    required property var modelData
    screen: Quickshell.screens.find(s => s.name === modelData.screen) ?? null

    // This bar's settings: the defaults of Config bar.*, with the screen's (or the extra bar's) own on top.
    readonly property var options: Services.BarLayout.spec(modelData.screen, modelData.barId)
    // The widget lists only change when their contents do: a new height or style leaves the widgets alone.
    property var leftIds: []
    property var centerIds: []
    property var rightIds: []
    function syncLists() {
        for (const [prop, key] of [["leftIds", "left"], ["centerIds", "center"], ["rightIds", "right"]]) {
            if (JSON.stringify(root[prop]) !== JSON.stringify(options[key]))
                root[prop] = options[key];
        }
    }
    onOptionsChanged: syncLists()
    Component.onCompleted: syncLists()

    readonly property string position: options.position
    readonly property string style: options.style
    readonly property bool vertical: position === "left" || position === "right"
    readonly property bool edgeToEdge: style === "hug" || style === "m3"
    readonly property int thickness: options.height
    readonly property int margin: edgeToEdge ? 0 : options.margin
    // Concave "screen corners" under an edge-to-edge bar.
    readonly property int cornerSize: edgeToEdge ? Appearance.rounding.large : 0

    // Shared with every widget (BarWidget.bar).
    readonly property QtObject context: QtObject {
        readonly property bool vertical: root.vertical
        readonly property string style: root.style
        readonly property int thickness: root.thickness
        readonly property var screen: root.screen
        readonly property int popupEdge: root.position === "top" ? Edges.Bottom : root.position === "bottom" ? Edges.Top : root.position === "left" ? Edges.Right : Edges.Left

        // Edit mode: dragging a widget (BarSection's overlay calls these).
        function dragStart(section, index, id, item) { root.beginDrag(section, index, id, item); }
        function dragMove(item, x, y) { root.moveDrag(item, x, y); }
        function dragEnd() { root.endDrag(); }
        function dragCancel() { root.dragInfo = null; }
    }

    readonly property var registry: ({
        launcher: launcher,
        workspaces: workspaces,
        activeWindow: activeWindow,
        media: media,
        resources: resources,
        clock: clock,
        weather: weather,
        tray: tray,
        systemIcons: systemIcons,
        utilButtons: utilButtons,
        networkSpeed: networkSpeed,
        battery: battery,
        updates: updates,
        keyboardLayout: keyboardLayout,
        power: power,
        notifications: notifications,
        visualizer: visualizer,
        divider: divider,
        focus: focus,
        zoneClock: zoneClock,
        script: script
    })

    // The Dynamic Island (the clock widget) takes the bar over while it shows music or a notification:
    // the other widgets go towards it and fade out, and come back after.
    readonly property bool compact: Services.Island.compact && hasClock && !ShellState.barEdit
    property real collapse: compact ? 1 : 0
    Behavior on collapse {
        NumberAnimation { duration: Appearance.anim.slow; easing.type: Easing.InOutCubic }
    }
    // The island's place in the bar (content coordinates): the bar's background narrows to it.
    readonly property var islandSec: islandSection === "left" ? left : islandSection === "center" ? center : islandSection === "right" ? right : null
    readonly property Item islandLoader: islandSec?.islandLoader ?? null
    readonly property bool islandKnown: islandLoader !== null && islandLoader.width > 0
    readonly property real islandX: islandKnown ? content.x + islandSec.x + islandLoader.x : 0
    readonly property real islandY: islandKnown ? content.y + islandSec.y + islandLoader.y : 0
    readonly property real islandW: islandKnown ? islandLoader.width : 0
    readonly property real islandH: islandKnown ? islandLoader.height : 0
    readonly property real narrow: islandKnown ? collapse : 0
    // Which section holds the clock, and where (index in it).
    readonly property string islandSection: leftIds.includes("clock") ? "left" : centerIds.includes("clock") ? "center" : rightIds.includes("clock") ? "right" : ""

    // Focus Mode keeps only workspaces, system icons and the clock, with the session's
    // timer next to the clock (or in the middle if the bar has no clock).
    readonly property var zenWidgets: ["workspaces", "systemIcons", "clock"]
    readonly property bool hasClock: [...leftIds, ...centerIds, ...rightIds].includes("clock")
    function section(widgets, middle) {
        if (!ShellState.zen)
            return widgets;
        const out = [];
        for (const w of widgets) {
            if (zenWidgets.includes(w))
                out.push(w);
            if (w === "clock")
                out.push("focus");
        }
        if (middle && !hasClock)
            out.push("focus");
        return out;
    }

    // --- Edit mode: drag widgets between and within the sections, or off the bar to remove them ---
    // dragInfo: { section, index, id } of the widget being dragged; dropSection / dropIndex / dropRemove: where it
    // would land (set while moving), dragX / dragY: the pointer in `content` coordinates.
    property var dragInfo: null
    property string dropSection: ""
    property int dropIndex: -1
    property bool dropRemove: false
    property real dragX: 0
    property real dragY: 0
    readonly property var sectionItems: ({ left: left, center: center, right: right })
    readonly property var sectionIds: ({ left: leftIds, center: centerIds, right: rightIds })

    function beginDrag(section, index, id, item) {
        dragInfo = { section, index, id };
        dropSection = section;
        dropIndex = index;
        dropRemove = false;
    }

    function moveDrag(item, mx, my) {
        if (!dragInfo)
            return;
        const p = item.mapToItem(content, mx, my);
        dragX = p.x;
        dragY = p.y;
        const along = vertical ? p.y : p.x;
        const across = vertical ? p.x : p.y;
        const span = vertical ? content.height : content.width;
        const thick = vertical ? content.width : content.height;
        const key = along < span / 3 ? "left" : along < span * 2 / 3 ? "center" : "right";
        const sec = sectionItems[key];
        let idx = sectionIds[key].length;
        for (let i = 0; i < sec.repeater.count; i++) {
            const it = sec.repeater.itemAt(i);
            if (!it || !it.visible || (key === dragInfo.section && i === dragInfo.index))
                continue;
            const c = it.mapToItem(content, it.width / 2, it.height / 2);
            if ((vertical ? c.y : c.x) > along) {
                idx = i;
                break;
            }
        }
        dropSection = key;
        dropIndex = idx;
        dropRemove = across < -thick * 0.8 || across > thick * 1.8;
    }

    function endDrag() {
        const info = dragInfo;
        dragInfo = null;
        if (!info)
            return;
        const lists = { left: [...leftIds], center: [...centerIds], right: [...rightIds] };
        lists[info.section].splice(info.index, 1);
        if (!dropRemove) {
            let at = dropIndex;
            if (dropSection === info.section && at > info.index)
                at--;
            lists[dropSection].splice(Math.max(0, Math.min(at, lists[dropSection].length)), 0, info.id);
        }
        for (const key of ["left", "center", "right"]) {
            if (JSON.stringify(lists[key]) !== JSON.stringify(sectionIds[key]))
                Services.BarLayout.writeList(modelData.screen, modelData.barId, key, lists[key]);
        }
    }

    Component { id: launcher; LauncherButton {} }
    Component { id: workspaces; Workspaces {} }
    Component { id: activeWindow; ActiveWindow {} }
    Component { id: media; Media {} }
    Component { id: resources; Resources {} }
    Component { id: clock; Clock {} }
    Component { id: weather; WeatherWidget {} }
    Component { id: tray; TrayWidget {} }
    Component { id: systemIcons; SystemIcons {} }
    Component { id: utilButtons; UtilButtons {} }
    Component { id: networkSpeed; NetworkSpeed {} }
    Component { id: battery; BatteryWidget {} }
    Component { id: updates; UpdatesWidget {} }
    Component { id: keyboardLayout; KeyboardLayout {} }
    Component { id: power; PowerButton {} }
    Component { id: notifications; NotificationsWidget {} }
    Component { id: visualizer; Visualizer {} }
    Component { id: divider; Divider {} }
    Component { id: focus; FocusWidget {} }
    Component { id: zoneClock; ZoneClock {} }
    Component { id: script; ScriptWidget {} }

    anchors.top: position !== "bottom"
    anchors.bottom: position !== "top"
    anchors.left: position !== "right"
    anchors.right: position !== "left"

    // The window also covers the screen corners; only the bar reserves space and takes input.
    visible: !ShellState.barHidden
    exclusiveZone: thickness + margin
    implicitWidth: thickness + margin + cornerSize
    implicitHeight: thickness + margin + cornerSize
    mask: Region { item: barArea }
    color: "transparent"

    WlrLayershell.namespace: "hi-shell-bar"
    WlrLayershell.layer: WlrLayer.Top

    readonly property color barColor: Appearance.translucent(style === "m3" ? Colors.m3surfaceContainer : Colors.m3surfaceContainerLow)

    // Startup: the bar slides in from its edge with a spring.
    property real intro: ShellState.started ? 1 : 0
    Behavior on intro {
        SpringAnim { overshoot: 1.2; duration: Appearance.anim.spatial * 1.4 }
    }
    readonly property real introShift: (1 - intro) * (thickness + margin + 8) * (position === "top" || position === "left" ? -1 : 1)

    // Bar area: the strip along the edge, inset by the margin when floating.
    Item {
        id: barArea

        x: root.position === "right" ? parent.width - root.thickness - root.margin : root.margin
        y: root.position === "bottom" ? parent.height - root.thickness - root.margin : root.margin
        width: root.vertical ? root.thickness : parent.width - root.margin * 2
        height: root.vertical ? parent.height - root.margin * 2 : root.thickness

        // Moved by the startup animation. The input mask follows barArea itself,
        // which stays put: a transform on it isn't seen by the mask, which then
        // stayed where the bar was at the start of the slide (off screen).
        Item {
            id: barContent
            anchors.fill: parent
            opacity: root.intro
            transform: Translate {
                x: root.vertical ? root.introShift : 0
                y: root.vertical ? 0 : root.introShift
            }

            // The bar's own background; while the island has the bar to itself it narrows to the island.
            Rectangle {
                readonly property real pad: 6
                x: root.vertical ? 0 : root.narrow * (root.islandX - pad)
                y: root.vertical ? root.narrow * (root.islandY - pad) : 0
                width: root.vertical ? parent.width : parent.width + root.narrow * (root.islandW + pad * 2 - parent.width)
                height: root.vertical ? parent.height + root.narrow * (root.islandH + pad * 2 - parent.height) : parent.height
                visible: root.style !== "islands"
                transform: Translate { y: Services.Island.drop }
                radius: (root.edgeToEdge ? 0 : Appearance.rounding.full) * (1 - root.narrow) + Math.min(width, height) / 2 * root.narrow
                color: root.barColor
            }

            // Right click on the empty part of the bar opens its settings; the widgets sit above
            // this and keep their own clicks.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: {
                    ShellState.settingsPage = "bar";
                    ShellState.settingsOpen = true;
                }
            }

            Item {
                id: content

                anchors.fill: parent
                anchors.margins: 6
                anchors.leftMargin: root.vertical ? 6 : 8
                anchors.rightMargin: root.vertical ? 6 : 8

                readonly property real centerStart: root.vertical ? center.y : center.x
                readonly property real centerEnd: root.vertical ? center.y + center.height : center.x + center.width
                readonly property real length: root.vertical ? height : width

                BarSection {
                    id: left
                    key: "left"
                    bar: root.context
                    widgets: root.section(root.leftIds, false)
                    registry: root.registry
                    collapse: root.collapse
                    side: root.islandSection === "" || root.islandSection === "left" ? 0 : (0 < ["left", "center", "right"].indexOf(root.islandSection) ? -1 : 1)
                    islandIndex: root.islandSection === "left" ? widgets.indexOf("clock") : -1
                    // Fill up to the centered section; elidable widgets shrink.
                    width: root.vertical ? content.width : Math.min(implicitWidth, Math.max(0, content.centerStart - 12))
                    height: root.vertical ? Math.min(implicitHeight, Math.max(0, content.centerStart - 12)) : content.height
                }

                BarSection {
                    id: center
                    key: "center"
                    bar: root.context
                    widgets: root.section(root.centerIds, true)
                    registry: root.registry
                    collapse: root.collapse
                    side: root.islandSection === "" || root.islandSection === "center" ? 0 : (1 < ["left", "center", "right"].indexOf(root.islandSection) ? -1 : 1)
                    islandIndex: root.islandSection === "center" ? widgets.indexOf("clock") : -1
                    x: root.vertical ? 0 : (content.width - width) / 2
                    y: root.vertical ? (content.height - height) / 2 : 0
                    width: root.vertical ? content.width : Math.min(implicitWidth, content.width)
                    height: root.vertical ? Math.min(implicitHeight, content.height) : content.height
                }

                BarSection {
                    id: right
                    key: "right"
                    bar: root.context
                    widgets: root.section(root.rightIds, false)
                    registry: root.registry
                    collapse: root.collapse
                    side: root.islandSection === "" || root.islandSection === "right" ? 0 : (2 < ["left", "center", "right"].indexOf(root.islandSection) ? -1 : 1)
                    islandIndex: root.islandSection === "right" ? widgets.indexOf("clock") : -1
                    width: root.vertical ? content.width : Math.min(implicitWidth, Math.max(0, content.length - content.centerEnd - 12))
                    height: root.vertical ? Math.min(implicitHeight, Math.max(0, content.length - content.centerEnd - 12)) : content.height
                    x: root.vertical ? 0 : content.width - width
                    y: root.vertical ? content.height - height : 0
                }

                // Edit mode: the three drop zones, where the widget would land, and the widget under the pointer.
                Repeater {
                    model: ShellState.barEdit ? ["left", "center", "right"] : []

                    Rectangle {
                        required property string modelData
                        required property int index
                        z: 50
                        x: root.vertical ? 0 : content.width * index / 3
                        y: root.vertical ? content.height * index / 3 : 0
                        width: root.vertical ? content.width : content.width / 3
                        height: root.vertical ? content.height / 3 : content.height
                        radius: Appearance.rounding.medium
                        color: "transparent"
                        border.width: root.dragInfo && root.dropSection === modelData && !root.dropRemove ? 2 : 1
                        border.color: Qt.alpha(Colors.m3tertiary, root.dragInfo && root.dropSection === modelData && !root.dropRemove ? 0.9 : 0.35)
                    }
                }
                // The insertion point.
                Rectangle {
                    readonly property var sec: root.sectionItems[root.dropSection] ?? null
                    readonly property var ref: sec && root.dropIndex >= 0 && root.dropIndex < sec.repeater.count ? sec.repeater.itemAt(root.dropIndex) : null
                    visible: root.dragInfo !== null && !root.dropRemove && sec !== null
                    z: 60
                    color: Colors.m3tertiary
                    radius: 1
                    width: root.vertical ? content.width - 8 : 3
                    height: root.vertical ? 3 : content.height - 8
                    x: root.vertical ? 4 : (ref ? ref.mapToItem(content, 0, 0).x - 5 : sec ? sec.mapToItem(content, sec.width, 0).x + 2 : 0)
                    y: root.vertical ? (ref ? ref.mapToItem(content, 0, 0).y - 5 : sec ? sec.mapToItem(content, 0, sec.height).y + 2 : 0) : 4
                }
                Rectangle {
                    visible: root.dragInfo !== null
                    z: 70
                    x: root.dragX - width / 2
                    y: root.dragY - height / 2
                    width: ghostRow.implicitWidth + 20
                    height: 30
                    radius: Appearance.rounding.full
                    color: root.dropRemove ? Colors.m3errorContainer : Colors.m3primaryContainer
                    opacity: 0.92

                    Row {
                        id: ghostRow
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialIcon {
                            icon: root.dropRemove ? "delete" : (BarWidgets.icons[(root.dragInfo?.id ?? "").split("#")[0]] ?? "widgets")
                            iconSize: 16
                            color: root.dropRemove ? Colors.m3onErrorContainer : Colors.m3onPrimaryContainer
                        }
                        StyledText {
                            text: BarWidgets.names[root.dragInfo?.id ?? ""] ? Translation.tr(BarWidgets.names[root.dragInfo.id]) : (root.dragInfo?.id ?? "")
                            font.pixelSize: Appearance.font.size.labelMedium
                            color: root.dropRemove ? Colors.m3onErrorContainer : Colors.m3onPrimaryContainer
                        }
                    }
                }

                // Islands style: one pill behind each non-empty section.
                Repeater {
                    model: root.style === "islands" ? [left, center, right] : []

                    Rectangle {
                        required property var modelData
                        visible: modelData.widgets.length > 0 && (root.vertical ? modelData.height : modelData.width) > 2
                        x: modelData.x - 4
                        y: modelData.y - 4
                        width: modelData.width + 8
                        height: modelData.height + 8
                        z: -1
                        radius: Appearance.rounding.full
                        color: root.barColor
                        // The island's own pill bounces with it.
                        transform: Translate { y: modelData === root.islandSec ? Services.Island.drop : 0 }
                    }
                }
            }
        }
    }

    // Concave corners where an edge-to-edge bar meets the screen sides.
    Repeater {
        model: root.cornerSize > 0 ? 2 : 0

        ScreenCorner {
            required property int index
            readonly property bool second: index === 1
            x: root.vertical ? (root.position === "left" ? root.thickness : 0) : (second ? parent.width - width : 0)
            y: root.vertical ? (second ? parent.height - height : 0) : (root.position === "top" ? root.thickness : 0)
            flipX: root.vertical ? root.position === "right" : second
            flipY: root.vertical ? second : root.position === "bottom"
            size: root.cornerSize
            color: root.barColor
            opacity: root.intro * (1 - root.collapse)
            transform: Translate {
                x: root.vertical ? root.introShift : 0
                y: root.vertical ? 0 : root.introShift
            }
        }
    }
}
