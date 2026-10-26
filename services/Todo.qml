pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// To-do list kept in ~/.local/state/hi-shell/todo.json.
Singleton {
    id: root

    // [{ text, done, time }]
    property var items: []
    readonly property int pending: items.filter(i => !i.done).length

    function add(text) {
        const t = text.trim();
        if (t === "")
            return;
        items = [...items, { text: t, done: false, time: Date.now() }];
        save();
    }
    function toggle(index) {
        items = items.map((item, i) => i === index ? Object.assign({}, item, { done: !item.done }) : item);
        save();
    }
    function remove(index) {
        items = items.filter((_, i) => i !== index);
        save();
    }
    function clearDone() {
        items = items.filter(i => !i.done);
        save();
    }

    function save() {
        file.setText(JSON.stringify(items, null, 1));
    }

    FileView {
        id: file
        path: Paths.state + "/todo.json"
        printErrors: false
        onLoaded: {
            try {
                root.items = JSON.parse(text());
            } catch (e) {
                console.warn("Todo: invalid file", e);
            }
        }
    }

    IpcHandler {
        target: "todo"

        function add(text: string): void {
            root.add(text);
        }
        // Done / not done, by its number in `list` (from 1)
        function toggle(number: int): void {
            root.toggle(number - 1);
        }
        function list(): string {
            return root.items.map(i => `${i.done ? "[x]" : "[ ]"} ${i.text}`).join("\n");
        }
    }
}
