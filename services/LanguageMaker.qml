pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Makes a language with the AI chat's model (services/translate.py): the shell's strings, translated,
// into ~/.config/hi-shell/translations/<code>.json. The language then shows in the Language choice.
Singleton {
    id: root

    readonly property string script: `${Quickshell.shellDir}/services/translate.py`
    property bool running: maker.running
    property string status: ""
    property string error: ""

    // The key and address of the chat's provider (the Claude CLI needs none).
    function generate(code, name, model) {
        if (maker.running)
            return;
        const provider = Config.options.ai.provider;
        const key = provider === "claude" ? "" : (Config.options.ai.keys[provider] ?? "");
        const url = provider === "claude" ? "" : (Config.options.ai.urls[provider] ?? "");
        const out = `${Config.dir}/translations/${code}.json`;
        error = "";
        status = Translation.tr("Starting…");
        maker.pending = { code, name: name || code };
        maker.environment = { HI_AI_KEY: key };
        maker.command = ["python3", script, "--code", code, "--name", name || code, "--out", out, "--provider", provider, "--url", url, "--model", model];
        maker.running = true;
    }

    Process {
        id: maker
        property var pending: ({})
        stdout: SplitParser {
            onRead: line => {
                const m = /^progress (\d+) (\d+)/.exec(line);
                if (m)
                    root.status = Translation.tr("Translating… %1 of %2").arg(m[1]).arg(m[2]);
                else if (/^done/.test(line))
                    root.status = Translation.tr("Done: %1").arg(line.slice(5));
            }
        }
        stderr: StdioCollector {
            onStreamFinished: root.error = text.trim()
        }
        onExited: code => {
            if (code === 0) {
                const list = Config.options.customLanguages.filter(l => l.code !== pending.code);
                Config.options.customLanguages = [...list, pending];
                Config.options.language = pending.code;
                Translation.reload();
            } else {
                root.status = "";
                root.error = root.error || Translation.tr("Couldn't make the language");
            }
        }
    }
}
