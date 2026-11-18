.pragma library

// The chat's providers besides the Claude CLI. All speak the OpenAI "chat completions" API
// (POST <url>/chat/completions with a Bearer key, answers as server-sent events), so one client
// covers them; an entry says where they are and how their model list looks.
//   url        API base (without /chat/completions); can be overridden in the settings (ai.urls)
//   keyUrl     where to get a key (shown in the settings); no key needed when `key` is false
//   usage      how to ask for token counts in a stream: "openrouter" | "stream_options" | "" (don't)
//   models     picks the chat models from the provider's list (id -> bool)
const providers = [
    {
        id: "openrouter", name: "OpenRouter", icon: "hub", url: "https://openrouter.ai/api/v1", key: true,
        keyUrl: "openrouter.ai/keys", usage: "openrouter", free: true,
        note: "Any of its models; the picker lists the free ones"
    },
    {
        id: "openai", name: "OpenAI", icon: "psychology", url: "https://api.openai.com/v1", key: true,
        keyUrl: "platform.openai.com/api-keys", usage: "stream_options",
        models: id => /^(gpt|chatgpt|o\d)/.test(id) && !/(audio|realtime|transcribe|tts|image|search|embedding|moderation|instruct)/.test(id)
    },
    {
        id: "gemini", name: "Gemini", icon: "diamond", url: "https://generativelanguage.googleapis.com/v1beta/openai", key: true,
        keyUrl: "aistudio.google.com/apikey", usage: "stream_options", stripPrefix: "models/",
        models: id => /^gemini/.test(id) && !/(embedding|aqa|vision|tts|image|live)/.test(id)
    },
    {
        id: "groq", name: "Groq", icon: "bolt", url: "https://api.groq.com/openai/v1", key: true,
        keyUrl: "console.groq.com/keys", usage: "stream_options",
        models: id => !/(whisper|tts|guard|embed|distil-whisper)/.test(id)
    },
    {
        id: "deepseek", name: "DeepSeek", icon: "water", url: "https://api.deepseek.com", key: true,
        keyUrl: "platform.deepseek.com/api_keys", usage: "stream_options"
    },
    {
        id: "mistral", name: "Mistral", icon: "air", url: "https://api.mistral.ai/v1", key: true,
        keyUrl: "console.mistral.ai/api-keys", usage: "stream_options",
        models: id => !/(embed|moderation|ocr|voxtral)/.test(id)
    },
    {
        id: "ollama", name: "Ollama", icon: "dns", url: "http://localhost:11434/v1", key: false,
        usage: "stream_options", note: "Local models; the picker lists what you've pulled"
    },
    {
        id: "custom", name: "Custom", icon: "settings_ethernet", url: "", key: false, urlRequired: true,
        usage: "", note: "Any OpenAI-compatible server (LM Studio, llama.cpp, vLLM, ...)"
    }
];

function find(id) {
    return providers.find(p => p.id === id) ?? null;
}

// --- Ollama: its own API next to the OpenAI-compatible one (model list with sizes, pulls) ---

// The server root from the chat address: "http://localhost:11434/v1" -> "http://localhost:11434".
function ollamaBase(url) {
    return url.replace(/\/+$/, "").replace(/\/v1$/, "");
}

function formatSize(bytes) {
    if (!(bytes > 0))
        return "";
    const gb = bytes / 1e9;
    return gb >= 1 ? `${gb.toFixed(1)} GB` : `${Math.round(bytes / 1e6)} MB`;
}

// Embedding-only models can't chat: by their capabilities (Ollama 0.6+) or, without them, the family.
function canChat(m) {
    if (Array.isArray(m.capabilities))
        return m.capabilities.includes("completion");
    const families = [m.details?.family ?? "", ...(m.details?.families ?? [])].join(" ");
    return !/bert/.test(families) && !/embed/.test(m.name ?? "");
}

// /api/tags -> [{ id, name, details }], sorted by name; details is "8.2B · Q4_K_M · 5.2 GB".
function ollamaModels(tags) {
    return (tags?.models ?? [])
        .filter(canChat)
        .map(m => ({
            id: m.name,
            name: m.name,
            details: [m.details?.parameter_size, m.details?.quantization_level, formatSize(m.size)].filter(s => s).join(" · ")
        }))
        .sort((a, b) => a.name.localeCompare(b.name));
}

// One line of /api/pull's stream -> { status, fraction (0..1, -1 when unknown), done, error }.
function pullProgress(ev) {
    return {
        status: ev.status ?? "",
        fraction: ev.total > 0 ? (ev.completed ?? 0) / ev.total : -1,
        done: ev.status === "success",
        error: typeof ev.error === "string" ? ev.error : ev.error ? String(ev.error) : ""
    };
}

// A model name as `ollama pull` takes it: "llama3.2", "qwen3:8b", "hf.co/user/repo:Q4_K_M".
function validModelName(name) {
    return /^[A-Za-z0-9][A-Za-z0-9._\/:-]*$/.test(name);
}
