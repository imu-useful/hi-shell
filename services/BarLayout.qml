pragma Singleton

import QtQuick
import Quickshell
import qs.common

// Which bars exist and what each one looks like: the main bar on every screen (with the per-screen overrides in
// Config bar.monitors) and the extra bars (bar.extra). Bar.qml makes one window per entry of `entries`.
Singleton {
    id: root

    readonly property var options: Config.options.bar
    readonly property var positions: ["top", "bottom", "left", "right"]
    readonly property var styles: ["hug", "float", "islands", "m3"]

    // The settings of bar `barId` on the screen `screenName`, with every field filled in.
    function spec(screenName, barId) {
        const base = {
            position: options.position,
            style: options.style,
            height: options.height,
            margin: options.margin,
            left: [...options.left],
            center: [...options.center],
            right: [...options.right]
        };
        let own = {};
        if (barId === "main") {
            own = (options.monitors ?? {})[screenName] ?? {};
        } else {
            own = (options.extra ?? []).find(b => (b.id ?? "") === barId) ?? {};
            base.left = [];
            base.center = [];
            base.right = [];
        }
        const out = Object.assign({}, base);
        for (const k of Object.keys(base)) {
            if (own[k] !== undefined && own[k] !== null)
                out[k] = own[k];
        }
        out.position = positions.includes(out.position) ? out.position : "top";
        out.style = styles.includes(out.style) ? out.style : "float";
        out.height = Math.max(20, Math.min(120, Number(out.height) || 40));
        out.margin = Math.max(0, Math.min(64, Number(out.margin) || 0));
        for (const k of ["left", "center", "right"])
            out[k] = Array.isArray(out[k]) ? out[k].filter(w => typeof w === "string") : [];
        return out;
    }

    // [{ screen, barId }] for every window to create.
    readonly property var entries: {
        const list = [];
        const extra = (options.extra ?? []).filter(b => b && typeof b.id === "string" && b.id !== "" && b.id !== "main");
        for (const scr of Quickshell.screens) {
            const own = (options.monitors ?? {})[scr.name] ?? {};
            if (own.enabled !== false)
                list.push({ screen: scr.name, barId: "main" });
            for (const b of extra) {
                const on = Array.isArray(b.monitors) ? b.monitors : [];
                if (on.length === 0 || on.includes(scr.name))
                    list.push({ screen: scr.name, barId: b.id });
            }
        }
        return list;
    }
}
