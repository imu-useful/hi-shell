pragma Singleton

import QtQuick
import Quickshell
import qs.services

// Synced lyrics for the current track from LRCLIB (lrclib.net, no key).
// `lines` is [{ time (s, -1 if unsynced), text }]; `index` is the line playing now.
Singleton {
    id: root

    readonly property string artist: Mpris.artist
    readonly property string title: Mpris.active?.trackTitle ?? ""
    readonly property string key: `${artist}\u0001${title}`

    property var lines: []
    property bool synced: false
    property bool loading: false
    property string status: "" // "", "not found", "error"
    property var cache: ({})

    // Playback position, interpolated between MPRIS updates (which come once a second).
    property real basePosition: 0
    property real baseTime: Date.now()
    property real position: 0
    readonly property int index: {
        if (!synced)
            return -1;
        let i = -1;
        for (let k = 0; k < lines.length && lines[k].time <= position + 0.15; k++)
            i = k;
        return i;
    }

    Connections {
        target: Mpris
        function onPositionChanged() {
            root.basePosition = Mpris.position;
            root.baseTime = Date.now();
        }
    }

    // Only ticks while something shows lyrics (see `users`).
    property int users: 0
    Timer {
        interval: 100
        repeat: true
        running: root.users > 0 && root.synced && Mpris.playing
        onTriggered: root.position = root.basePosition + (Date.now() - root.baseTime) / 1000
    }

    onKeyChanged: fetchTimer.restart()

    // Players often change title and artist in separate updates; wait for both.
    Timer {
        id: fetchTimer
        interval: 400
        onTriggered: root.fetch()
    }

    // LRCLIB answers 503 when overloaded; retry a few times before giving up.
    property int attempts: 0
    Timer {
        id: retryTimer
        interval: 4000
        onTriggered: root.fetch(true)
    }
    function retryOrFail(requestKey) {
        if (requestKey !== key)
            return;
        if (attempts < 3) {
            attempts++;
            retryTimer.restart();
        } else {
            loading = false;
            status = "error";
        }
    }

    function fetch(retry) {
        if (!retry) {
            attempts = 0;
            retryTimer.stop();
        }
        lines = [];
        synced = false;
        status = "";
        position = Mpris.position;
        if (title === "")
            return;
        const cached = cache[key];
        if (cached) {
            apply(cached);
            return;
        }
        loading = true;
        const q = `track_name=${encodeURIComponent(title)}&artist_name=${encodeURIComponent(artist)}`;
        const duration = Mpris.length > 0 ? `&duration=${Math.round(Mpris.length)}` : "";
        const requestKey = key;
        request(`https://lrclib.net/api/get?${q}${duration}`, (ok, data, code) => {
            if (requestKey !== root.key)
                return;
            if (ok && (data.syncedLyrics || data.plainLyrics))
                return root.store(requestKey, data);
            if (code !== 404)
                return root.retryOrFail(requestKey);
            // No exact match (e.g. duration differs): search and prefer a synced result.
            request(`https://lrclib.net/api/search?${q}`, (ok2, results) => {
                if (requestKey !== root.key)
                    return;
                if (!ok2)
                    return root.retryOrFail(requestKey);
                const best = Array.isArray(results) ? (results.find(r => r.syncedLyrics) ?? results.find(r => r.plainLyrics)) : null;
                if (best) {
                    root.store(requestKey, best);
                } else {
                    root.loading = false;
                    root.status = "not found";
                }
            });
        });
    }

    function store(key, data) {
        const parsed = parse(data);
        const next = Object.assign({}, cache);
        next[key] = parsed;
        cache = next;
        apply(parsed);
    }

    function apply(parsed) {
        lines = parsed.lines;
        synced = parsed.synced;
        loading = false;
        status = lines.length ? "" : "not found";
    }

    // LRC: "[01:23.45] text" (a line may carry several timestamps).
    function parse(data) {
        if (data.syncedLyrics) {
            const out = [];
            for (const raw of data.syncedLyrics.split("\n")) {
                const stamps = [...raw.matchAll(/\[(\d+):(\d+(?:\.\d+)?)\]/g)];
                const text = raw.replace(/\[[^\]]*\]/g, "").trim();
                for (const s of stamps)
                    out.push({ time: Number(s[1]) * 60 + Number(s[2]), text });
            }
            out.sort((a, b) => a.time - b.time);
            return { synced: true, lines: out };
        }
        return { synced: false, lines: (data.plainLyrics ?? "").split("\n").map(text => ({ time: -1, text: text.trim() })) };
    }

    function request(url, done) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let data = null;
            try {
                data = JSON.parse(xhr.responseText);
            } catch (e) {}
            done(xhr.status === 200 && data !== null, data, xhr.status);
        };
        xhr.open("GET", url);
        xhr.send();
    }
}
