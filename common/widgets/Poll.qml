import QtQuick
import Quickshell.Io

// Runs a shell command now and then and keeps what it printed: for widgets that show the output of a script.
//   Poll { command: "date +%H:%M"; interval: 30; onResult: text => label.text = text }
// `interval` is in seconds (0 = once). The command runs through `sh -c`; a run that is still going is not started twice.
Item {
    id: root

    property string command: ""
    property real interval: 5
    property bool active: true
    // What the last run printed on stdout, without the trailing newline; and its exit code.
    property string output: ""
    property int exitCode: 0
    property bool ran: false

    signal result(string text)

    function run() {
        if (root.command === "" || proc.running)
            return;
        proc.command = ["sh", "-c", root.command];
        proc.running = true;
    }

    visible: false
    width: 0
    height: 0

    onCommandChanged: if (active) run()
    onActiveChanged: if (active) run()
    Component.onCompleted: if (active) run()

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                root.output = text.replace(/\n$/, "");
                root.ran = true;
                root.result(root.output);
            }
        }
        onExited: code => root.exitCode = code
    }

    Timer {
        running: root.active && root.interval > 0 && root.command !== ""
        interval: Math.max(1, root.interval) * 1000
        repeat: true
        onTriggered: root.run()
    }
}
