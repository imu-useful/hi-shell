pragma Singleton

import QtQuick
import Quickshell
import qs.common

// Which screens a thing is on, and the per-screen settings of the dock and the desktop (Config dock.monitors / perScreen,
// desktop.monitors / layouts, wallpapers.perScreen).
Singleton {
    id: root

    // Lists read from the config file may be array-like objects rather than arrays.
    function arr(v) {
        return v !== null && v !== undefined && typeof v === "object" && typeof v.length === "number" ? Array.from(v) : [];
    }

    // Is `screen` (a ShellScreen) one of the screens in `list`: ["*"] is every screen, names pick screens; an empty
    // list means the single screen named by `legacy` (the older option), or else the first screen.
    function selected(list, legacy, screen) {
        const names = arr(list);
        if (names.length > 0)
            return names.includes("*") || names.includes(screen?.name);
        return legacy ? screen?.name === legacy : screen === Quickshell.screens[0];
    }

    // --- Dock: shared options with a screen's own over them ---
    readonly property var dockKeys: ["position", "autoHide", "magnify", "showWhenEmpty", "showRunning", "appsButton", "showIndicators", "magnifyAmount", "spacing", "cornerRadius", "edgeMargin", "iconSize"]

    function dockFor(screenName) {
        const shared = Config.options.dock;
        const own = (shared.perScreen ?? {})[screenName] ?? {};
        const out = { pinned: shared.pinned };
        for (const k of dockKeys)
            out[k] = own[k] !== undefined && own[k] !== null ? own[k] : shared[k];
        return out;
    }

    // --- Desktop widget layout: a screen can have one of its own ---
    function hasOwnLayout(screenName) {
        return ((Config.options.desktop.layouts ?? {})[screenName]) !== undefined;
    }

    function layoutFor(screenName) {
        const own = (Config.options.desktop.layouts ?? {})[screenName];
        return own !== undefined ? own : Config.options.desktop.layout;
    }

    function saveLayout(screenName, layout) {
        if (hasOwnLayout(screenName))
            Config.mapSet("desktop.layouts", screenName, layout);
        else
            Config.options.desktop.layout = layout;
    }

    // Give a screen its own layout (a copy of the shared one), or take it back to the shared one.
    function setOwnLayout(screenName, own) {
        if (own)
            Config.mapSet("desktop.layouts", screenName, JSON.parse(JSON.stringify(Config.options.desktop.layout ?? {})));
        else
            Config.mapSet("desktop.layouts", screenName, null);
    }

    // --- Wallpaper of a screen ("" = the shared one) ---
    function wallpaperFor(screenName) {
        const f = (Config.options.wallpapers.perScreen ?? {})[screenName];
        return typeof f === "string" ? f.replace(/^~(?=\/|$)/, Paths.home) : "";
    }
}
