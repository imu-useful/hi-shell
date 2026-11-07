pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Pending package updates: repo packages via checkupdates (pacman-contrib),
// AUR via yay / paru. `run()` opens a terminal with the system upgrade.
// NixOS has none of that: its updates come with nixos-rebuild, so this stays off there.
Singleton {
    id: root

    readonly property var options: Config.options.updates
    readonly property bool supported: Distro.id !== "nixos"

    // [{ name, from, to, aur }]
    property var packages: []
    readonly property int count: packages.length
    readonly property int aurCount: packages.filter(p => p.aur).length
    readonly property bool checking: checker.running
    property string error: ""
    property real lastCheck: 0
    property string aurHelper: ""

    // The shell itself: how many changes its update would bring (-1: not checked, or no network).
    // A git checkout, so it's the repo's upstream (git channel) or its newest release tag (release).
    readonly property string repo: Quickshell.shellDir
    property int shellBehind: -1
    // What the update brings: the release's tag and notes, or the new commits (git)
    property string shellRelease: ""
    property string shellNotes: ""
    // True once the first check has finished (the update window waits for it)
    property bool shellChecked: false
    readonly property bool shellChecking: shellChecker.running
    readonly property bool upgradeRunning: upgrade.running

    function checkShell() {
        if (!shellChecker.running && !upgrade.running)
            shellChecker.running = true;
    }

    function refresh() {
        if (options.enabled && supported && !checker.running && !upgrade.running)
            checker.running = true;
        checkShell();
    }

    // The shell's update (update.sh in the terminal: pulls, restarts the shell).
    function updateShell() {
        runInTerminal(`"${repo}/update.sh"`);
    }

    // The upgrade of the packages, then the shell's update when there is one.
    function run() {
        const packages = aurHelper && options.aur ? aurHelper : "sudo pacman -Syu";
        const steps = [];
        if (supported && count > 0)
            steps.push(packages);
        if (shellBehind !== 0)
            steps.push(`"${repo}/update.sh"`);
        runInTerminal(steps.join("; ") || "true");
    }

    function runInTerminal(cmd) {
        if (upgrade.running)
            return;
        upgrade.command = [Config.options.apps.terminal, "-e", "bash", "-c", `${cmd}; echo; read -n 1 -s -r -p 'Done. Press any key to close'`];
        upgrade.running = true;
    }

    Process {
        id: shellChecker
        // Line 1: how many changes. Release: line 2 is the tag, then its notes. Git: the new commits ("hash subject").
        command: ["sh", "-c", `cd "${root.repo}" && git fetch -q --tags 2>/dev/null || exit 1; ` + (Config.options.update.channel === "release"
            ? `latest=$(git tag -l 'v*' --sort=-v:refname | head -1); current=$(git describe --tags --abbrev=0 2>/dev/null); if [ "$latest" = "$current" ]; then echo 0; else echo 1; echo "$latest"; git for-each-ref --format='%(contents)' "refs/tags/$latest" | head -30; fi`
            : `git rev-list --count HEAD..@{u} || exit 1; git log -10 --format='%h %s' HEAD..@{u}`)]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const n = parseInt(lines[0], 10);
                const release = Config.options.update.channel === "release";
                root.shellRelease = release && n > 0 ? (lines[1] ?? "") : "";
                root.shellNotes = (n > 0 ? lines.slice(release ? 2 : 1) : []).join("\n").trim();
                root.shellBehind = isNaN(n) ? -1 : n;
                root.shellChecked = true;
            }
        }
        onExited: code => {
            if (code !== 0)
                root.shellBehind = -1;
        }
    }

    // "name 1.0-1 -> 1.1-1"
    function parse(lines, aur) {
        return lines.split("\n").map(l => l.trim().split(/\s+/)).filter(f => f.length >= 4 && f[2] === "->")
            .map(f => ({ name: f[0], from: f[1], to: f[3], aur }));
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v yay || command -v paru"]
        stdout: StdioCollector {
            onStreamFinished: root.aurHelper = text.trim().split("/").pop()
        }
    }

    Process {
        id: checker
        // checkupdates exits 2 when there is nothing to update.
        command: ["sh", "-c", `checkupdates --nocolor; s=$?; [ $s -le 2 ] || exit $s; echo '::aur::'; ${root.options.aur && root.aurHelper ? root.aurHelper + " -Qua 2>/dev/null" : "true"}; exit 0`]
        stdout: StdioCollector {
            onStreamFinished: {
                const [repo, aur] = text.split("::aur::");
                root.packages = [...root.parse(repo ?? "", false), ...root.parse(aur ?? "", true)];
                root.lastCheck = Date.now();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: root.error = text.trim()
        }
        onExited: code => {
            if (code === 0)
                root.error = "";
        }
    }

    Process {
        id: upgrade
        onExited: root.refresh()
    }

    Timer {
        running: root.options.enabled
        interval: Math.max(10, root.options.intervalMinutes) * 60000
        repeat: true
        onTriggered: root.refresh()
    }

    // First check shortly after startup, once the network is likely up.
    Timer {
        running: root.options.enabled
        interval: 30000
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "updates"

        function refresh(): void {
            root.refresh();
        }
        function count(): int {
            return root.count;
        }
    }
}
