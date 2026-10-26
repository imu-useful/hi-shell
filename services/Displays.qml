pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Display modes for a laptop with a second screen: this screen only, duplicate,
// extend left / right, second screen only. Used by the picker (the display key),
// the right sidebar's quick toggle and Settings > Hyprland.
// Rules apply live and go into the Hyprland overrides, except the laptop panel being
// off ("second screen only" is for the session, so a boot without the cable has a
// screen); if every screen disappears the panel is turned back on.
// IPC: `qs -c hi-shell ipc call display set mirror` (internal, left, right, external).
Singleton {
    id: root

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
    readonly property var currentMode: modes.find(m => m.id === current) ?? modes[0]

    function refresh() {
        HyprlandSettings.refresh();
    }

    function modeOf(m) {
        return `${m.width}x${m.height}@${m.refreshRate.toFixed(2)}`;
    }

    // An enabled output; `mirror: ""` clears a previous duplicate (rules keep it otherwise).
    function rule(m, extra) {
        return Object.assign({ mode: m === internal ? modeOf(m) : "preferred", scale: m.scale || 1, disabled: false, mirror: "" }, extra);
    }

    function apply(id) {
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
        }[id]?.filter(r => r[0]);
        if (!rules)
            return;

        const saved = Object.assign({}, HyprlandSettings.overrides.monitors);
        for (const [output, r, keep] of rules) {
            HyprlandSettings.apply(`hl.monitor(${HyprlandSettings.lua(Object.assign({ output }, r))})`);
            saved[output] = keep ? r : rule(internal, { position: "0x0" });
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
            // Hotplug: re-read Hyprland's monitors (and heal what the shell can't see).
            refreshLater.restart();
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

    // Hyprland sometimes turns an output back on without announcing it to clients: it's
    // "on" but the shell (and grim) can't see it, so it has no bar or desktop. When the
    // shell is missing a screen Hyprland has on, switch that output off and on once.
    property var healed: ({}) // output -> time of the last attempt
    function heal() {
        for (const m of monitors) {
            if (m.disabled || Quickshell.screens.some(s => s.name === m.name))
                continue;
            const last = healed[m.name] ?? 0;
            if (Date.now() - last < 20000)
                continue;
            healed[m.name] = Date.now();
            console.info("Displays: re-announcing", m.name);
            const r = HyprlandSettings.overrides.monitors[m.name] ?? rule(m, { position: "auto" });
            HyprlandSettings.apply(`hl.monitor(${HyprlandSettings.lua({ output: m.name, disabled: true })})`);
            reenable.pending.push(HyprlandSettings.lua(Object.assign({ output: m.name }, r, { disabled: false })));
            reenable.restart();
        }
    }
    Timer {
        id: reenable
        property var pending: []
        interval: 700
        onTriggered: {
            for (const r of pending)
                HyprlandSettings.apply(`hl.monitor(${r})`);
            pending = [];
            refreshLater.restart();
        }
    }
    // Check once the screen list has settled after Hyprland's monitors change.
    Connections {
        target: HyprlandSettings
        function onMonitorsChanged() {
            healCheck.restart();
        }
    }
    Timer {
        id: healCheck
        interval: 1500
        onTriggered: root.heal()
    }
    Component.onCompleted: HyprlandSettings.refresh()

    IpcHandler {
        target: "displays"

        // Screens the shell has windows for (Quickshell's view), one per line.
        function screens(): string {
            return Quickshell.screens.map(s => `${s.name} ${s.width}x${s.height}+${s.x}+${s.y}`).join("\n");
        }
    }
}
