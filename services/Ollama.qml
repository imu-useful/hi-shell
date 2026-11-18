pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import "AiProviders.js" as Providers

// Local models through Ollama's own API (the chat itself goes through its OpenAI-compatible one in
// Claude.qml): downloading a model with progress and removing one. The server is the chat's
// Ollama address (Settings → General), without its /v1.
Singleton {
    id: root

    readonly property string base: Providers.ollamaBase(Claude.urlFor("ollama"))

    // The download in progress (or the last one, while its error is shown).
    property string pulling: ""
    readonly property bool busy: pullProc.running
    property string status: ""
    // 0..1, or -1 while the size isn't known yet
    property real fraction: -1
    property string error: ""

    function pull(name) {
        const model = name.trim();
        if (busy)
            return;
        if (!Providers.validModelName(model)) {
            error = Translation.tr("Not a model name: %1").arg(model);
            return;
        }
        pulling = model;
        status = Translation.tr("Starting…");
        fraction = -1;
        error = "";
        pullProc.environment = ({ OLLAMA_BASE: base, OLLAMA_BODY: JSON.stringify({ model, stream: true }) });
        pullProc.running = true;
    }

    function cancelPull() {
        pullProc.running = false;
    }

    function remove(name) {
        if (!Providers.validModelName(name) || removeProc.running)
            return;
        error = "";
        removeProc.model = name;
        removeProc.environment = ({ OLLAMA_BASE: base, OLLAMA_BODY: JSON.stringify({ model: name }) });
        removeProc.running = true;
    }

    function handleLine(line) {
        const text = line.trim();
        if (text === "")
            return;
        let ev;
        try {
            ev = JSON.parse(text);
        } catch (e) {
            return;
        }
        const p = Providers.pullProgress(ev);
        if (p.error !== "") {
            error = p.error;
            return;
        }
        status = p.status;
        fraction = p.fraction;
        if (p.done) {
            if (Claude.modelFor("ollama") === "")
                Claude.setModel("ollama", pulling);
            pulling = "";
            Claude.reloadModels("ollama");
        }
    }

    Process {
        id: pullProc

        // The body and address come through the environment, never into the script.
        command: ["sh", "-c", 'exec curl -sS -N --max-time 7200 -H "Content-Type: application/json" --data-binary "$OLLAMA_BODY" "$OLLAMA_BASE/api/pull"']

        stdout: SplitParser {
            onRead: line => root.handleLine(line)
        }
        stderr: StdioCollector {
            id: pullStderr
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && root.error === "")
                root.error = exitCode === 7 ? Claude.ollamaDown() : (pullStderr.text.trim() || Translation.tr("curl exited with code %1.").arg(exitCode));
            if (root.error === "" && root.pulling !== "")
                root.error = Translation.tr("The download stopped.");
            root.status = "";
        }
    }

    Process {
        id: removeProc

        property string model: ""
        command: ["sh", "-c", 'exec curl -sS -f -X DELETE -H "Content-Type: application/json" --data-binary "$OLLAMA_BODY" "$OLLAMA_BASE/api/delete"']

        stderr: StdioCollector {
            id: removeStderr
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                if (Claude.modelFor("ollama") === model)
                    Claude.setModel("ollama", "");
                Claude.reloadModels("ollama");
            } else {
                root.error = exitCode === 7 ? Claude.ollamaDown() : Translation.tr("Couldn't remove %1 (%2)").arg(model).arg(removeStderr.text.trim() || exitCode);
            }
        }
    }
}
