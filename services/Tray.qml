pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.common

// System tray (StatusNotifierItem) items, minus the ones hidden in Config tray.hidden.
Singleton {
    id: root

    readonly property list<SystemTrayItem> all: SystemTray.items.values
    readonly property list<SystemTrayItem> items: all.filter(i => !Config.options.tray.hidden.includes(i.id))

    function setHidden(id, hidden) {
        const list = Config.options.tray.hidden.filter(x => x !== id);
        Config.options.tray.hidden = hidden ? [...list, id] : list;
    }

    IpcHandler {
        target: "tray"

        // One "id<TAB>title" line per item, to find ids for tray.hidden.
        function list(): string {
            return root.all.map(i => `${i.id}\t${i.title}`).join("\n");
        }
    }
}
