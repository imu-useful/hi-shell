pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Spotify's playback queue through the Web API (services/spotify.py): the queue, a track
// search and adding to the queue. Needs the Client ID (Settings › Services › Spotify) and a
// one-time sign-in in the browser (PKCE, no secret); queue management needs Premium.
// Only fetched while the queue view is open (`users`) and the track changes.
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/services/spotify.py"
    readonly property bool configured: Config.options.spotify.clientId.trim() !== ""

    // "idle" | "ok" | "needs_setup" | "needs_auth" | "error"
    property string status: "idle"
    property string message: ""
    property var playing: null // { name, artists, uri, art }
    property var queue: []
    property var results: []
    property string lastQuery: ""
    // While signing in: what the sign-in said, and the address when the browser didn't open.
    property string authNote: ""
    property string authUrl: ""
    // Views that want the queue (it isn't fetched otherwise).
    property int users: 0

    // The API says another track plays than the player does: the Spotify app isn't sending
    // its state up (a network or VPN problem), so the queue can't be known. Spotify also lags
    // a few seconds behind after every track change, so it's asked again a few times first.
    property int tries: 0
    readonly property bool stale: status === "ok" && playing !== null && Mpris.isSpotify && playing.name !== Mpris.title

    readonly property bool loading: fetcher.running
    readonly property bool searching: searcher.running
    readonly property bool connecting: authProc.running

    function refresh() {
        if (!configured) {
            status = "needs_setup";
            return;
        }
        if (fetcher.running)
            return;
        fetcher.command = ["python3", script, "queue"];
        fetcher.running = true;
    }

    function search(query) {
        const q = query.trim();
        lastQuery = q;
        if (q === "") {
            results = [];
            return;
        }
        searcher.running = false;
        searcher.command = ["python3", script, "search", q];
        searcher.running = true;
    }

    function add(uri) {
        if (adder.running)
            return;
        adder.command = ["python3", script, "add", uri];
        adder.running = true;
    }

    function connect() {
        if (authProc.running)
            return;
        authNote = "";
        authUrl = "";
        message = "";
        authProc.running = true;
    }

    function cancelConnect() {
        authProc.running = false;
    }

    function disconnect() {
        logout.running = true;
    }

    // Jump to a track of the list (0 = playing, 1 = next, ...) by skipping forward that
    // many times: the queue API can't start a queue entry, but the player's Next does.
    property int skipsLeft: 0
    function playAt(index) {
        if (index < 1 || skipsLeft > 0)
            return;
        skipsLeft = index;
        skipTimer.start();
    }
    Timer {
        id: skipTimer
        interval: 350
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            Mpris.next();
            if (--root.skipsLeft <= 0)
                stop();
        }
    }

    // One JSON object per command.
    function parse(text) {
        try {
            return JSON.parse(text);
        } catch (e) {
            return { status: "error", message: Translation.tr("Unexpected response") };
        }
    }

    Process {
        id: fetcher
        stdout: StdioCollector {
            onStreamFinished: {
                const d = root.parse(text);
                root.status = d.status;
                root.message = d.message ?? "";
                if (d.status === "ok") {
                    root.playing = d.playing ?? null;
                    root.queue = d.queue ?? [];
                    if (root.stale && root.tries < 6) {
                        root.tries++;
                        refreshLater.interval = 2000;
                        refreshLater.restart();
                    }
                }
            }
        }
    }

    Process {
        id: searcher
        stdout: StdioCollector {
            onStreamFinished: {
                const d = root.parse(text);
                if (d.status === "ok")
                    root.results = d.tracks ?? [];
                else {
                    root.status = d.status;
                    root.message = d.message ?? "";
                }
            }
        }
    }

    Process {
        id: adder
        stdout: StdioCollector {
            onStreamFinished: {
                const d = root.parse(text);
                if (d.status === "ok") {
                    ShellState.osdMessage("playlist_add", Translation.tr("Added to the queue"));
                    root.refresh();
                } else {
                    root.status = d.status;
                    root.message = d.message ?? "";
                }
            }
        }
    }

    // Sign-in: it prints what it's doing on stderr, one line at a time.
    Process {
        id: authProc
        command: ["python3", root.script, "auth"]
        stderr: SplitParser {
            onRead: line => {
                if (line.startsWith("https://"))
                    root.authUrl = line.trim();
                else if (line.trim() !== "")
                    root.authNote = line.trim();
            }
        }
        onExited: code => {
            if (code === 0) {
                root.authNote = "";
                root.authUrl = "";
                root.refresh();
            } else {
                root.status = "error";
                root.message = root.authNote || Translation.tr("Spotify sign-in failed");
                root.authUrl = "";
            }
        }
    }

    Process {
        id: logout
        command: ["python3", root.script, "logout"]
        onExited: {
            root.queue = [];
            root.playing = null;
            root.results = [];
            root.status = "needs_auth";
            root.message = "";
        }
    }

    // A new track: the queue moved on.
    Connections {
        target: Mpris
        function onTitleChanged() {
            if (root.users > 0 && root.status === "ok") {
                root.tries = 0;
                refreshLater.interval = 1500;
                refreshLater.restart();
            }
        }
    }
    Timer {
        id: refreshLater
        interval: 1500
        onTriggered: root.refresh()
    }
    onUsersChanged: if (users > 0 && configured && status !== "needs_setup") refresh()
}
