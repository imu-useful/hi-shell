pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Claude chat through the `claude` CLI (Claude Code), shared by the quick
// palette (Super+Y) and the left sidebar. Answers stream in; follow-ups resume
// the CLI session. With the OpenRouter provider the same chat talks to any
// OpenRouter model (the free ones are listed) over its streaming API instead;
// there the whole conversation is sent with every message. Chats are saved to ~/.local/state/hi-shell/claude-chats.json
// and can be reopened; each tracks tokens and cost reported by the CLI.
Singleton {
    id: root

    // Current chat. Each entry: { role: "user" | "assistant" | "error", text, done }
    property ListModel messages: ListModel {}
    property string sessionId: ""
    property string chatId: ""
    readonly property bool busy: proc.running || orProc.running

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

    // "claude" or "openrouter"
    property string provider: Config.options.ai.provider
    readonly property bool openrouter: provider === "openrouter"
    property string openrouterModel: Config.options.ai.openrouterModel
    // Free OpenRouter models, [{ id, name }], loaded on demand.
    property var freeModels: []
    property bool loadingModels: false
    property string modelsError: ""
    // What the sidebar shows as the current model.
    readonly property string modelName: openrouter ? (freeModels.find(m => m.id === openrouterModel)?.name ?? openrouterModel) : model

    // The request body is passed through the environment and the key through a
    // curl config on a pipe, so neither the key nor its header shows in `ps`.
    readonly property int maxBodyBytes: 100000
    readonly property string curlScript: 'exec curl -sS -N --max-time 600 -K <(printf \'header = "Authorization: Bearer %s"\\n\' "$OR_KEY") '
        + '-H "Content-Type: application/json" -H "X-Title: hi-shell" --data-binary "$OR_BODY" https://openrouter.ai/api/v1/chat/completions'

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

        if (openrouter) {
            sendOpenRouter();
            return;
        }

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

    // The conversation so far as chat messages, newest last, within maxBodyBytes.
    function conversation() {
        const list = [];
        for (let i = 0; i < messages.count - 1; i++) {
            const m = messages.get(i);
            if ((m.role === "user" || m.role === "assistant") && m.text !== "")
                list.push({ role: m.role, content: m.text });
        }
        const body = () => JSON.stringify({ model: openrouterModel, stream: true, usage: { include: true }, messages: list });
        while (list.length > 1 && body().length > maxBodyBytes)
            list.shift();
        return body();
    }

    function sendOpenRouter() {
        const key = Config.options.ai.openrouterKey;
        if (key === "")
            return finishWith("error", Translation.tr("Add your OpenRouter API key in Settings → General."));
        if (openrouterModel === "")
            return finishWith("error", Translation.tr("Pick an OpenRouter model first."));
        orProc.environment = ({
            PATH: `${Quickshell.env("HOME")}/.local/bin:${Quickshell.env("PATH")}`,
            OR_KEY: key,
            OR_BODY: conversation()
        });
        orProc.command = ["bash", "-c", curlScript];
        orProc.running = true;
    }

    function finishWith(role, text) {
        gotResult = true;
        finish(role, text);
    }

    // OpenRouter's free models (prompt and completion both cost nothing).
    function loadFreeModels() {
        if (loadingModels)
            return;
        loadingModels = true;
        modelsError = "";
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            loadingModels = false;
            try {
                if (xhr.status !== 200)
                    throw new Error(`HTTP ${xhr.status}`);
                freeModels = JSON.parse(xhr.responseText).data
                    .filter(m => Number(m.pricing?.prompt) === 0 && Number(m.pricing?.completion) === 0)
                    .map(m => ({ id: m.id, name: m.name ?? m.id }))
                    .sort((a, b) => a.name.localeCompare(b.name));
            } catch (e) {
                modelsError = Translation.tr("Couldn't load the model list (%1)").arg(e.message);
            }
        };
        xhr.open("GET", "https://openrouter.ai/api/v1/models");
        xhr.send();
    }

    function cancel() {
        if (!busy)
            return;
        cancelled = true;
        proc.running = false;
        orProc.running = false;
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
        provider = chat.provider ?? "claude";
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
            provider,
            model: openrouter ? openrouterModel : model,
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

    // One server event of an OpenRouter stream: "data: {json}" lines, ": comment" keep-alives
    // and "data: [DONE]". An error before the stream starts comes as a plain JSON line.
    function handleOpenRouterLine(line) {
        const payload = line.startsWith("data:") ? line.slice(5).trim() : line.trim();
        if (payload === "" || payload === "[DONE]" || payload.startsWith(":"))
            return;
        let ev;
        try {
            ev = JSON.parse(payload);
        } catch (e) {
            return;
        }
        if (ev.error)
            return finishWith("error", ev.error.message ?? Translation.tr("OpenRouter returned an error."));
        const delta = ev.choices?.[0]?.delta?.content;
        if (delta) {
            const i = messages.count - 1;
            messages.setProperty(i, "text", messages.get(i).text + delta);
        }
        if (ev.usage) {
            inputTokens += ev.usage.prompt_tokens ?? 0;
            outputTokens += ev.usage.completion_tokens ?? 0;
            costUsd += ev.usage.cost ?? 0;
        }
    }

    onModelChanged: if (Config.options.ai.model !== model) Config.options.ai.model = model
    onProviderChanged: if (Config.options.ai.provider !== provider) Config.options.ai.provider = provider
    onOpenrouterModelChanged: if (Config.options.ai.openrouterModel !== openrouterModel) Config.options.ai.openrouterModel = openrouterModel

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

    Process {
        id: orProc

        workingDirectory: Quickshell.env("HOME")

        stdout: SplitParser {
            onRead: line => root.handleOpenRouterLine(line)
        }
        stderr: StdioCollector {
            id: orStderr
        }

        onExited: (exitCode, exitStatus) => {
            if (root.gotResult)
                return;
            const cur = root.current();
            if (root.cancelled)
                root.finish(undefined, cur.text === "" ? Translation.tr("_Stopped._") : cur.text + "\n\n_Stopped._");
            else if (exitCode !== 0)
                root.finish("error", orStderr.text.trim() || Translation.tr("curl exited with code %1.").arg(exitCode));
            else if (cur.text === "")
                root.finish("error", Translation.tr("The model returned an empty answer."));
            else
                root.finish();
        }
    }
}
