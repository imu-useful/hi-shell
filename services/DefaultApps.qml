pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Default applications (Settings > Default apps): which program opens a kind of file or link, through
// xdg-mime (the same as `xdg-mime default`). The current ones are read back with `xdg-mime query default`.
Singleton {
    id: root

    // The kinds, with the MIME types each one covers.
    readonly property var categories: [
        { id: "browser", title: "Web browser", icon: "public", mimes: ["x-scheme-handler/http", "x-scheme-handler/https", "text/html"] },
        { id: "files", title: "File manager", icon: "folder", mimes: ["inode/directory"] },
        { id: "mail", title: "Email", icon: "mail", mimes: ["x-scheme-handler/mailto"] },
        { id: "image", title: "Images", icon: "image", mimes: ["image/png", "image/jpeg", "image/webp", "image/gif"] },
        { id: "video", title: "Videos", icon: "movie", mimes: ["video/mp4", "video/webm", "video/x-matroska"] },
        { id: "audio", title: "Music", icon: "music_note", mimes: ["audio/mpeg", "audio/flac", "audio/ogg"] },
        { id: "pdf", title: "PDF", icon: "picture_as_pdf", mimes: ["application/pdf"] },
        { id: "text", title: "Text", icon: "description", mimes: ["text/plain"] }
    ]

    // category id -> the desktop file id of its default app ("" when none).
    property var current: ({})

    function refresh() {
        if (!query.running)
            query.running = true;
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

    // category id -> desktop file ids whose MimeType= lists one of its types (read by `finder`).
    property var offered: ({})

    // The apps that can open a category: the desktop entries offered for it, by name.
    function candidates(category) {
        const ids = offered[category] ?? [];
        return ids.map(id => DesktopEntries.heuristicLookup(id))
            .filter(a => a !== null && !a.noDisplay)
            .sort((a, b) => a.name.localeCompare(b.name));
    }

    function set(category, desktopId) {
        const mimes = categories.find(c => c.id === category)?.mimes ?? [];
        Quickshell.execDetached(["sh", "-c", 'd="$1"; shift; for m in "$@"; do xdg-mime default "$d" "$m"; done', "sh", desktopId, ...mimes]);
        current = Object.assign({}, current, { [category]: desktopId });
        refreshLater.restart();
    }

    // The desktop file name ("firefox.desktop") of an entry, and the entry of a file name.
    function fileName(app) {
        return app.id.endsWith(".desktop") ? app.id : `${app.id}.desktop`;
    }
    function nameOf(desktopId) {
        if (desktopId === "")
            return "";
        const entry = DesktopEntries.heuristicLookup(desktopId.replace(/\.desktop$/, ""));
        return entry?.name ?? desktopId;
    }

    // Which desktop files list each type: grep of the applications folders, one "category id" line per match.
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
        // One line per category: "<category> <desktop id>", from its first MIME type.
        command: ["sh", "-c", root.categories.map(c => `printf '%s %s\\n' '${c.id}' "$(xdg-mime query default '${c.mimes[0]}' 2>/dev/null)"`).join("; ")]
        stdout: StdioCollector {
            onStreamFinished: {
                const next = {};
                for (const line of text.split("\n")) {
                    const parts = line.trim().split(" ");
                    if (parts.length >= 1 && parts[0] !== "")
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
