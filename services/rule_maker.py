#!/usr/bin/env python3
"""Make a rule (docs/RULES.md) from a description in words, with the AI chat's model.

    rule_maker.py --provider claude --model sonnet --text "dark mode after 22:00"
    rule_maker.py --provider openai --url https://api.openai.com/v1 --model gpt-4o-mini --facts '{...}' --text "..."

The description comes with --text (or on stdin), the key from the environment (HI_AI_KEY). The model sees the rule format
(the Conditions and Actions of docs/RULES.md), the options a rule can set (modules/settings/OptionIndex.js)
and, with --facts, what the conditions see right now (screens, open apps). Prints the rule as one line of
JSON, without an id (the shell gives it one); errors go to stderr with exit code 1.
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from translate import ask_claude, ask_compat  # noqa: E402  (the same two ways to reach a model)

REPO = Path(__file__).resolve().parent.parent
RULES_DOC = REPO / "docs" / "RULES.md"
OPTIONS = REPO / "modules" / "settings" / "OptionIndex.js"
TRIES = 2
MAX_DESCRIPTION = 2000
PARTS = ("when", "then", "else")


def rule_format() -> str:
    """The Conditions and Actions sections of docs/RULES.md."""
    text = RULES_DOC.read_text(encoding="utf-8")
    start = text.find("## Conditions")
    end = text.find("## Good to know")
    return text[start:end if end > start else len(text)].strip() if start >= 0 else text


def options() -> dict[str, str]:
    """Option path -> what it does, from the generated OptionIndex.js."""
    text = OPTIONS.read_text(encoding="utf-8")
    start, end = text.find("["), text.rfind("]")
    if start < 0 or end < start:
        return {}
    return {o["path"]: o.get("text", "") for o in json.loads(text[start:end + 1]) if "path" in o}


def prompt_for(description: str, known: dict[str, str], facts: str, problem: str = "") -> str:
    lines = "\n".join(f"{p}: {t}" for p, t in known.items())
    parts = [
        "You write automation rules for hi-shell, a Hyprland desktop shell. A rule is JSON:\n"
        '{"name": "...", "when": <condition>, "then": [<actions>], "else": [<actions>]}\n'
        "`name` is a short title in the language of the request. `else` runs when the condition turns false; "
        "options set in `then` go back by themselves, so `else` is only for ipc / run actions that need undoing. "
        "Prefer `set` and `notify` to `run`; use `run` only when nothing else does it.\n\n"
        + rule_format(),
        "Options `set` can change (path: what it does):\n" + lines,
    ]
    if facts:
        parts.append("What the conditions see right now (screen names, app classes, ...):\n" + facts)
    parts.append("The request:\n" + description)
    if problem:
        parts.append(f"Your previous answer was wrong: {problem}. Fix it.")
    parts.append("Answer with only the JSON object of the rule, nothing else.")
    return "\n\n".join(parts)


def parse(answer: str) -> dict:
    start, end = answer.find("{"), answer.rfind("}")
    if start < 0 or end < start:
        raise ValueError("no JSON object in the answer")
    rule = json.loads(answer[start:end + 1])
    if not isinstance(rule, dict):
        raise ValueError("the answer is not a JSON object")
    return rule


def problem_of(rule: dict, known: dict[str, str]) -> str:
    """What is wrong with the rule that the model can fix, or "". The shell checks the rest."""
    if not isinstance(rule.get("when"), dict):
        return "`when` must be a condition object"
    if not isinstance(rule.get("then"), list):
        return "`then` must be a list of actions"
    actions = rule["then"] + (rule.get("else") if isinstance(rule.get("else"), list) else [])
    unknown = [a["set"] for a in actions if isinstance(a, dict) and isinstance(a.get("set"), str) and a["set"] not in known]
    return f"there is no option {', '.join(unknown)}" if unknown else ""


def cleaned(rule: dict) -> dict:
    """Only the parts a rule has; the shell gives the id."""
    out = {k: rule[k] for k in PARTS if k in rule}
    name = rule.get("name")
    return {"name": name.strip()[:80] if isinstance(name, str) else "", "enabled": True, **out, "else": out.get("else", [])}


def make(description: str, ask, known: dict[str, str], facts: str = "") -> dict:
    """The rule for the description; `ask(prompt) -> answer`. Raises RuntimeError when the model can't make one."""
    problem = ""
    for _ in range(TRIES):
        try:
            rule = parse(ask(prompt_for(description, known, facts, problem)))
        except (ValueError, json.JSONDecodeError) as e:
            problem = str(e)
            continue
        problem = problem_of(rule, known)
        if not problem:
            return cleaned(rule)
    raise RuntimeError(f"the model's rule is no good: {problem}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--provider", required=True)
    ap.add_argument("--url", default="")
    ap.add_argument("--model", default="")
    ap.add_argument("--facts", default="")
    ap.add_argument("--text", default="")
    args = ap.parse_args()
    description = re.sub(r"\s+", " ", args.text or sys.stdin.read()).strip()[:MAX_DESCRIPTION]
    if not description:
        print("describe the rule", file=sys.stderr)
        return 1
    key = os.environ.get("HI_AI_KEY", "")

    def ask(prompt: str) -> str:
        return ask_claude(prompt, args.model) if args.provider == "claude" else ask_compat(args.url, key, args.model, prompt)

    try:
        rule = make(description, ask, options(), args.facts)
    except (RuntimeError, OSError, KeyError) as e:
        print(str(e), file=sys.stderr)
        return 1
    print(json.dumps(rule, ensure_ascii=False), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
