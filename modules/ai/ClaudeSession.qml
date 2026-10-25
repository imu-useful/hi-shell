import QtQuick
import Quickshell
import Quickshell.Io

// Runs the `claude` CLI in the background and streams its answer into `messages`.
// Follow-up prompts resume the same Claude session until reset() is called.
Scope {
    id: root

    // Each entry: { role: "user" | "assistant" | "error", text: string, done: bool }
    property ListModel messages: ListModel {}
    property string sessionId: ""
    readonly property bool busy: proc.running

    property bool gotResult: false
    property bool cancelled: false

    function send(prompt) {
        const text = prompt.trim();
        if (busy || text === "")
            return;

        messages.append({ role: "user", text: text, done: true });
        messages.append({ role: "assistant", text: "", done: false });
        gotResult = false;
        cancelled = false;

        const args = ["-p", "--output-format", "stream-json", "--include-partial-messages", "--verbose",
            // Chat only: no file edits or shell commands from the palette.
            "--tools="];
        if (sessionId !== "")
            args.push("--resume", sessionId);
        args.push("--", text);

        // Run through sh so PATH (with ~/.local/bin) is honoured; the prompt is
        // passed as an argument via "$@", never interpolated into the script.
        proc.command = ["sh", "-c", 'exec claude "$@"', "claude", ...args];
        proc.running = true;
    }

    function cancel() {
        if (!busy)
            return;
        cancelled = true;
        proc.running = false;
    }

    function reset() {
        cancel();
        messages.clear();
        sessionId = "";
    }

    function lastAnswer() {
        for (let i = messages.count - 1; i >= 0; i--) {
            const m = messages.get(i);
            if (m.role === "assistant" && m.text !== "")
                return m.text;
        }
        return "";
    }

    function current() {
        return messages.count > 0 ? messages.get(messages.count - 1) : null;
    }

    function finish(role, text) {
        const i = messages.count - 1;
        if (i < 0)
            return;
        if (role !== undefined)
            messages.setProperty(i, "role", role);
        if (text !== undefined)
            messages.setProperty(i, "text", text);
        messages.setProperty(i, "done", true);
    }

    function handleLine(line) {
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (ev.session_id)
            sessionId = ev.session_id;

        if (ev.type === "stream_event") {
            const e = ev.event;
            if (e.type === "content_block_delta" && e.delta.type === "text_delta") {
                const i = messages.count - 1;
                messages.setProperty(i, "text", messages.get(i).text + e.delta.text);
            }
        } else if (ev.type === "result") {
            gotResult = true;
            if (ev.is_error)
                finish("error", ev.result || `Claude returned an error (${ev.subtype}).`);
            else if (current().text === "")
                finish(undefined, ev.result || "");
            else
                finish();
        }
    }

    Process {
        id: proc

        workingDirectory: Quickshell.env("HOME")
        environment: ({
                PATH: `${Quickshell.env("HOME")}/.local/bin:${Quickshell.env("PATH")}`
            })

        stdout: SplitParser {
            onRead: line => root.handleLine(line)
        }
        stderr: StdioCollector {
            id: stderr
        }

        onExited: (exitCode, exitStatus) => {
            if (root.gotResult)
                return;
            const cur = root.current();
            if (root.cancelled)
                root.finish(undefined, cur.text === "" ? "_Stopped._" : cur.text + "\n\n_Stopped._");
            else if (exitCode === 127)
                root.finish("error", "The `claude` CLI was not found. Install Claude Code and make sure `claude` is on PATH.");
            else
                root.finish("error", stderr.text.trim() || `claude exited with code ${exitCode}.`);
        }
    }
}
