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

    // Lists read from the config file may be array-like objects rather than real arrays.
    function arr(v) {
        return v !== null && v !== undefined && typeof v === "object" && typeof v.length === "number" ? Array.from(v) : [];
    }

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
            own = arr(options.extra).find(b => (b.id ?? "") === barId) ?? {};
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
            out[k] = arr(out[k]).filter(w => typeof w === "string");
        return out;
    }

    // `entries` keeps the same array while the list of bars is the same, so that a change inside a bar (a widget
    // dragged, a slider) doesn't make Variants build every bar window again.
    property var entries: []
    onComputedEntriesChanged: {
        if (JSON.stringify(computedEntries) !== JSON.stringify(entries))
            entries = computedEntries;
    }
    Component.onCompleted: entries = computedEntries

    // Save the widget list `key` (left / center / right) of bar `barId` on `screenName`: an extra bar keeps it in its
    // entry; the main bar in the screen's own settings if that screen has a list of its own, else in bar.<key>.
    function writeList(screenName, barId, key, list) {
        if (barId === "main") {
            const own = (options.monitors ?? {})[screenName] ?? {};
            if (own[key] !== undefined && own[key] !== null)
                Config.mapSet("bar.monitors", screenName + "." + key, list);
            else
                Config.options.bar[key] = list;
            return;
        }
        const entry = arr(options.extra).find(b => b.id === barId);
        if (entry)
            Config.listPut("bar.extra", Object.assign({}, entry, { [key]: list }));
    }

    // [{ screen, barId }] for every window to create.
    readonly property var computedEntries: {
        const list = [];
        const extra = arr(options.extra).filter(b => b && typeof b.id === "string" && b.id !== "" && b.id !== "main");
        for (const scr of Quickshell.screens) {
            const own = (options.monitors ?? {})[scr.name] ?? {};
            if (own.enabled !== false)
                list.push({ screen: scr.name, barId: "main" });
            for (const b of extra) {
                const on = arr(b.monitors);
                if (on.length === 0 || on.includes(scr.name))
                    list.push({ screen: scr.name, barId: b.id });
            }
        }
        return list;
    }
}
