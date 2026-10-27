pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.common

// Media players (MPRIS). `active` is the player the UI controls: the one that
// most recently started playing, else any playing one, else the first.
// Toggle from Hyprland: `qs -c hi-shell ipc call mpris playPause` (next, previous).
Singleton {
    id: root

    // playerctld mirrors other players; showing it would duplicate them.
    readonly property list<MprisPlayer> players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))

    property MprisPlayer lastPlaying: null
    property MprisPlayer manual: null

    readonly property MprisPlayer active: {
        if (manual && players.includes(manual))
            return manual;
        if (lastPlaying && players.includes(lastPlaying))
            return lastPlaying;
        return players.find(p => p.isPlaying) ?? players.find(p => p.trackTitle) ?? players[0] ?? null;
    }
    readonly property bool hasPlayer: active !== null
    // The queue (Web API) is Spotify's; other players have none.
    readonly property bool isSpotify: !!active && active.dbusName.toLowerCase().includes("spotify")
    readonly property bool playing: active?.isPlaying ?? false

    readonly property string title: active?.trackTitle || Translation.tr("No media")
    readonly property string artist: active?.trackArtist ?? ""
    readonly property string album: active?.trackAlbum ?? ""
    readonly property string artUrl: active?.trackArtUrl ?? ""
    readonly property real position: active?.position ?? 0
    readonly property real length: active?.length ?? 0
    readonly property real progress: length > 0 ? Math.min(1, position / length) : 0

    // Shuffle and repeat, when the player supports them (Spotify does).
    readonly property bool shuffleSupported: !!active?.shuffleSupported
    readonly property bool shuffle: !!active?.shuffle
    readonly property bool loopSupported: !!active?.loopSupported
    readonly property int loopState: active?.loopState ?? MprisLoopState.None
    // For the UI, which can't import MprisLoopState (its own `Mpris` would hide this one).
    readonly property bool loopOff: loopState === MprisLoopState.None
    readonly property bool loopTrack: loopState === MprisLoopState.Track

    function togglePlaying() {
        if (active?.canTogglePlaying)
            active.togglePlaying();
    }
    function next() {
        if (active?.canGoNext)
            active.next();
    }
    function previous() {
        if (active?.canGoPrevious)
            active.previous();
    }
    function toggleShuffle() {
        if (active?.shuffleSupported)
            active.shuffle = !active.shuffle;
    }
    // Off -> whole playlist -> one track -> off.
    function cycleLoop() {
        if (!active?.loopSupported)
            return;
        const s = active.loopState;
        active.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist
            : s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
    }
    // `fraction` is 0..1 of the track length.
    function seekTo(fraction) {
        if (active?.canSeek && length > 0)
            active.position = Math.max(0, Math.min(1, fraction)) * length;
    }
    // Make the next player in the list the active one.
    function cyclePlayer() {
        if (players.length < 2)
            return;
        manual = players[(players.indexOf(active) + 1) % players.length];
    }

    // "1:05" / "1:02:03"
    function formatTime(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = String(s % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`;
    }

    Instantiator {
        model: Mpris.players

        Connections {
            required property MprisPlayer modelData
            target: modelData

            function onPlaybackStateChanged() {
                if (modelData.isPlaying) {
                    root.lastPlaying = modelData;
                    root.manual = null;
                }
            }
        }
    }

    // MPRIS doesn't push position updates; poll while playing.
    Timer {
        running: root.playing
        interval: 1000
        repeat: true
        onTriggered: root.active.positionChanged()
    }

    IpcHandler {
        target: "mpris"

        function playPause(): void {
            root.togglePlaying();
        }
        function next(): void {
            root.next();
        }
        function previous(): void {
            root.previous();
        }
        function shuffle(): void {
            root.toggleShuffle();
        }
        // off, playlist, track
        function repeat(): void {
            root.cycleLoop();
        }
    }
}
