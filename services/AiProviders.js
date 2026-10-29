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
