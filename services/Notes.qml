pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Sticky notes kept in ~/.local/state/hi-shell/notes.json.
Singleton {
    id: root

    // [{ text, color (0..2 tonal slot), time }]
    property var notes: []

    function add(text) {
        const t = text.trim();
        if (t === "")
            return;
        notes = [...notes, { text: t, color: notes.length % 3, time: Date.now() }];
        save();
    }
    function remove(index) {
        notes = notes.filter((_, i) => i !== index);
        save();
    }
    function cycleColor(index) {
        notes = notes.map((n, i) => i === index ? Object.assign({}, n, { color: (n.color + 1) % 3 }) : n);
        save();
    }

    function save() {
        file.setText(JSON.stringify(notes, null, 1));
    }

    FileView {
        id: file
        path: Paths.state + "/notes.json"
        printErrors: false
        onLoaded: {
            try {
                root.notes = JSON.parse(text());
            } catch (e) {
                console.warn("Notes: invalid file", e);
            }
        }
    }
}
