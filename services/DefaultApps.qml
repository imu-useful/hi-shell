pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Default applications (Settings > Defaults): which program opens a kind of file or link, through
// xdg-mime (as `xdg-mime default`), and the terminal hi-shell runs its commands in (apps.terminal).
// The current ones are read back from xdg-mime; a failed change is reported, not dropped.
Singleton {
    id: root

    // The kinds, with the MIME types each one covers. "terminal" is not a MIME kind: it's apps.terminal.
    readonly property var categories: [
        { id: "browser", title: "Web browser", icon: "public", mimes: ["x-scheme-handler/http", "x-scheme-handler/https", "text/html"] },
        { id: "files", title: "File manager", icon: "folder", mimes: ["inode/directory"] },
        { id: "mail", title: "Email", icon: "mail", mimes: ["x-scheme-handler/mailto"] },
        { id: "image", title: "Images", icon: "image", mimes: ["image/png", "image/jpeg", "image/webp", "image/gif"] },
        { id: "video", title: "Videos", icon: "movie", mimes: ["video/mp4", "video/webm", "video/x-matroska"] },
        { id: "audio", title: "Music", icon: "music_note", mimes: ["audio/mpeg", "audio/flac", "audio/ogg"] },
        { id: "pdf", title: "PDF", icon: "picture_as_pdf", mimes: ["application/pdf"] },
        { id: "text", title: "Text", icon: "description", mimes: ["text/plain"] },
        { id: "terminal", title: "Terminal", icon: "terminal", mimes: [] }
    ]

    // category id -> the desktop file id of its default app ("" when none).
    property var current: ({})
    // category id -> desktop file ids that can open it (read by `finder`).
    property var offered: ({})
    // The last change that failed, shown in its category ("" when it worked).
    property var failed: ({})

    function mimesOf(category) {
        return categories.find(c => c.id === category)?.mimes ?? [];
    }

    // The desktop file name ("firefox.desktop") of an entry, and the name of a file's entry.
    function fileName(app) {
        return app.id.endsWith(".desktop") ? app.id : `${app.id}.desktop`;
    }
    function nameOf(desktopId) {
        if (desktopId === "")
            return "";
        const entry = DesktopEntries.heuristicLookup(desktopId.replace(/\.desktop$/, ""));
        return entry?.name ?? desktopId;
    }

    // The apps that can open a category, by name. The terminal ones for "terminal".
    function candidates(category) {
        if (category === "terminal")
            return DesktopEntries.applications.values.filter(a => !a.noDisplay && a.categories.includes("TerminalEmulator"))
                .sort((a, b) => a.name.localeCompare(b.name));
        return (offered[category] ?? []).map(id => DesktopEntries.heuristicLookup(id))
            .filter(a => a !== null && !a.noDisplay)
            .sort((a, b) => a.name.localeCompare(b.name));
    }

    // Makes `desktopId` the default for a category. Terminal: apps.terminal gets the entry's id (the command).
    function set(category, desktopId) {
        if (category === "terminal") {
            Config.options.apps.terminal = desktopId.replace(/\.desktop$/, "");
            failed = Object.assign({}, failed, { [category]: "" });
            return;
        }
        const mimes = mimesOf(category);
        setter.category = category;
        setter.desktop = desktopId;
        setter.command = ["sh", "-c", 'd="$1"; shift; for m in "$@"; do xdg-mime default "$d" "$m" || exit 1; done', "sh", desktopId, ...mimes];
        setter.running = true;
    }

    // Types a program's name or command: its desktop entry, if there is one. Returns "" when not found.
    function resolve(text) {
        const name = text.trim().replace(/\.desktop$/, "");
        if (name === "")
            return "";
        const entry = DesktopEntries.heuristicLookup(name);
        return entry && !entry.noDisplay ? fileName(entry) : "";
    }

    function refresh() {
        if (!query.running)
            query.running = true;
    }

    Process {
        id: setter
        property string category: ""
        property string desktop: ""
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("DefaultApps:", text.trim())
        }
        onExited: code => {
            const next = Object.assign({}, root.failed);
            next[category] = code === 0 ? "" : Translation.tr("Couldn't set it (see the shell's log)");
            root.failed = next;
            if (code === 0)
                root.current = Object.assign({}, root.current, { [category]: desktop });
            refreshLater.restart();
        }
    }

    // One grep per MIME type, all in one shell line: each prints the desktop ids that list it.
    function finderScript() {
        const parts = [];
        for (const c of categories) {
            for (const m of c.mimes) {
                const re = m.replace(/[.]/g, "\\.");
                parts.push(`grep -lE '^MimeType=.*${re}' /usr/share/applications/*.desktop "$HOME"/.local/share/applications/*.desktop 2>/dev/null | sed -e 's#.*/##' -e 's#[.]desktop$##' -e 's#^#${c.id} #'`);
            }
        }
        return parts.join("; ");
    }

    Process {
        id: finder
        command: ["sh", "-c", root.finderScript()]
        stdout: StdioCollector {
            onStreamFinished: {
                const next = {};
                for (const line of text.split("\n")) {
                    const [category, id] = line.trim().split(" ");
                    if (category && id)
                        next[category] = [...new Set([...(next[category] ?? []), id])];
                }
                root.offered = next;
            }
        }
    }

    Process {
        id: query
        // One line per MIME kind: "<category> <desktop id>", from its first type.
        command: ["sh", "-c", root.categories.filter(c => c.mimes.length > 0).map(c => `printf '%s %s\\n' '${c.id}' "$(xdg-mime query default '${c.mimes[0]}' 2>/dev/null)"`).join("; ")]
        stdout: StdioCollector {
            onStreamFinished: {
                const next = Object.assign({}, root.current);
                for (const line of text.split("\n")) {
                    const parts = line.trim().split(" ");
                    if (parts[0])
                        next[parts[0]] = (parts[1] ?? "").trim();
                }
                root.current = next;
            }
        }
    }

    // The default changes once the file is written; read it back a moment later.
    Timer {
        id: refreshLater
        interval: 600
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        refresh();
        finder.running = true;
    }
}
