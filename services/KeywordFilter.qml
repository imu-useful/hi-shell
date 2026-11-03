pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.common
import qs.services

// Keyword filter (Settings > Services): a browser tab whose title has one of the words (porn, hentai, ...)
// is closed, the way Focus Mode closes a blocked site's tab (services/focus_close_tab.sh). Only the title
// is known here, not the address, so a page whose title doesn't name the word is not caught.
Singleton {
    id: root

    readonly property var options: Config.options.contentFilter
    readonly property var words: options.keywords.map(w => w.trim().toLowerCase()).filter(w => w !== "")

    // Window address -> the last time a tab was closed in it (a title lags behind the closed tab).
    property var lastClose: ({})

    function check(address, title) {
        if (!options.keywordsOn || words.length === 0)
            return;
        const window = Hyprland.toplevels.values.find(t => t.address === address);
        const app = (window?.wayland?.appId ?? "").toLowerCase();
        if (!FocusBlocker.browsers.some(b => app.includes(b)))
            return;
        const lower = title.toLowerCase();
        const word = words.find(w => lower.includes(w));
        if (!word)
            return;
        const now = Date.now();
        if (now - (lastClose[address] ?? 0) < 1500)
            return;
        lastClose = Object.assign({}, lastClose, { [address]: now });
        Quickshell.execDetached(["sh", Quickshell.shellDir + "/services/focus_close_tab.sh", `0x${address}`]);
        Quickshell.execDetached(["notify-send", "-a", "hi-shell", "-i", "block", Translation.tr("A tab was closed"), Translation.tr("Its title has “%1”").arg(word)]);
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "windowtitlev2")
                return;
            // "address,title": the title may hold commas itself.
            const comma = event.data.indexOf(",");
            root.check(event.data.slice(0, comma), event.data.slice(comma + 1));
        }
    }
}
