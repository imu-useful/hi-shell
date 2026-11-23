pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import "../common/RulesEngine.js" as Engine
import "../common/RuleForm.js" as Form

// Makes a rule from a description in words with the AI chat's provider and model (services/rule_maker.py).
// The rule is not saved: it lands in `draft` (with a free id) for Settings > Rules to open in the editor.
Singleton {
    id: root

    readonly property string script: `${Quickshell.shellDir}/services/rule_maker.py`
    readonly property bool running: maker.running
    property var draft: null
    property string error: ""

    function generate(description) {
        const text = String(description ?? "").trim();
        if (maker.running || text === "")
            return;
        const provider = Config.options.ai.provider;
        const claude = provider === "claude";
        if (!claude && !Claude.configured(provider)) {
            error = Translation.tr("Set up the AI provider in Settings → General first");
            return;
        }
        error = "";
        draft = null;
        maker.environment = { HI_AI_KEY: claude ? "" : Claude.keyFor(provider) };
        maker.command = ["python3", script, "--provider", provider, "--url", claude ? "" : Claude.urlFor(provider),
            "--model", claude ? Config.options.ai.model : Claude.modelFor(provider), "--facts", JSON.stringify(Rules.facts), "--text", text];
        maker.running = true;
    }

    function clear() {
        draft = null;
        error = "";
    }

    // The model's answer -> a rule with an id no other rule has, or an error.
    function take(text) {
        let rule;
        try {
            rule = JSON.parse(text.trim());
        } catch (e) {
            error = Translation.tr("The AI's answer isn't a rule");
            return;
        }
        const taken = Rules.plainRules().map(r => r.id);
        const named = Object.assign({}, rule, { name: rule.name || Form.describe(rule.when, s => Translation.tr(s)) });
        const withId = Object.assign({ id: Form.idFor(named.name, taken) }, named);
        const problem = Engine.validateRule(withId);
        if (problem)
            error = Translation.tr("The AI made a rule that doesn't work: %1").arg(problem);
        else
            draft = withId;
    }

    Process {
        id: maker
        stdout: StdioCollector {
            id: out
        }
        stderr: StdioCollector {
            id: err
        }
        onExited: code => {
            if (code === 0)
                root.take(out.text);
            else
                root.error = err.text.trim() || Translation.tr("Couldn't make the rule");
        }
    }
}
