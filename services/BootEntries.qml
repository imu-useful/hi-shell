pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// What the machine can reboot into once: systemd-boot entries (bootctl; `systemctl reboot
// --boot-loader-entry` needs no password) and a Windows entry from the firmware's boot
// list (efibootmgr -n sets BootNext, which asks for the password through pkexec).
// Entries: [{ kind: "loader" | "firmware", id, title, icon }].
Singleton {
    id: root

    property var loaderEntries: []
    property var windowsEntries: []
    readonly property var entries: loaderEntries.concat(windowsEntries)
    readonly property bool available: entries.length > 0

    function refresh() {
        bootctl.running = true;
        efi.running = true;
    }

    function parseLoader(text) {
        try {
            loaderEntries = JSON.parse(text).map(e => e.id === "auto-reboot-to-firmware-setup"
                ? { kind: "loader", id: e.id, title: Translation.tr("Firmware setup (BIOS / UEFI)"), icon: "memory" }
                : { kind: "loader", id: e.id, title: e.showTitle ?? e.title ?? e.id, icon: e.id.startsWith("auto-windows") ? "window" : "terminal" });
        } catch (e) {
            loaderEntries = [];
        }
    }

    function parseEfi(text) {
        const seen = {};
        windowsEntries = text.split("\n").map(l => l.match(/^Boot([0-9A-Fa-f]{4})\*?\s+(Windows(?!.*Recovery)[^\t]*?)\s*(\t|$)/)).filter(m => m && !seen[m[1]] && (seen[m[1]] = true))
            .map(m => ({ kind: "firmware", id: m[1], title: m[2], icon: "window" }))
            // systemd-boot already lists Windows when it finds it.
            .filter(() => !loaderEntries.some(e => e.id.startsWith("auto-windows")));
    }

    // Reboots into the entry (asks for the password for a firmware one).
    function rebootInto(entry) {
        if (entry.kind === "firmware")
            Quickshell.execDetached(["sh", "-c", `pkexec efibootmgr -n ${entry.id} && systemctl reboot`]);
        else
            Quickshell.execDetached(["systemctl", "reboot", "--boot-loader-entry=" + entry.id]);
    }

    Component.onCompleted: refresh()

    Process {
        id: bootctl
        command: ["bootctl", "list", "--json=short", "--no-pager"]
        stdout: StdioCollector {
            onStreamFinished: root.parseLoader(text)
        }
    }

    Process {
        id: efi
        command: ["efibootmgr"]
        stdout: StdioCollector {
            onStreamFinished: root.parseEfi(text)
        }
    }

    IpcHandler {
        target: "boot"

        // `ipc call boot list` prints the entries; `ipc call boot reboot <id>` reboots into one.
        function list(): string {
            return root.entries.map(e => `${e.id}\t${e.title}`).join("\n");
        }
        function reboot(id: string): void {
            const e = root.entries.find(e => e.id === id);
            if (e)
                root.rebootInto(e);
        }
    }
}
