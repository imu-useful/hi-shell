pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.common

// Is a microphone or a camera in use? From PipeWire's links: a capture stream (Stream/Input/*)
// fed by a real source (Audio/Source, Audio/Source/Virtual such as EasyEffects' mic, Video/Source).
// Streams fed by a sink's monitor (visualizers, recorders of the desktop sound) aren't the mic, and
// neither are the effects chains' own streams. Apps that open the camera directly (Telegram, OBS, most
// browsers: /dev/video*) don't go through PipeWire; for them inotify tells when a camera device is opened or
// closed, and `fuser` then says who has it (not PipeWire's own probing).
Singleton {
    id: root

    readonly property var groups: Pipewire.linkGroups.values

    // The properties of a node are filled in once it is tracked.
    PwObjectTracker {
        objects: {
            const nodes = [];
            for (const g of root.groups)
                nodes.push(g.source, g.target);
            return nodes.filter(n => n !== null);
        }
    }

    function mediaClass(node) {
        return node?.properties["media.class"] ?? "";
    }
    function isEffects(node) {
        const p = node?.properties ?? {};
        return `${p["application.name"] ?? ""} ${p["application.id"] ?? ""} ${p["node.name"] ?? ""}`.toLowerCase().includes("easyeffects");
    }
    function captures(g, streamClass, sourcePattern) {
        return mediaClass(g.target) === streamClass && sourcePattern.test(mediaClass(g.source)) && !isEffects(g.target);
    }

    readonly property bool mic: groups.some(g => captures(g, "Stream/Input/Audio", /^Audio\/Source/))
    // A program has a camera device open.
    property bool direct: false
    readonly property bool camera: direct || groups.some(g => captures(g, "Stream/Input/Video", /^Video\/Source/))
    readonly property bool active: mic || camera
    // "mic" | "camera" | "both" | ""
    readonly property string kind: mic && camera ? "both" : mic ? "mic" : camera ? "camera" : ""

    readonly property bool watching: Config.options.bar.island.enabled && Config.options.bar.island.privacy

    // A camera device was opened or closed: ask who has one open (after a moment: many events come together).
    Process {
        running: root.watching
        // Without inotify-tools, look every few seconds instead.
        command: ["sh", "-c", "if command -v inotifywait >/dev/null; then exec inotifywait -m -q -e open -e close /dev/video*; else while :; do echo poll; sleep 4; done; fi"]
        stdout: SplitParser {
            onRead: look.restart()
        }
    }
    Timer {
        id: look
        interval: 250
        onTriggered: who.running = true
    }
    Process {
        id: who
        command: ["sh", "-c", 'for p in $(fuser /dev/video* 2>/dev/null); do c=$(cat /proc/$p/comm 2>/dev/null); case "$c" in pipewire*|wireplumber*) ;; *) echo "$c";; esac; done']
        stdout: StdioCollector {
            onStreamFinished: root.direct = text.trim() !== ""
        }
    }
    onWatchingChanged: {
        if (watching)
            look.restart();
        else
            direct = false;
    }
    Component.onCompleted: if (watching) look.restart()
}
