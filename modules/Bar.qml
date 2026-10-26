import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.modules.bar

// The bar, one per screen (Variants in shell.qml). Layout, position and style
// come from Config bar.*: widget ids in left / center / right, position
// top | bottom | left | right, style hug | float | islands | m3.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property var options: Config.options.bar
    readonly property string position: ["top", "bottom", "left", "right"].includes(options.position) ? options.position : "top"
    readonly property string style: ["hug", "float", "islands", "m3"].includes(options.style) ? options.style : "float"
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
        divider: divider
    })

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

    readonly property color barColor: Appearance.translucent(style === "m3" ? Colors.m3surfaceContainer : Colors.m3surface)

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
        opacity: root.intro
        transform: Translate {
            x: root.vertical ? root.introShift : 0
            y: root.vertical ? 0 : root.introShift
        }

        Rectangle {
            anchors.fill: parent
            visible: root.style !== "islands"
            radius: root.edgeToEdge ? 0 : Appearance.rounding.full
            color: root.barColor
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
                bar: root.context
                widgets: root.options.left
                registry: root.registry
                // Fill up to the centered section; elidable widgets shrink.
                width: root.vertical ? content.width : Math.min(implicitWidth, Math.max(0, content.centerStart - 12))
                height: root.vertical ? Math.min(implicitHeight, Math.max(0, content.centerStart - 12)) : content.height
            }

            BarSection {
                id: center
                bar: root.context
                widgets: root.options.center
                registry: root.registry
                x: root.vertical ? 0 : (content.width - width) / 2
                y: root.vertical ? (content.height - height) / 2 : 0
                width: root.vertical ? content.width : Math.min(implicitWidth, content.width)
                height: root.vertical ? Math.min(implicitHeight, content.height) : content.height
            }

            BarSection {
                id: right
                bar: root.context
                widgets: root.options.right
                registry: root.registry
                width: root.vertical ? content.width : Math.min(implicitWidth, Math.max(0, content.length - content.centerEnd - 12))
                height: root.vertical ? Math.min(implicitHeight, Math.max(0, content.length - content.centerEnd - 12)) : content.height
                x: root.vertical ? 0 : content.width - width
                y: root.vertical ? content.height - height : 0
            }

            // Islands style: one pill behind each non-empty section.
            Repeater {
                model: root.style === "islands" ? [left, center, right] : []

                Rectangle {
                    required property var modelData
                    visible: modelData.widgets.length > 0 && (root.vertical ? modelData.height : modelData.width) > 0
                    x: modelData.x - 4
                    y: modelData.y - 4
                    width: modelData.width + 8
                    height: modelData.height + 8
                    z: -1
                    radius: Appearance.rounding.full
                    color: root.barColor
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
            opacity: root.intro
            transform: Translate {
                x: root.vertical ? root.introShift : 0
                y: root.vertical ? 0 : root.introShift
            }
        }
    }
}
