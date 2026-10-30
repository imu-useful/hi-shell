pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Current wallpaper (kept in ~/.local/state/hi-shell/wallpaper.txt), local
// folders with cached thumbnails, and online search (Wallhaven; Unsplash with a
// key). The desktop layer draws `current`; the palette follows it via Theme.
// A wallpaper can be live: a video (mp4, webm, mkv, ...) or a gif. The desktop plays it over `still`,
// a picture of it (the picture itself, or a frame of the video taken by services/stills.py), which
// everything that needs an image (palette, lock screen, thumbnails) uses.
// IPC: `qs -c hi-shell ipc call wallpaper set <path>` (random, toggleSelector, status).
Singleton {
    id: root

    readonly property var options: Config.options.wallpapers
    readonly property string stateFile: Paths.state + "/wallpaper.txt"
    readonly property string thumbDir: Paths.cache + "/thumbnails"

    property string current: ""

    readonly property var videoExtensions: ["mp4", "webm", "mkv", "mov", "avi", "m4v", "ogv", "flv", "wmv", "ts", "mpg", "mpeg"]
    readonly property var animatedExtensions: ["gif", "apng"]
    // "video", "gif", or "" for a plain picture.
    function kindOf(path) {
        const ext = path.slice(path.lastIndexOf(".") + 1).toLowerCase();
        return videoExtensions.includes(ext) ? "video" : animatedExtensions.includes(ext) ? "gif" : "";
    }
    readonly property string kind: kindOf(current)
    // Played on the desktop (Settings > Desktop can switch it off).
    readonly property bool live: kind !== "" && options.animate
    // A picture of the wallpaper; empty while a video's frame is being taken.
    property string videoStill: ""
    readonly property string still: kind === "video" ? videoStill : current

    // [{ path, name, thumb }]
    property var local: []
    property bool scanning: false

    // Online search
    readonly property var providers: options.unsplashKey ? ["wallhaven", "unsplash"] : ["wallhaven"]
    property string provider: "wallhaven"
    property string query: ""
    property string resolution: "1920x1080" // minimum
    property int page: 1
    property int lastPage: 1
    // [{ id, url (full image), thumb, resolution, ext }]
    property var online: []
    property bool searching: false
    property string onlineError: ""
    property string downloading: "" // id being downloaded

    function expand(path) {
        return path.startsWith("~/") ? Paths.home + path.slice(1) : path;
    }

    function set(path) {
        const p = expand(path);
        if (!p)
            return;
        current = p;
        store.setText(p + "\n");
        Theme.setWallpaper(p);
        updateStill();
    }

    // A frame of the video wallpaper (one at a time; again if the wallpaper changed meanwhile).
    function updateStill() {
        if (kind !== "video") {
            videoStill = "";
            return;
        }
        if (stiller.running) {
            stiller.again = true;
            return;
        }
        stiller.file = current;
        stiller.command = ["python3", Quickshell.shellDir + "/services/stills.py", "--cache", thumbDir, current];
        stiller.running = true;
    }

    function random() {
        const pool = local.filter(w => w.path !== current);
        if (pool.length)
            set(pool[Math.floor(Math.random() * pool.length)].path);
    }

    function scan() {
        if (scanner.running)
            return;
        local = [];
        scanning = true;
        scanner.command = ["python3", Quickshell.shellDir + "/services/thumbnails.py", "--cache", thumbDir, ...options.directories.map(expand)];
        scanner.running = true;
    }

    // --- Online ---
    function search(newPage) {
        page = Math.max(1, newPage ?? 1);
        online = [];
        onlineError = "";
        searching = true;
        if (provider === "unsplash")
            searchUnsplash();
        else
            searchWallhaven();
    }

    function searchWallhaven() {
        const params = [
            `q=${encodeURIComponent(query)}`, "categories=110", "purity=100",
            `atleast=${resolution}`, `sorting=${query ? "relevance" : "toplist"}`, "topRange=1M", `page=${page}`
        ];
        if (options.wallhavenKey)
            params.push(`apikey=${options.wallhavenKey}`);
        get(`https://wallhaven.cc/api/v1/search?${params.join("&")}`, {}, data => {
            lastPage = data.meta?.last_page ?? 1;
            online = (data.data ?? []).map(w => ({
                id: `wallhaven-${w.id}`,
                url: w.path,
                thumb: w.thumbs.large,
                resolution: w.resolution,
                ext: w.path.split(".").pop()
            }));
        });
    }

    function searchUnsplash() {
        const width = Number(resolution.split("x")[0]);
        const q = query || "wallpaper";
        get(`https://api.unsplash.com/search/photos?query=${encodeURIComponent(q)}&orientation=landscape&per_page=24&page=${page}`,
            { Authorization: `Client-ID ${options.unsplashKey}` }, data => {
            lastPage = data.total_pages ?? 1;
            online = (data.results ?? []).filter(p => p.width >= width).map(p => ({
                id: `unsplash-${p.id}`,
                // raw + w: Unsplash resizes server-side to the screen width.
                url: `${p.urls.raw}&w=${Math.max(width, 2560)}&fm=jpg&q=90`,
                thumb: p.urls.small,
                resolution: `${p.width}x${p.height}`,
                ext: "jpg"
            }));
        });
    }

    function get(url, headers, onData) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            searching = false;
            if (xhr.status !== 200) {
                onlineError = xhr.status === 401 ? Translation.tr("Invalid API key") : xhr.status === 429 ? Translation.tr("Rate limited, try again in a minute") : Translation.tr("Couldn't search (HTTP %1)").arg(xhr.status || "error");
                return;
            }
            try {
                onData(JSON.parse(xhr.responseText));
            } catch (e) {
                onlineError = Translation.tr("Unexpected response");
            }
        };
        xhr.open("GET", url);
        for (const k in headers)
            xhr.setRequestHeader(k, headers[k]);
        xhr.send();
    }

    // Save an online picture to the download folder, then set it.
    function download(item) {
        if (downloader.running)
            return;
        const dir = expand(options.downloadDirectory);
        const file = `${dir}/${item.id}.${item.ext}`;
        downloading = item.id;
        downloader.target = file;
        downloader.command = ["sh", "-c", 'mkdir -p "$1" && [ -s "$2" ] || curl -fsSL --retry 2 -o "$2.part" "$3" && mv "$2.part" "$2"', "sh", dir, file, item.url];
        downloader.running = true;
    }

    Process {
        id: stiller
        property string file: ""
        property bool again: false
        stdout: StdioCollector {
            onStreamFinished: if (stiller.file === root.current) root.videoStill = text.trim()
        }
        onExited: {
            if (again || file !== root.current) {
                again = false;
                root.updateStill();
            }
        }
    }

    // What the wallpaper looks like as a picture, for wait-mode (its own process, no Wallpapers service).
    FileView {
        id: stillStore
        path: Paths.state + "/wallpaper-still.txt"
        printErrors: false
    }
    onStillChanged: if (still !== "") stillStore.setText(still + "\n")

    Process {
        id: downloader
        property string target: ""
        onExited: code => {
            root.downloading = "";
            if (code === 0) {
                root.set(target);
                root.scan();
            } else {
                root.onlineError = Translation.tr("Download failed");
            }
        }
    }

    Process {
        id: scanner
        // Lines arrive one per thumbnail; hand them to the UI in batches.
        property var pending: []
        stdout: SplitParser {
            onRead: line => {
                try {
                    scanner.pending.push(JSON.parse(line));
                } catch (e) {}
            }
        }
        onExited: {
            flush.triggered();
            root.scanning = false;
            root.local = [...root.local].sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
        }
    }

    Timer {
        id: flush
        interval: 300
        repeat: true
        running: root.scanning
        onTriggered: {
            if (scanner.pending.length === 0)
                return;
            root.local = root.local.concat(scanner.pending);
            scanner.pending = [];
        }
    }

    FileView {
        id: store
        path: root.stateFile
        printErrors: false
        onLoaded: {
            root.current = text().trim();
            root.updateStill();
        }
        // First run: start from what the palette was generated from (e.g. illogical-impulse's wallpaper).
        onLoadFailed: root.current = Colors.wallpaper
    }

    // Before the state file exists, follow the palette's wallpaper.
    Connections {
        target: Colors
        function onWallpaperChanged() {
            if (root.current === "")
                root.current = Colors.wallpaper;
        }
    }

    IpcHandler {
        target: "wallpaper"

        function set(path: string): void {
            root.set(path);
        }
        function random(): void {
            if (root.local.length === 0) {
                root.scan();
                randomAfterScan.running = true;
            } else {
                root.random();
            }
        }
        function get(): string {
            return root.current;
        }
        function status(): string {
            return JSON.stringify({ current: root.current, kind: root.kind, live: root.live, still: root.still });
        }
        function toggleSelector(): void {
            ShellState.wallpaperSelectorOpen = !ShellState.wallpaperSelectorOpen;
        }
    }

    Timer {
        id: randomAfterScan
        interval: 500
        repeat: true
        onTriggered: {
            if (!root.scanning) {
                running = false;
                root.random();
            }
        }
    }
}
