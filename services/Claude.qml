pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Claude chat through the `claude` CLI (Claude Code), shared by the quick
// palette (Super+Y) and the left sidebar. Answers stream in; follow-ups resume
// the CLI session. Chats are saved to ~/.local/state/hi-shell/claude-chats.json
// and can be reopened; each tracks tokens and cost reported by the CLI.
Singleton {
    id: root

    // Current chat. Each entry: { role: "user" | "assistant" | "error", text, done }
    property ListModel messages: ListModel {}
    property string sessionId: ""
    property string chatId: ""
    readonly property bool busy: proc.running

    // Usage of the current chat, from the CLI's result events.
    property int inputTokens: 0
    property int outputTokens: 0
    property real costUsd: 0

    // Saved chats, newest first: [{ id, title, sessionId, model, updated, messages, inputTokens, outputTokens, costUsd }]
    property var chats: []

    // "" = the CLI's default, or an alias the CLI accepts (opus, sonnet, haiku).
    property string model: Config.options.ai.model
    readonly property var models: [
        { id: "", name: Translation.tr("Default") },
        { id: "opus", name: "Opus" },
        { id: "sonnet", name: "Sonnet" },
        { id: "haiku", name: "Haiku" }
    ]

    property bool gotResult: false
    property bool cancelled: false

    function send(prompt) {
        const text = prompt.trim();
        if (busy || text === "")
            return;
        if (chatId === "")
            chatId = String(Date.now());

        messages.append({ role: "user", text: text, done: true });
        messages.append({ role: "assistant", text: "", done: false });
        gotResult = false;
        cancelled = false;

        const args = ["-p", "--output-format", "stream-json", "--include-partial-messages", "--verbose",
            // Chat only: no file edits or shell commands from the shell UI.
            "--tools="];
        if (model !== "")
            args.push("--model", model);
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

    // Start a new chat (the current one stays in the history).
    function reset() {
        cancel();
        messages.clear();
        sessionId = "";
        chatId = "";
        inputTokens = outputTokens = 0;
        costUsd = 0;
    }

    function open(id) {
        const chat = chats.find(c => c.id === id);
        if (!chat || busy)
            return;
        messages.clear();
        for (const m of chat.messages)
            messages.append({ role: m.role, text: m.text, done: true });
        chatId = chat.id;
        sessionId = chat.sessionId;
        inputTokens = chat.inputTokens ?? 0;
        outputTokens = chat.outputTokens ?? 0;
        costUsd = chat.costUsd ?? 0;
    }

    function remove(id) {
        if (id === chatId)
            reset();
        chats = chats.filter(c => c.id !== id);
        saveFile();
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
        saveChat();
    }

    // Store the current chat in the history.
    function saveChat() {
        if (chatId === "" || messages.count === 0)
            return;
        const list = [];
        for (let i = 0; i < messages.count; i++) {
            const m = messages.get(i);
            list.push({ role: m.role, text: m.text });
        }
        const first = list.find(m => m.role === "user")?.text ?? "Chat";
        const chat = {
            id: chatId,
            title: first.length > 60 ? first.slice(0, 57) + "…" : first,
            sessionId,
            model,
            updated: Date.now(),
            messages: list,
            inputTokens,
            outputTokens,
            costUsd
        };
        chats = [chat, ...chats.filter(c => c.id !== chatId)].slice(0, 50);
        saveFile();
    }

    function saveFile() {
        store.setText(JSON.stringify(chats));
    }

    // "12.3k"
    function formatTokens(n) {
        return n >= 1000 ? `${(n / 1000).toFixed(1)}k` : String(n);
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
            const u = ev.usage ?? {};
            inputTokens += (u.input_tokens ?? 0) + (u.cache_read_input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0);
            outputTokens += u.output_tokens ?? 0;
            costUsd += ev.total_cost_usd ?? 0;
            if (ev.is_error)
                finish("error", ev.result || Translation.tr("Claude returned an error (%1).").arg(ev.subtype));
            else if (current().text === "")
                finish(undefined, ev.result || "");
            else
                finish();
        }
    }

    onModelChanged: if (Config.options.ai.model !== model) Config.options.ai.model = model

    IpcHandler {
        target: "claude"

        // One "id<TAB>title" line per saved chat, newest first.
        function chats(): string {
            return root.chats.map(c => `${c.id}\t${c.title}`).join("\n");
        }
        function deleteChat(id: string): void {
            root.remove(id);
        }
        function newChat(): void {
            root.reset();
        }
    }

    FileView {
        id: store
        path: Paths.state + "/claude-chats.json"
        printErrors: false
        onLoaded: {
            try {
                root.chats = JSON.parse(text());
            } catch (e) {
                console.warn("Claude: invalid chat history", e);
            }
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
                root.finish(undefined, cur.text === "" ? Translation.tr("_Stopped._") : cur.text + "\n\n_Stopped._");
            else if (exitCode === 127)
                root.finish("error", Translation.tr("The `claude` CLI was not found. Install Claude Code and make sure `claude` is on PATH."));
            else
                root.finish("error", stderr.text.trim() || Translation.tr("claude exited with code %1.").arg(exitCode));
        }
    }
}
