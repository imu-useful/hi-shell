pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import "AiProviders.js" as Providers

// Claude chat through the `claude` CLI (Claude Code), shared by the quick
// palette (Super+Y) and the left sidebar. Answers stream in; follow-ups resume
// the CLI session. With another provider (services/AiProviders.js: OpenRouter, OpenAI,
// Gemini, Groq, DeepSeek, Mistral, Ollama, or any OpenAI-compatible server) the same chat
// talks to that API over a stream instead; there the whole conversation is sent with
// every message. Chats are saved to ~/.local/state/hi-shell/claude-chats.json
// and can be reopened; each tracks tokens and cost reported by the CLI.
Singleton {
    id: root

    // Current chat. Each entry: { role: "user" | "assistant" | "error", text, done }
    property ListModel messages: ListModel {}
    property string sessionId: ""
    property string chatId: ""
    readonly property bool busy: proc.running || aiProc.running

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

    // "claude" or a provider id from AiProviders.js
    property string provider: Config.options.ai.provider
    readonly property var spec: provider === "claude" ? null : Providers.find(provider)
    // Not the Claude CLI: the chat goes to an OpenAI-compatible API.
    readonly property bool compat: spec !== null
    readonly property var providers: Providers.providers

    // Keys, models and URLs per provider (ai.keys / ai.models / ai.urls); OpenRouter's earlier
    // single key and model are read as a fallback.
    function keyFor(id) {
        return Config.options.ai.keys[id] ?? (id === "openrouter" ? Config.options.ai.openrouterKey : "") ?? "";
    }
    function modelFor(id) {
        return Config.options.ai.models[id] ?? (id === "openrouter" ? Config.options.ai.openrouterModel : "") ?? "";
    }
    function urlFor(id) {
        return Config.options.ai.urls[id] || Providers.find(id)?.url || "";
    }
    function setKey(id, value) {
        Config.options.ai.keys = Object.assign({}, Config.options.ai.keys, { [id]: value });
    }
    function setModel(id, value) {
        Config.options.ai.models = Object.assign({}, Config.options.ai.models, { [id]: value });
    }
    function setUrl(id, value) {
        Config.options.ai.urls = Object.assign({}, Config.options.ai.urls, { [id]: value });
    }
    // Ready to use: it has the key it needs (and a URL, for a custom server).
    function configured(id) {
        const p = Providers.find(id);
        return !!p && (!p.key || keyFor(id) !== "") && (!p.urlRequired || urlFor(id) !== "");
    }

    readonly property string apiModel: compat ? modelFor(provider) : ""
    // Model lists per provider, [{ id, name }], loaded on demand.
    property var modelLists: ({})
    readonly property var modelList: modelLists[provider] ?? []
    property bool loadingModels: false
    property string modelsError: ""
    // What the sidebar shows as the current model.
    readonly property string modelName: compat ? (modelList.find(m => m.id === apiModel)?.name ?? apiModel) : model
    readonly property string providerName: compat ? spec.name : "Claude"

    // The request body is passed through the environment and the key through a
    // curl config on a pipe, so neither the key nor its header shows in `ps`.
    readonly property int maxBodyBytes: 100000
    // With a key it goes in a curl config on a pipe (-K <(...) has to be on the exec line itself);
    // servers that need none (Ollama, a local one) get the request without it.
    readonly property string curlCommon: '-sS -N --max-time 600 -H "Content-Type: application/json" -H "X-Title: hi-shell" --data-binary "$AI_BODY" "$AI_URL/chat/completions"'
    readonly property string curlScript: 'if [ -n "$AI_KEY" ]; then exec curl -K <(printf \'header = "Authorization: Bearer %s"\\n\' "$AI_KEY") ' + curlCommon + '; fi; '
        + 'exec curl ' + curlCommon

    property bool gotResult: false
    property bool cancelled: false

    // AI switched off (Settings > General, or the welcome screen).
    readonly property bool enabled: Config.options.ai.enabled

    function send(prompt) {
        const text = prompt.trim();
        if (!enabled || busy || text === "")
            return;
        if (chatId === "")
            chatId = String(Date.now());

        messages.append({ role: "user", text: text, done: true });
        messages.append({ role: "assistant", text: "", done: false });
        gotResult = false;
        cancelled = false;

        if (compat) {
            sendCompat();
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
        const extra = spec.usage === "openrouter" ? { usage: { include: true } }
                    : spec.usage === "stream_options" ? { stream_options: { include_usage: true } } : {};
        const body = () => JSON.stringify(Object.assign({ model: apiModel, stream: true, messages: list }, extra));
        while (list.length > 1 && body().length > maxBodyBytes)
            list.shift();
        return body();
    }

    function sendCompat() {
        const key = keyFor(provider);
        const url = urlFor(provider).replace(/\/+$/, "");
        if (spec.urlRequired && url === "")
            return finishWith("error", Translation.tr("Add the %1 server address in Settings → General.").arg(spec.name));
        if (spec.key && key === "")
            return finishWith("error", Translation.tr("Add your %1 API key in Settings → General.").arg(spec.name));
        if (apiModel === "")
            return finishWith("error", Translation.tr("Pick a %1 model first.").arg(spec.name));
        aiProc.environment = ({
            PATH: `${Quickshell.env("HOME")}/.local/bin:${Quickshell.env("PATH")}`,
            AI_KEY: key,
            AI_URL: url,
            AI_BODY: conversation()
        });
        aiProc.command = ["bash", "-c", curlScript];
        aiProc.running = true;
    }

    function finishWith(role, text) {
        gotResult = true;
        finish(role, text);
    }

    // The provider's chat models: from its /models list (OpenRouter: the free ones, where prompt
    // and completion both cost nothing).
    function loadModels() {
        if (!compat || loadingModels)
            return;
        const p = spec, id = provider;
        const url = urlFor(id).replace(/\/+$/, "");
        if (url === "") {
            modelsError = Translation.tr("Add the %1 server address in Settings → General.").arg(p.name);
            return;
        }
        loadingModels = true;
        modelsError = "";
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            loadingModels = false;
            try {
                if (xhr.status !== 200)
                    throw new Error(xhr.status === 401 ? Translation.tr("invalid key") : xhr.status ? `HTTP ${xhr.status}` : Translation.tr("no connection"));
                const rows = JSON.parse(xhr.responseText).data ?? [];
                const list = rows
                    .map(m => ({ raw: m, id: p.stripPrefix && m.id.startsWith(p.stripPrefix) ? m.id.slice(p.stripPrefix.length) : m.id }))
                    .filter(m => p.free ? Number(m.raw.pricing?.prompt) === 0 && Number(m.raw.pricing?.completion) === 0 : (p.models ? p.models(m.id) : true))
                    .map(m => ({ id: m.id, name: m.raw.name ?? m.id }))
                    .sort((a, b) => a.name.localeCompare(b.name));
                const lists = Object.assign({}, modelLists);
                lists[id] = list;
                modelLists = lists;
            } catch (e) {
                modelsError = Translation.tr("Couldn't load the model list (%1)").arg(e.message);
            }
        };
        xhr.open("GET", `${url}/models`);
        const key = keyFor(id);
        if (key !== "")
            xhr.setRequestHeader("Authorization", `Bearer ${key}`);
        xhr.send();
    }

    function cancel() {
        if (!busy)
            return;
        cancelled = true;
        proc.running = false;
        aiProc.running = false;
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
            model: compat ? apiModel : model,
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

    // The stream is over ([DONE], or the connection closed): the answer is complete.
    function finishStream() {
        if (gotResult)
            return;
        gotResult = true;
        if (current().text === "")
            finish("error", Translation.tr("The model returned an empty answer."));
        else
            finish();
    }

    // One server event of a stream: "data: {json}" lines, ": comment" keep-alives and
    // "data: [DONE]". An error before the stream starts comes as a plain JSON line.
    function handleCompatLine(line) {
        // The parser hands lines over with stray newlines around them.
        const text = line.trim();
        const payload = text.startsWith("data:") ? text.slice(5).trim() : text;
        if (payload === "[DONE]")
            return finishStream();
        if (payload === "" || payload.startsWith(":"))
            return;
        let ev;
        try {
            ev = JSON.parse(payload);
        } catch (e) {
            return;
        }
        if (ev.error)
            return finishWith("error", ev.error.message ?? ev.error ?? Translation.tr("%1 returned an error.").arg(providerName));
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
        id: aiProc

        workingDirectory: Quickshell.env("HOME")

        stdout: SplitParser {
            onRead: line => root.handleCompatLine(line)
        }
        stderr: StdioCollector {
            id: aiStderr
        }

        onExited: (exitCode, exitStatus) => {
            if (root.gotResult)
                return;
            const cur = root.current();
            if (root.cancelled)
                root.finish(undefined, cur.text === "" ? Translation.tr("_Stopped._") : cur.text + "\n\n_Stopped._");
            else if (exitCode !== 0)
                root.finish("error", aiStderr.text.trim() || Translation.tr("curl exited with code %1.").arg(exitCode));
            else
                // The rest of the stream may still be on its way to the parser.
                drain.restart();
        }
    }

    // After the connection closes: gives the last lines of the stream a moment to be read.
    Timer {
        id: drain
        interval: 300
        onTriggered: root.finishStream()
    }
}
