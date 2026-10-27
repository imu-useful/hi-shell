import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Wait Mode: a screen for the person while an AI (or anything else) works on the machine.
// A separate Quickshell instance, so it keeps going when hi-shell restarts; start and stop
// it with wait-mode.sh. The person is shut out: the screen is covered by an overlay that
// takes keyboard and pointer, Hyprland's key binds are off (the "hi-wait" submap, see
// hypr/hi-shell.lua), and the machine doesn't sleep. Esc three times ends it.
//
// For automated tests, `qs -p <this folder> ipc call waitmode bypass true [seconds]` makes the
// overlay invisible and click-through and gives the keyboard back, so screenshots show the
// windows underneath and ydotool / wtype / hyprctl reach them. It comes back by itself after
// the seconds (30 by default, 300 at most) or with `bypass false`. Notifications are
// hi-shell's own windows, above this one.
ShellRoot {
    id: root

    settings.watchFiles: false

    property bool bypass: false
    property int escapes: 0
    property bool bindsBlocked: false

    // The cover shows the player that is playing, else the one that has a track.
    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))
    readonly property MprisPlayer player: players.find(p => p.isPlaying) ?? players.find(p => p.trackTitle) ?? null
    // HI_WAIT_NO_MUSIC=1 shows the no-music cover even while something plays (to try it out).
    readonly property bool hasMusic: !Quickshell.env("HI_WAIT_NO_MUSIC") && player !== null && player.trackTitle !== ""

    // --- The player's own controls (the cover's buttons) ---
    readonly property bool shuffle: !!player?.shuffle
    readonly property bool shuffleSupported: !!player?.shuffleSupported
    readonly property bool loopSupported: !!player?.loopSupported
    readonly property bool loopOff: (player?.loopState ?? MprisLoopState.None) === MprisLoopState.None
    readonly property bool loopTrack: (player?.loopState ?? MprisLoopState.None) === MprisLoopState.Track

    function toggleShuffle() {
        if (player?.shuffleSupported)
            player.shuffle = !player.shuffle;
    }
    // Off -> the whole playlist -> one track -> off.
    function cycleLoop() {
        if (!player?.loopSupported)
            return;
        const s = player.loopState;
        player.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist
            : s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
    }

    // --- Spotify's queue, from hi-shell's services/spotify.py (needs its sign-in) ---
    readonly property bool isSpotify: !!player && player.dbusName.toLowerCase().includes("spotify")
    property var queue: [] // [{ name, artists, art }]
    function refreshQueue() {
        if (isSpotify && hasMusic && !queueProc.running)
            queueProc.running = true;
    }
    Process {
        id: queueProc
        command: ["python3", Quickshell.shellDir + "/../services/spotify.py", "queue"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.queue = d.status === "ok" ? (d.queue ?? []).slice(0, 6) : [];
                } catch (e) {
                    root.queue = [];
                }
            }
        }
    }
    onIsSpotifyChanged: isSpotify ? refreshQueue() : queue = []
    Connections {
        target: root.player
        function onTrackTitleChanged() { queueLater.restart(); }
    }
    Timer {
        id: queueLater
        interval: 1500
        onTriggered: root.refreshQueue()
    }
    // Also now and then: the queue changes when tracks are added elsewhere.
    Timer {
        running: root.isSpotify
        interval: 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshQueue()
    }

    function pressEsc() {
        escapes++;
        escTimer.restart();
        if (escapes >= 3)
            quit();
    }

    // Binds back first, then out.
    function quit() {
        Quickshell.execDetached(["hyprctl", "eval", 'hl.dispatch(hl.dsp.submap("reset"))']);
        Qt.quit();
    }

    function setBypass(on, seconds) {
        bypass = on;
        escapes = 0;
        if (on) {
            bypassTimer.interval = Math.max(1, Math.min(seconds > 0 ? seconds : 30, 300)) * 1000;
            bypassTimer.restart();
        } else {
            bypassTimer.stop();
        }
    }

    Variants {
        model: Quickshell.screens

        Overlay {
            control: root
        }
    }

    // Three Esc presses count only when they come close together.
    Timer {
        id: escTimer
        interval: 4000
        onTriggered: root.escapes = 0
    }
    // The cover comes back by itself.
    Timer {
        id: bypassTimer
        onTriggered: root.setBypass(false, 0)
    }
    // MPRIS doesn't push the position.
    Timer {
        running: root.player?.isPlaying ?? false
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    // Keep the machine awake (the overlay's IdleInhibitor does the screen).
    Process {
        running: true
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=hi-wait-mode", "--why=Wait Mode is on", "sleep", "infinity"]
    }

    // Key binds off: the empty "hi-wait" submap. If the config doesn't have it (hi-shell's
    // Hyprland file not loaded yet), the cover still works, but the binds do too.
    Component.onCompleted: {
        Quickshell.execDetached(["hyprctl", "eval", 'hl.dispatch(hl.dsp.submap("hi-wait"))']);
        submapCheck.running = true;
    }
    Process {
        id: submapCheck
        command: ["sh", "-c", "sleep 0.5; hyprctl submap"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.bindsBlocked = text.trim() === "hi-wait";
                if (!root.bindsBlocked)
                    console.warn("Wait Mode: Hyprland has no 'hi-wait' submap; key binds stay on. Reload Hyprland (hyprctl reload) with hi-shell's hypr/hi-shell.lua.");
            }
        }
    }

    IpcHandler {
        target: "waitmode"

        // Make the cover invisible and click-through for a while (tests, AI).
        function bypass(on: bool, seconds: int): void {
            root.setBypass(on, seconds);
        }
        function stop(): void {
            root.quit();
        }
        function status(): string {
            return `${root.bypass ? "bypass" : "locked"} esc=${root.escapes} music=${root.hasMusic} binds=${root.bindsBlocked ? "blocked" : "open"}`;
        }
    }
}
