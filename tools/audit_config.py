#!/usr/bin/env python3
"""Audit of config options: which keys in common/Config.qml have no control in the settings app,
and how many hardcoded colors / durations / radii sit in the QML files.

    python3 tools/audit_config.py            # print the report
    python3 tools/audit_config.py --write    # write docs/CONFIG_AUDIT.md
"""
import re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROP = re.compile(r"^\s*property\s+(?:list<(\w+)>|(\w+))\s+(\w+)\s*(?::\s*(.+?))?\s*(?://.*)?$")
OBJ = re.compile(r"^\s*property\s+JsonObject\s+(\w+)\s*:\s*JsonObject\s*\{")


def parse_options():
    """Return [(dotted.path, type, default)] for every leaf option in Config.qml."""
    stack, out = [], []
    started = False
    for line in (ROOT / "common/Config.qml").read_text().splitlines():
        if "JsonAdapter {" in line:
            started = True
            continue
        if not started:
            continue
        m = OBJ.match(line)
        if m:
            stack.append(m.group(1))
            continue
        m = PROP.match(line)
        if m and "JsonObject" not in line:
            typ = f"list<{m.group(1)}>" if m.group(1) else m.group(2)
            out.append((".".join(stack + [m.group(3)]), typ, (m.group(4) or "").strip()))
            continue
        if line.strip() == "}" and stack and line.startswith(" " * (12 + 4 * (len(stack) - 1)) + "}"):
            stack.pop()
    return out


ALIAS = re.compile(r"property\s+(?:var|QtObject|JsonObject)\s+(\w+)\s*:\s*Config\.options\.([\w.]+)")


def expand_aliases(text):
    """`readonly property var a: Config.options.appearance` -> later `a.fonts` reads as Config.options.appearance.fonts."""
    for name, target in ALIAS.findall(text):
        text = re.sub(r"(?<![\w.])(?:root\.)?" + name + r"\.", f"Config.options.{target}.", text)
    return text


def read_all(globs):
    return {p: expand_aliases(p.read_text(errors="ignore")) for g in globs for p in ROOT.glob(g)}


def referenced(opts, files):
    """A key counts as used by the UI if its last two path parts appear in a settings page,
    e.g. `fonts.main` or `Config.options.bar.height`."""
    text = "\n".join(files.values())
    result = {}
    for path, _, _ in opts:
        parts = path.split(".")
        pats = [path]
        result[path] = any(re.search(r"(?<![\w])" + re.escape(p) + r"(?![\w])", text) for p in pats)
    return result


def hardcoded():
    counts = {"colors": 0, "durations": 0, "radii": 0, "font sizes": 0}
    per_file = []
    for p in list(ROOT.glob("modules/**/*.qml")) + list(ROOT.glob("common/widgets/*.qml")):
        t = p.read_text(errors="ignore")
        c = len(re.findall(r'"#[0-9a-fA-F]{6,8}"|Qt\.rgba\(', t))
        d = len(re.findall(r"duration:\s*\d+", t))
        r = len(re.findall(r"radius:\s*\d+", t))
        f = len(re.findall(r"pixelSize:\s*\d+", t))
        counts["colors"] += c; counts["durations"] += d; counts["radii"] += r; counts["font sizes"] += f
        per_file.append((c + d + r + f, str(p.relative_to(ROOT)), c, d, r, f))
    per_file.sort(reverse=True)
    return counts, per_file[:15]


def main():
    opts = parse_options()
    ui = read_all(["modules/settings/*.qml", "modules/Settings.qml", "modules/Welcome.qml", "modules/**/*.qml",
                   "modules/bar/*.qml", "modules/Sidebar*.qml", "modules/desktop/*.qml", "services/*.qml"])
    settings_only = {p: t for p, t in ui.items() if "settings" in str(p) or p.name in ("Settings.qml", "Welcome.qml")}
    in_settings = referenced(opts, settings_only)
    in_code = referenced(opts, ui)

    lines = ["# Config audit", "",
             f"{len(opts)} options in `common/Config.qml`.", ""]
    missing = [o for o in opts if not in_settings[o[0]]]
    lines += [f"## Options without a control in the settings app ({len(missing)})", "",
              "| Option | Type | Default |", "| --- | --- | --- |"]
    lines += [f"| `{p}` | `{t}` | `{d}` |" for p, t, d in missing]
    dead = [o for o in opts if not in_code[o[0]]]
    lines += ["", f"## Options not referenced anywhere ({len(dead)})", ""]
    lines += [f"- `{p}`" for p, _, _ in dead] or ["None."]
    counts, top = hardcoded()
    lines += ["", "## Hardcoded values in modules/ and common/widgets/", "",
              ", ".join(f"{v} {k}" for k, v in counts.items()), "",
              "| File | Total | Colors | Durations | Radii | Font sizes |", "| --- | --- | --- | --- | --- | --- |"]
    lines += [f"| `{f}` | {t} | {c} | {d} | {r} | {s} |" for t, f, c, d, r, s in top]
    report = "\n".join(lines) + "\n"
    if "--write" in sys.argv:
        (ROOT / "docs/CONFIG_AUDIT.md").write_text(report)
    print(report)


main()
