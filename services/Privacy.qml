pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.common

// Is a microphone or a camera in use? From PipeWire's links: a capture stream (Stream/Input/*)
// fed by a real source (Audio/Source, Audio/Source/Virtual such as EasyEffects' mic, Video/Source).
// Streams fed by a sink's monitor (visualizers, recorders of the desktop sound) aren't the mic, and
// neither are the effects chains' own streams. Apps that open the camera without PipeWire aren't seen.
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
    readonly property bool camera: groups.some(g => captures(g, "Stream/Input/Video", /^Video\/Source/))
    readonly property bool active: mic || camera
    // "mic" | "camera" | "both" | ""
    readonly property string kind: mic && camera ? "both" : mic ? "mic" : camera ? "camera" : ""
}
