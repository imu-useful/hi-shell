#!/usr/bin/env python3
"""The config reference: every option of common/ConfigOptions.qml with its type, default, allowed values (from
common/ConfigSchema.js), description (the comment above it) and where Settings lets you change it.

    python3 tools/config_meta.py docs      # write docs/CONFIG.md and modules/settings/OptionIndex.js
    python3 tools/config_meta.py check     # exit 1 if those files are out of date or an option can't be reached
    python3 tools/config_meta.py search W  # options that match a word: path, default, where, description
    python3 tools/config_meta.py names     # every option path and section, one per line (shell completions)

Where an option is changed is found by looking for it in the settings pages (the aliases pages use, like
`readonly property var a: Config.options.appearance`, are followed); what that can't see is in tools/config_meta.json:
{ "path or prefix.*": { "ui": "<settings page id>" | "elsewhere: <where>" | "file: <why>", "advanced": true } }.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OPTIONS = ROOT / "common" / "ConfigOptions.qml"
SCHEMA = ROOT / "common" / "ConfigSchema.js"
META = ROOT / "tools" / "config_meta.json"
DOC = ROOT / "docs" / "CONFIG.md"
INDEX = ROOT / "modules" / "settings" / "OptionIndex.js"

PROP = re.compile(r"^\s*property\s+(?:list<(\w+)>|(\w+))\s+(\w+)\s*(?::\s*(.+?))?\s*(?://\s*(.*))?$")
OBJ = re.compile(r"^\s*property\s+JsonObject\s+(\w+)\s*:\s*JsonObject\s*\{")
ALIAS = re.compile(r"property\s+(?:var|QtObject|JsonObject)\s+(\w+)\s*:\s*Config\.options\.([\w.]+)")

# settings page file -> page id (modules/settings/Pages.js)
PAGE_FILES = {
    "HomePage": "home", "GeneralPage": "general", "BarPage": "bar", "DesktopPage": "desktop", "LockPage": "lock",
    "InterfacePage": "interface", "SoundsPage": "sounds", "ServicesPage": "services", "HyprlandPage": "hyprland",
    "AutostartPage": "autostart", "KeybindsPage": "keybinds", "DefaultAppsPage": "defaultapps",
    "ScreenTimePage": "screentime", "RulesPage": "rules", "AboutPage": "about",
}


@dataclass(frozen=True)
class Option:
    path: str
    type: str
    default: str
    description: str

    @property
    def section(self) -> str:
        return self.path.split(".")[0] if "." in self.path else "(general)"


def parse_options() -> list[Option]:
    """Every leaf option of ConfigOptions.qml with the comment above it (and a trailing `// ...` on its line)."""
    stack: list[str] = []
    out: list[Option] = []
    pending: list[str] = []
    started = False
    for line in OPTIONS.read_text().splitlines():
        if "JsonAdapter {" in line:
            started = True
            continue
        if not started:
            continue
        stripped = line.strip()
        if stripped.startswith("//"):
            pending.append(stripped[2:].strip())
            continue
        m = OBJ.match(line)
        if m:
            stack.append(m.group(1))
            pending = []
            continue
        m = PROP.match(line)
        if m and "JsonObject" not in line:
            typ = f"list<{m.group(1)}>" if m.group(1) else m.group(2)
            text = " ".join([*pending, m.group(5) or ""]).strip()
            out.append(Option(".".join(stack + [m.group(3)]), typ, (m.group(4) or "").strip(), re.sub(r"\s+", " ", text)))
            pending = []
            continue
        if stripped == "}" and stack and line.startswith(" " * (4 + 4 * (len(stack) - 1)) + "}"):
            stack.pop()
        if not stripped:
            pending = []
    return out


def schema_rules() -> dict[str, dict]:
    script = SCHEMA.read_text().replace(".pragma library", "") + ";process.stdout.write(JSON.stringify(rules));"
    return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)


def rule_text(rule: dict | None) -> str:
    if not rule:
        return ""
    if "enum" in rule:
        return " \\| ".join(f"`{v}`" for v in rule["enum"])
    if "pattern" in rule:
        return "`#rrggbb`" + (" or empty" if rule.get("allowEmpty") else "")
    if "min" in rule:
        return f"{rule['min']} … {rule['max']}"
    return ""


# --- where an option is changed ---


def expand_aliases(text: str) -> str:
    for name, target in ALIAS.findall(text):
        text = re.sub(r"(?<![\w.])(?:root\.)?" + name + r"\.", f"Config.options.{target}.", text)
    return text


def page_sources() -> dict[str, str]:
    out: dict[str, str] = {}
    for f in (ROOT / "modules" / "settings").glob("*Page.qml"):
        page = PAGE_FILES.get(f.stem)
        if page:
            out[page] = out.get(page, "") + expand_aliases(f.read_text(errors="ignore"))
    welcome = ROOT / "modules" / "Welcome.qml"
    if welcome.is_file():
        out["welcome"] = expand_aliases(welcome.read_text(errors="ignore"))
    return out


def load_meta() -> dict[str, dict]:
    return json.loads(META.read_text()) if META.is_file() else {}


def meta_for(path: str, meta: dict[str, dict]) -> dict | None:
    """The entry for an option: a `prefix.*` entry, with the option's own entry over it."""
    best = None
    for key, value in meta.items():
        if key.endswith(".*") and path.startswith(key[:-1]) and (best is None or len(key) > len(best[0])):
            best = (key, value)
    merged = dict(best[1]) if best else {}
    merged.update(meta.get(path, {}))
    return merged or None


def locate(options: list[Option]) -> dict[str, str]:
    """option path -> "page:<id>" (found in a settings page), "elsewhere: ..." or "file: ..." (tools/config_meta.json); "" if nowhere."""
    sources = page_sources()
    meta = load_meta()
    out: dict[str, str] = {}
    for o in options:
        pat = re.compile(r"(?<![\w])" + re.escape(o.path) + r"(?![\w])")
        found = next((page for page, text in sources.items() if page != "welcome" and pat.search(text)), None)
        m = meta_for(o.path, meta)
        if m and m.get("ui"):
            out[o.path] = m["ui"] if not re.fullmatch(r"[a-z]+", m["ui"]) else f"page:{m['ui']}"
        elif found:
            out[o.path] = f"page:{found}"
        else:
            out[o.path] = ""
    return out


def stale_meta(options: list[Option]) -> list[str]:
    paths = {o.path for o in options}
    bad = []
    for key in load_meta():
        if key.endswith(".*"):
            if not any(p.startswith(key[:-1]) for p in paths):
                bad.append(key)
        elif key not in paths:
            bad.append(key)
    return bad


def page_title(page_id: str) -> str:
    pages = (ROOT / "modules" / "settings" / "Pages.js").read_text()
    m = re.search(r'id: "%s", title: "([^"]+)"' % re.escape(page_id), pages)
    return m.group(1) if m else page_id


def where_text(where: str) -> str:
    if where.startswith("page:"):
        return f"Settings › {page_title(where[5:])}"
    return where.replace("elsewhere: ", "").replace("file: ", "file only: ") if where else "—"


# --- outputs ---


def clean_default(o: Option) -> str:
    d = o.default.strip()
    if d in ("({})", "{}"):
        return "`{}`"
    return f"`{d}`" if d else "`—`"


def build_doc(options: list[Option]) -> str:
    rules = schema_rules()
    where = locate(options)
    meta = load_meta()
    lines = [
        "# Config reference", "",
        "Generated by `python3 tools/config_meta.py docs` from `common/ConfigOptions.qml` (types, defaults, descriptions) and "
        "`common/ConfigSchema.js` (allowed values). Do not edit by hand.", "",
        "The file is `~/.config/hi-shell/config.json`; edits apply live. A value that breaks its rule is reported in the log "
        "and replaced by its default. `hi config get|set|reset` change options from a terminal (see the README).", "",
    ]
    sections: dict[str, list[Option]] = {}
    for o in options:
        sections.setdefault(o.section, []).append(o)
    lines += ["| Section | Options |", "| --- | --- |"]
    lines += [f"| [`{name}`](#{re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')}) | {len(items)} |" for name, items in sections.items()]
    for name, items in sections.items():
        lines += ["", f"## {name}", "", "| Option | Type | Default | Values | Where | Description |", "| --- | --- | --- | --- | --- | --- |"]
        for o in items:
            m = meta_for(o.path, meta) or {}
            adv = " (advanced)" if m.get("advanced") else ""
            desc = (o.description or "").replace("|", "\\|")
            lines.append(f"| `{o.path}` | `{o.type}` | {clean_default(o)} | {rule_text(rules.get(o.path))} | {where_text(where[o.path])}{adv} | {desc} |")
    return "\n".join(lines) + "\n"


def build_index(options: list[Option]) -> str:
    """The options a person can change in Settings, for the search there and in the launcher."""
    where = locate(options)
    meta = load_meta()
    entries = []
    for o in options:
        w = where[o.path]
        if not w.startswith("page:"):
            continue
        entries.append({"path": o.path, "page": w[5:], "text": o.description, "advanced": bool((meta_for(o.path, meta) or {}).get("advanced"))})
    body = json.dumps(entries, indent=4, ensure_ascii=False)
    return ".pragma library\n\n// Generated by tools/config_meta.py: the options Settings can change, for its search. Do not edit by hand.\nconst options = " + body + ";\n"


def problems(options: list[Option]) -> list[str]:
    out = []
    where = locate(options)
    out += [f"{p}: not in any settings page and not in tools/config_meta.json" for p, w in where.items() if not w]
    out += [f"tools/config_meta.json: {k} names no option" for k in stale_meta(options)]
    out += [f"{o.path}: no description (a comment above it in ConfigOptions.qml)" for o in options if not o.description]
    return out


def main(argv: list[str]) -> int:
    options = parse_options()
    cmd = argv[1] if len(argv) > 1 else "docs"
    if cmd == "docs":
        DOC.write_text(build_doc(options))
        INDEX.write_text(build_index(options))
        print(f"wrote {DOC.relative_to(ROOT)} and {INDEX.relative_to(ROOT)} ({len(options)} options)")
        return 0
    if cmd == "check":
        errors = problems(options)
        if not DOC.is_file() or DOC.read_text() != build_doc(options):
            errors.append("docs/CONFIG.md is out of date: python3 tools/config_meta.py docs")
        if not INDEX.is_file() or INDEX.read_text() != build_index(options):
            errors.append("modules/settings/OptionIndex.js is out of date: python3 tools/config_meta.py docs")
        for e in errors:
            print(e)
        return 1 if errors else 0
    if cmd == "search":
        words = [w.lower() for w in argv[2:]]
        if not words:
            print("Usage: config_meta.py search <word...>", file=sys.stderr)
            return 1
        where = locate(options)
        shown = 0
        for o in options:
            hay = f"{o.path} {o.description}".lower()
            if all(w in hay for w in words):
                print(f"{o.path}  [{o.type}]  default {o.default or '-'}  ({where_text(where[o.path])})")
                if o.description:
                    print(f"    {o.description}")
                shown += 1
        if not shown:
            print("No option matches.")
        return 0
    if cmd == "names":
        # Every option path and section, one per line: the shell completions of `hi config get/set/reset`.
        paths = [o.path for o in options]
        sections = sorted({p.rsplit(".", 1)[0] for p in paths if "." in p})
        print("\n".join(sorted(set(paths) | set(sections))))
        return 0
    print("Usage: config_meta.py docs|check|search <word...>|names", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
