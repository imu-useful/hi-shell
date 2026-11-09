import QtQuick
import Quickshell
import Quickshell.Io

// Plays a file from sounds/secret on repeat while `playing`: mpv, else ffplay (both loop); with
// only pw-play it plays once. Stopping kills the player (it's exec'd, so there is no shell left over).
Process {
    id: root

    required property string file
    property bool playing: false

    running: playing
    command: ["sh", "-c", `f="$1"; if command -v mpv >/dev/null; then exec mpv --no-video --really-quiet --loop-file=inf "$f";
        elif command -v ffplay >/dev/null; then exec ffplay -nodisp -loglevel quiet -loop 0 "$f";
        else exec pw-play "$f"; fi`, "sh", Quickshell.shellPath(`sounds/secret/${file}`)]
}
