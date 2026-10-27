pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Power saving, turned on by hand (Settings › Quick). It switches off what costs the most
// CPU and GPU: animations, blur and transparency, the visualizer, the dancing frame and
// cover mode, and it checks the weather less often. The values it changes are kept in
// config (powerSaving.saved), so turning it off puts them back, also after a restart.
Singleton {
    id: root

    readonly property bool enabled: Config.options.powerSaving.enabled

    function apply(on) {
        const c = Config.options;
        const p = c.powerSaving;
        if (on === p.enabled)
            return;
        if (on) {
            p.saved = {
                animationSpeed: c.appearance.animationSpeed,
                transparency: c.appearance.transparency,
                visualizer: c.desktop.visualizer,
                coverMode: c.desktop.coverMode,
                frameDance: c.wallpapers.frameDance,
                refreshMinutes: c.weather.refreshMinutes
            };
            c.appearance.animationSpeed = 0;
            c.appearance.transparency = false;
            c.desktop.visualizer = false;
            c.desktop.coverMode = false;
            c.wallpapers.frameDance = false;
            c.weather.refreshMinutes = 60;
            p.enabled = true;
            // Blur and Hyprland's animations: remember them, then turn them off.
            hyprQuery.running = true;
        } else {
            const s = p.saved;
            c.appearance.animationSpeed = s.animationSpeed ?? 1;
            c.appearance.transparency = s.transparency ?? true;
            c.desktop.visualizer = s.visualizer ?? true;
            c.desktop.coverMode = s.coverMode ?? false;
            c.wallpapers.frameDance = s.frameDance ?? true;
            c.weather.refreshMinutes = s.refreshMinutes ?? 15;
            hyprSet(true);
            p.saved = {};
            p.enabled = false;
        }
    }

    // Blur and animations in Hyprland (`on` = put back what they were).
    function hyprSet(on) {
        const h = Config.options.powerSaving.saved.hypr ?? {};
        const blur = on ? (h.blur ?? true) : false;
        const animations = on ? (h.animations ?? true) : false;
        Quickshell.execDetached(["hyprctl", "eval", `hl.config({ decoration = { blur = { enabled = ${blur} } }, animations = { enabled = ${animations} } })`]);
    }

    Process {
        id: hyprQuery
        command: ["sh", "-c", "hyprctl getoption decoration:blur:enabled -j; hyprctl getoption animations:enabled -j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const h = {};
                for (const line of text.split("\n").filter(l => l.trim())) {
                    try {
                        const o = JSON.parse(line);
                        if (o.option === "decoration:blur:enabled")
                            h.blur = o.bool;
                        else if (o.option === "animations:enabled")
                            h.animations = o.bool;
                    } catch (e) {}
                }
                Config.options.powerSaving.saved = Object.assign({}, Config.options.powerSaving.saved, { hypr: h });
                root.hyprSet(false);
            }
        }
    }

    // After a shell restart with the mode on: Hyprland's settings are its own again.
    Timer {
        running: root.enabled
        interval: 3000
        onTriggered: root.hyprSet(false)
    }
}
