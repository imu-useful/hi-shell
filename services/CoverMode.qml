pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Cover mode (Config desktop.coverMode): while something with cover art plays, the
// desktop shows the cover instead of the wallpaper, and the palette comes from it.
// Players give art as file:// or http(s) URLs; remote ones are downloaded once into
// the cache for matugen. Turning it off (or the music going away) brings the
// wallpaper's colors back.
Singleton {
    id: root

    // Off during Focus Mode (it has a wallpaper of its own); back on after it.
    readonly property bool enabled: Config.options.desktop.coverMode && !ShellState.zen
    readonly property string art: Mpris.artUrl
    // The desktop draws the cover while this is true.
    readonly property bool active: enabled && Mpris.hasPlayer && art !== ""
    // Local file of the current cover ("" until it's ready).
    property string file: ""
    property bool themed: false

    readonly property string dir: `${Paths.cache}/covers`

    function toggle() {
        Config.options.desktop.coverMode = !enabled;
    }

    function refresh() {
        retheme.stop();
        if (!active) {
            file = "";
            if (themed) {
                themed = false;
                Theme.cover = "";
                Theme.setWallpaper(Wallpapers.current);
            }
            return;
        }
        if (art.startsWith("file://")) {
            file = decodeURIComponent(art.slice(7));
            retheme.restart();
        } else {
            // Name the cached copy after the URL so repeats don't download again.
            const name = Qt.md5(art) + ".img";
            download.target = `${dir}/${name}`;
            download.command = ["sh", "-c", 'mkdir -p "$(dirname "$2")"; [ -s "$2" ] || curl -fsSL --max-time 15 -o "$2" "$1"', "sh", art, download.target];
            download.running = true;
        }
    }

    onActiveChanged: refresh()
    onArtChanged: if (active) refresh()

    Process {
        id: download
        property string target: ""
        onExited: code => {
            if (code === 0 && root.active) {
                root.file = target;
                retheme.restart();
            }
        }
    }

    // Skipping through tracks shouldn't run matugen for each one.
    Timer {
        id: retheme
        interval: 1500
        onTriggered: {
            if (root.active && root.file) {
                root.themed = true;
                Theme.cover = root.file;
                Theme.setWallpaper(root.file);
            }
        }
    }

    // After a restart with the palette still from a cover (and nothing playing now),
    // go back to the wallpaper's colors.
    Timer {
        running: true
        interval: 3000
        onTriggered: {
            if (!root.active && Colors.wallpaper.startsWith(root.dir) && Wallpapers.current)
                Theme.setWallpaper(Wallpapers.current);
        }
    }

    IpcHandler {
        target: "coverMode"

        function toggle(): void {
            root.toggle();
        }
        function on(): void {
            Config.options.desktop.coverMode = true;
        }
        function off(): void {
            Config.options.desktop.coverMode = false;
        }
    }
}
