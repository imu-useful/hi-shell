import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

// Typing and checking the password. The characters go to `buffer` (nothing else sees them);
// Enter sends it to PAM, and success unlocks.
Scope {
    id: root

    enum State {
        None,
        Error,
        MaxTries,
        Failed
    }

    required property WlSessionLock lock

    readonly property alias passwd: passwd
    property string lockMessage
    property int state
    property string buffer
    property bool capsLock

    signal flashMsg

    function handleKey(event: KeyEvent): void {
        if (passwd.active || state === Pam.MaxTries)
            return;

        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            if (buffer.length > 0)
                passwd.start();
        } else if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_U) && (event.modifiers & Qt.ControlModifier)) {
            buffer = "";
        } else if (event.key === Qt.Key_Backspace) {
            buffer = buffer.slice(0, -1);
        } else if (/^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text)) {
            // Anything but control characters.
            buffer += event.text;
        }
    }

    PamContext {
        id: passwd

        config: "hi-shell-lock"
        configDirectory: Quickshell.shellPath("modules/lock/pam.d")

        onMessageChanged: {
            if (message.startsWith("The account is locked"))
                root.lockMessage = message;
            else if (root.lockMessage && message.endsWith(" left to unlock)"))
                root.lockMessage += "\n" + message;
        }

        onResponseRequiredChanged: {
            if (!responseRequired)
                return;
            respond(root.buffer);
            root.buffer = "";
        }

        onCompleted: result => {
            if (result === PamResult.Success)
                return root.lock.unlock();

            root.state = result === PamResult.Error ? Pam.Error
                : result === PamResult.MaxTries ? Pam.MaxTries : Pam.Failed;
            root.flashMsg();
            reset.restart();
        }
    }

    Timer {
        id: reset
        interval: 4000
        onTriggered: {
            if (root.state !== Pam.MaxTries)
                root.state = Pam.None;
        }
    }

    // Caps Lock has no event to listen to: the keyboard LED says (checked while locked).
    Process {
        id: caps
        command: ["sh", "-c", "cat /sys/class/leds/*capslock/brightness 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.capsLock = text.split("\n").some(line => line.trim() === "1")
        }
    }

    Timer {
        interval: 700
        repeat: true
        triggeredOnStart: true
        running: root.lock.locked
        onTriggered: caps.running = true
    }
}
