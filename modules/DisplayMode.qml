import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.services

// Display mode picker (the laptop's display key, XF86Display, like Win+P):
// this screen only, duplicate, extend right / left, second screen only.
// Pressing the key again moves to the next mode; Enter or a click applies, Esc closes.
// IPC: `qs -c hi-shell ipc call display toggle` (next, set internal|mirror|right|left|external).
//
// "Second screen only" turns the laptop panel off for this session only (it isn't saved),
// and if every screen goes away (cable pulled) the panel comes back on by itself.
Scope {
    id: root

    property bool open: false
    property int index: 0
    // Moved by the user since opening (else the highlight follows the current mode).
    property bool moved: false

    readonly property var modes: [
        { id: "internal", icon: "laptop", title: Translation.tr("This screen only") },
        { id: "mirror", icon: "screen_share", title: Translation.tr("Duplicate") },
        { id: "left", icon: "keyboard_double_arrow_left", title: Translation.tr("Extend left") },
        { id: "right", icon: "keyboard_double_arrow_right", title: Translation.tr("Extend right") },
        { id: "external", icon: "desktop_windows", title: Translation.tr("Second screen only") }
    ]

    // From `hyprctl monitors all -j` (includes disabled ones).
    readonly property var monitors: HyprlandSettings.monitors
    readonly property var internal: monitors.find(m => /^(eDP|LVDS|DSI)/.test(m.name)) ?? monitors[0] ?? null
    readonly property var external: monitors.find(m => m !== internal) ?? null
    readonly property bool hasExternal: external !== null

    // The layout in effect now.
    readonly property string current: {
        if (!internal || !external || external.disabled)
            return "internal";
        if (internal.disabled)
            return "external";
        if (external.mirrorOf && external.mirrorOf !== "none")
            return "mirror";
        return external.x >= internal.x + internal.width / internal.scale ? "right" : "left";
    }

    function show() {
        HyprlandSettings.refresh();
        moved = false;
        index = Math.max(0, modes.findIndex(m => m.id === current));
        open = true;
    }

    // The monitor list arrives asynchronously: start on the mode in effect.
    Connections {
        target: HyprlandSettings
        function onMonitorsChanged() {
            if (root.open && !root.moved)
                root.index = Math.max(0, root.modes.findIndex(m => m.id === root.current));
        }
    }
    Component.onCompleted: HyprlandSettings.refresh()

    function next() {
        if (!open) {
            show();
            return;
        }
        // Without a second screen there's only one mode to pick.
        if (hasExternal) {
            index = (index + 1) % modes.length;
            moved = true;
        }
    }

    function modeOf(m) {
        return `${m.width}x${m.height}@${m.refreshRate.toFixed(2)}`;
    }

    // An enabled output; `mirror: ""` clears a previous duplicate (rules keep it otherwise).
    function rule(m, extra) {
        return Object.assign({ mode: m === internal ? modeOf(m) : "preferred", scale: m.scale || 1, disabled: false, mirror: "" }, extra);
    }

    function apply(id) {
        open = false;
        if (!internal)
            return;
        if (!external) {
            id = "internal";
            if (!internal.disabled)
                return;
        }
        const i = internal.name, e = external?.name;
        // [output, rule, keep in the saved overrides]
        const rules = {
            internal: [[i, rule(internal, { position: "0x0" }), true], [e, { disabled: true }, true]],
            mirror: [[i, rule(internal, { position: "0x0" }), true], [e, rule(external, { position: "auto", mirror: i }), true]],
            right: [[i, rule(internal, { position: "0x0" }), true], [e, rule(external, { position: "auto-right" }), true]],
            left: [[i, rule(internal, { position: "0x0" }), true], [e, rule(external, { position: "auto-left" }), true]],
            // The panel stays on in the saved rules, so a boot without the cable has a screen.
            external: [[e, rule(external, { position: "0x0" }), true], [i, { disabled: true }, false]]
        }[id].filter(r => r[0]);

        const saved = Object.assign({}, HyprlandSettings.overrides.monitors);
        for (const [output, r, keep] of rules) {
            HyprlandSettings.apply(`hl.monitor(${HyprlandSettings.lua(Object.assign({ output }, r))})`);
            if (keep)
                saved[output] = r;
            else
                saved[output] = rule(internal, { position: "0x0" });
        }
        HyprlandSettings.overrides.monitors = saved;
        HyprlandSettings.writeLua();
        refreshLater.restart();
    }

    Timer {
        id: refreshLater
        interval: 800
        onTriggered: HyprlandSettings.refresh()
    }

    // Safety net: no screen left (e.g. the external one unplugged while the panel was
    // off) turns the panel back on.
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (Quickshell.screens.length === 0)
                rescue.restart();
        }
    }
    Timer {
        id: rescue
        interval: 500
        onTriggered: {
            if (Quickshell.screens.length > 0)
                return;
            const name = root.internal?.name ?? "eDP-1";
            HyprlandSettings.apply(`hl.monitor({ output = "${name}", mode = "preferred", position = "auto", scale = 1, disabled = false })`);
        }
    }

    IpcHandler {
        target: "display"

        function toggle(): void {
            root.open ? (root.open = false) : root.show();
        }
        // What the display key does: open, then step through the modes.
        function next(): void {
            root.next();
        }
        // internal, mirror, left, right, external
        function set(mode: string): void {
            HyprlandSettings.refresh();
            applyLater.mode = mode;
            applyLater.restart();
        }
    }
    Timer {
        id: applyLater
        property string mode
        interval: 400 // after the refresh above
        onTriggered: root.apply(mode)
    }

    PanelLoader {
        id: loader
        shown: root.open

        PanelWindow {
            id: window

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            WlrLayershell.namespace: "hi-shell-display"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape)
                        root.open = false;
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                        root.apply(root.modes[root.index].id);
                    else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab)
                        root.next();
                    else if ((event.key === Qt.Key_Left || event.key === Qt.Key_Up) && root.hasExternal) {
                        root.index = (root.index + root.modes.length - 1) % root.modes.length;
                        root.moved = true;
                    }
                    else
                        return;
                    event.accepted = true;
                }
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: content.implicitWidth + 40
                height: content.implicitHeight + 40
                radius: Appearance.rounding.extraLarge
                color: Appearance.translucent(Colors.m3surfaceContainerLow)
                border.width: 1
                border.color: Qt.alpha(Colors.m3outlineVariant, 0.6)

                opacity: loader.revealed ? 1 : 0
                scale: loader.revealed ? 1 : 0.85
                Behavior on opacity { EffectAnim { duration: Appearance.anim.fast } }
                Behavior on scale { SpringAnim {} }

                MouseArea {
                    anchors.fill: parent // keep clicks on the card from closing it
                }

                ColumnLayout {
                    id: content
                    anchors.centerIn: parent
                    spacing: 16

                    RowLayout {
                        spacing: 10
                        MaterialIcon {
                            icon: "screenshot_monitor"
                            iconSize: 22
                            color: Colors.m3primary
                        }
                        StyledText {
                            text: Translation.tr("Display mode")
                            font.pixelSize: Appearance.font.size.titleMedium
                            font.weight: Font.Medium
                        }
                        Item { Layout.fillWidth: true }
                        StyledText {
                            text: root.hasExternal ? `${root.internal?.name ?? ""} · ${root.external.name} ${root.external.width}×${root.external.height}`
                                                   : Translation.tr("No second screen connected")
                            font.pixelSize: Appearance.font.size.labelMedium
                            color: Colors.m3onSurfaceVariant
                        }
                    }

                    Row {
                        spacing: 10

                        Repeater {
                            model: root.modes

                            Rectangle {
                                id: tile
                                required property var modelData
                                required property int index
                                readonly property bool selected: index === root.index
                                readonly property bool active: modelData.id === root.current
                                readonly property bool usable: root.hasExternal || modelData.id === "internal"

                                width: 128
                                height: 128
                                radius: Appearance.rounding.large
                                color: selected ? Colors.m3primaryContainer : Colors.m3surfaceContainerHigh
                                border.width: selected ? 2 : 0
                                border.color: Colors.m3primary
                                opacity: usable ? 1 : 0.38
                                scale: selected ? 1.04 : 1
                                Behavior on color { ColorAnim { duration: Appearance.anim.fast } }
                                Behavior on scale { SpringAnim { duration: Appearance.anim.normal } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    width: parent.width - 16
                                    spacing: 10
                                    MaterialIcon {
                                        Layout.alignment: Qt.AlignHCenter
                                        icon: tile.modelData.icon
                                        iconSize: 40
                                        fill: tile.selected ? 1 : 0
                                        color: tile.selected ? Colors.m3onPrimaryContainer : Colors.m3onSurfaceVariant
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.Wrap
                                        text: tile.modelData.title
                                        font.pixelSize: Appearance.font.size.labelMedium
                                        font.weight: tile.selected ? Font.Medium : Font.Normal
                                        color: tile.selected ? Colors.m3onPrimaryContainer : Colors.m3onSurface
                                    }
                                }

                                // The mode in effect now
                                Rectangle {
                                    visible: tile.active
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 8
                                    width: 10
                                    height: 10
                                    radius: 5
                                    color: Colors.m3tertiary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: tile.usable
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.apply(tile.modelData.id)
                                }
                            }
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("Press the key again or use the arrows · Enter to apply · Esc to close")
                        font.pixelSize: Appearance.font.size.labelSmall
                        color: Colors.m3outline
                    }
                }
            }
        }
    }
}
