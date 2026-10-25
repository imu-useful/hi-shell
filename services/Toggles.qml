pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// State behind quick toggles that aren't covered by another service:
// night light (hyprsunset), keep awake (logind idle inhibitor, which
// hypridle respects), game mode (Hyprland eye candy off) and NetworkManager VPNs.
Singleton {
    id: root

    // --- Night light ---
    // A running hyprsunset daemon is driven over its IPC (hyprctl hyprsunset);
    // without one, hi-shell runs its own hyprsunset while the light is on.
    property bool daemon: false
    property int temperature: 6500 // current, K
    readonly property bool nightLight: ownSunset.running || (daemon && temperature < 6400)

    function setNightLight(on) {
        const k = Config.options.sidebar.nightLightTemperature;
        if (daemon) {
            sunsetCtl.command = on ? ["hyprctl", "hyprsunset", "temperature", String(k)] : ["hyprctl", "hyprsunset", "identity"];
            sunsetCtl.running = true;
            temperature = on ? k : 6500;
        } else {
            ownSunset.running = on;
        }
    }

    Process {
        id: ownSunset
        command: ["hyprsunset", "-t", String(Config.options.sidebar.nightLightTemperature)]
    }

    Process {
        id: sunsetCtl
    }

    // Is a daemon running, and at what temperature? (prints nothing without one)
    Process {
        id: sunsetQuery
        running: true
        command: ["sh", "-c", "pgrep -x hyprsunset >/dev/null && hyprctl hyprsunset temperature"]
        stdout: StdioCollector {
            onStreamFinished: {
                const k = parseInt(text);
                root.daemon = !isNaN(k) && !ownSunset.running;
                if (root.daemon)
                    root.temperature = k;
            }
        }
    }

    Timer {
        interval: 20000
        running: true
        repeat: true
        onTriggered: if (!ownSunset.running) sunsetQuery.running = true
    }

    // --- Keep awake ---
    readonly property bool keepAwake: inhibitor.running

    function setKeepAwake(on) {
        inhibitor.running = on;
    }

    Process {
        id: inhibitor
        command: ["systemd-inhibit", "--what=idle", "--who=hi-shell", "--why=Keep awake toggle", "sleep", "infinity"]
    }

    // --- Game mode ---
    property bool gameMode: false

    function setGameMode(on) {
        gameMode = on;
        // Hyprland 0.56+ (Lua config) only accepts runtime changes through eval.
        if (on)
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({ animations = { enabled = false }, decoration = { rounding = 0, blur = { enabled = false }, shadow = { enabled = false } }, general = { gaps_in = 0, gaps_out = 0, border_size = 1 } })"]);
        else
            Quickshell.execDetached(["hyprctl", "reload"]);
    }

    // --- VPN (NetworkManager connections of type vpn / wireguard) ---
    // [{ name, uuid, active }]
    property var vpns: []
    readonly property bool vpnAvailable: vpns.length > 0
    readonly property bool vpnActive: vpns.some(v => v.active)

    function refreshVpns() {
        vpnList.running = true;
    }

    function setVpn(on) {
        const target = on ? vpns[0] : vpns.find(v => v.active);
        if (!target)
            return;
        vpnToggle.command = ["nmcli", "connection", on ? "up" : "down", "uuid", target.uuid];
        vpnToggle.running = true;
    }

    Process {
        id: vpnList
        running: true
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                // nmcli -t escapes ":" inside fields as "\:"
                root.vpns = text.trim().split("\n").map(l => l.split(/(?<!\\):/).map(f => f.replace(/\\:/g, ":")))
                    .filter(f => f.length >= 4 && (f[2] === "vpn" || f[2] === "wireguard"))
                    .map(f => ({ name: f[0], uuid: f[1], active: f[3] === "yes" }));
            }
        }
    }

    Process {
        id: vpnToggle
        onExited: root.refreshVpns()
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: root.refreshVpns()
    }
}
