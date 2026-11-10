pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import "../common/Looks.js" as Engine

// Looks (common/Looks.js): apply a built-in or saved look, save the current appearance under a name.
//   qs -c hi-shell ipc call looks list | apply <name> | save <name> | remove <name>
Singleton {
    id: root

    readonly property var all: Engine.all(Config.options.appearance.looks)
    readonly property var names: Object.keys(all)

    function apply(name) {
        const look = all[name];
        if (!look)
            return false;
        for (const k of Object.keys(look.set))
            Config.setPath("appearance." + k, look.set[k]);
        return true;
    }

    function save(name) {
        if (!Engine.validName(name))
            return false;
        const own = Object.assign({}, Config.options.appearance.looks);
        own[name] = Engine.pick(Config.options.appearance);
        Config.setPath("appearance.looks", own);
        return true;
    }

    function remove(name) {
        const own = Object.assign({}, Config.options.appearance.looks);
        if (!(name in own))
            return false;
        delete own[name];
        Config.setPath("appearance.looks", own);
        return true;
    }

    IpcHandler {
        target: "looks"

        function list(): string {
            return root.names.map(n => n + (root.all[n].builtin ? "" : " (yours)")).join("\n");
        }
        function apply(name: string): string {
            return root.apply(name) ? "ok" : "no look named " + name;
        }
        function save(name: string): string {
            return root.save(name) ? "ok" : "a name is letters, digits, space, . _ - (up to 40)";
        }
        function remove(name: string): string {
            return root.remove(name) ? "ok" : "no look of yours named " + name;
        }
    }
}
