pragma Singleton

import QtQuick
import Quickshell

// App id (a window's class) -> icon path, shared by the bar's workspaces and the overview.
// heuristicLookup is a fuzzy search over every desktop entry, too slow to repeat on each
// window change (titles update often), so the answers are kept.
Singleton {
    id: root

    property var cache: ({})

    // "" when the app has no icon.
    function path(appId) {
        if (!appId)
            return "";
        if (!(appId in cache)) {
            const entry = DesktopEntries.heuristicLookup(appId);
            cache[appId] = Quickshell.iconPath(entry?.icon ?? appId, true);
        }
        return cache[appId];
    }
}
