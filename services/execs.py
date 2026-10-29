#!/usr/bin/env python3
"""Find, change, switch off and add the commands Hyprland runs at its start (Settings > Autostart).

    execs.py scan   --hypr DIR --exec FILE
    execs.py edit   --file F --line N --orig TEXT --cmd NEW
    execs.py toggle --file F --line N --orig TEXT --on 0|1
    execs.py delete --file F --line N --orig TEXT
    execs.py add    --exec FILE --cmd NEW

The Hyprland config is Lua, so an autostart command is a statement on a line of its own:

    hl.exec_cmd("hypridle")            inside hl.on("hyprland.start", function() ... end): once, at the start
    -- hl.exec_cmd("hypridle")         the same, switched off (commented out)
    hl.exec_cmd("hyprctl setcursor …") outside it: on every reload ("former exec", in the dots' words)

Only those one-line statements with a plain string are handled (not commands built from variables or
spread over lines). `scan` lists them from every .lua file under DIR plus the hi-shell file FILE (exec.lua,
where `add` puts new ones). The others write to the line a command is on: a change checks that the line is
still the one that was listed, keeps the indentation and the trailing comment, and the first change of a
file keeps a copy next to it (<name>.backup-hi-shell-autostart). Prints JSON.
"""

import argparse
import json
import os
import re
import sys

STATEMENT = re.compile(
    r"""^(?P<indent>[ \t]*)(?P<off>--+[ \t]*)?hl\.exec_cmd\(\s*(?P<q>["'])(?P<body>(?:\\.|(?!(?P=q)).)*)(?P=q)\s*\)[ \t]*(?P<tail>--.*)?$"""
)
START = re.compile(r"""^[ \t]*hl\.on\(\s*["']hyprland\.start["']""")
ESCAPES = {"n": "\n", "t": "\t", "\\": "\\", '"': '"', "'": "'"}
HEAD = ('-- hi-shell: commands Hyprland runs when it starts (Settings > Autostart changes this file;\n'
        '-- editing it by hand is fine). Loaded from ~/.config/hi-shell/hyprland.lua.\n')


def decode(body):
    return re.sub(r"\\(.)", lambda m: ESCAPES.get(m.group(1), m.group(0)), body)


def encode(cmd):
    return '"' + cmd.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def fail(msg):
    print(json.dumps({"error": msg}))
    sys.exit(1)


def scan_file(path):
    """The handled statements of one file: [{ line, cmd, enabled, kind }]."""
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.read().split("\n")
    except (OSError, UnicodeDecodeError):
        return []
    out, inside, indent = [], False, 0
    for i, text in enumerate(lines, 1):
        if not inside and START.match(text) and not text.lstrip().startswith("--"):
            inside, indent = True, len(text) - len(text.lstrip())
        elif inside and text.strip().startswith("end") and len(text) - len(text.lstrip()) <= indent:
            inside = False
        m = STATEMENT.match(text)
        # Outside a start block only statements at the top level count (an indented one is inside
        # some other function or condition, like a key handler).
        if m and (inside or not m.group("indent")):
            out.append({"line": i, "orig": text, "cmd": decode(m.group("body")), "enabled": not m.group("off"), "kind": "start" if inside else "reload"})
    return out


def lua_files(root):
    for base, dirs, files in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs if not d.startswith(".") and "backup" not in d and d != "__pycache__")
        for name in sorted(files):
            # The dots keep older copies next to the real ones (.old, .backup-...).
            if name.endswith(".lua") and "backup" not in name:
                yield os.path.join(base, name)


def scan(hypr, exec_file):
    shell = os.path.realpath(os.path.join(hypr, "hi-shell"))
    entries = []
    paths = list(lua_files(hypr))
    if os.path.exists(exec_file) and os.path.realpath(exec_file) not in {os.path.realpath(p) for p in paths}:
        paths.insert(0, exec_file)
    for path in paths:
        real = os.path.realpath(path)
        mine = real == os.path.realpath(exec_file)
        for e in scan_file(path):
            e.update(file=path, rel=os.path.relpath(path, hypr) if path.startswith(hypr) else path,
                     # hi-shell's own start-up (hypr/hi-shell/startup.lua) isn't for editing.
                     readonly=real.startswith(shell + os.sep) and not mine, own=mine)
            entries.append(e)
    # Your own (exec.lua) first, then the config in the order of its files.
    entries.sort(key=lambda e: 0 if e["own"] else 1)
    print(json.dumps(entries))


def rewrite(path, line, orig, make):
    """Replace line `line` (1-based) of `path` by make(match) (a string, or None to delete it)."""
    with open(path, encoding="utf-8") as f:
        text = f.read()
    lines = text.split("\n")
    if line < 1 or line > len(lines) or lines[line - 1] != orig:
        fail("The file changed since the list was made; it's reloaded now.")
    m = STATEMENT.match(orig)
    if not m:
        fail("That line isn't a plain exec any more.")
    new = make(m)
    if new is None:
        del lines[line - 1]
    else:
        lines[line - 1] = new
    backup = path + ".backup-hi-shell-autostart"
    if not os.path.exists(backup):
        with open(backup, "w", encoding="utf-8") as f:
            f.write(text)
    tmp = path + ".tmp-hi-shell"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    os.replace(tmp, path)
    print(json.dumps({"ok": True}))


def build(m, cmd=None, on=None):
    on = (not m.group("off")) if on is None else on
    tail = (" " + m.group("tail")) if m.group("tail") else ""
    cmd_lit = encode(cmd) if cmd is not None else m.group("q") + m.group("body") + m.group("q")
    return f'{m.group("indent")}{"" if on else "-- "}hl.exec_cmd({cmd_lit}){tail}'


def add(exec_file, cmd):
    os.makedirs(os.path.dirname(exec_file), exist_ok=True)
    new = f"    hl.exec_cmd({encode(cmd)})"
    if not os.path.exists(exec_file):
        text = HEAD + 'hl.on("hyprland.start", function()\n' + new + "\nend)\n"
    else:
        with open(exec_file, encoding="utf-8") as f:
            lines = f.read().split("\n")
        # Before the closing "end)" of the (last) start block; one is made when there's none.
        close = max((i for i, t in enumerate(lines) if re.match(r"^end\)\s*$", t)), default=None)
        if close is None:
            lines += ([""] if lines and lines[-1] else []) + ['hl.on("hyprland.start", function()', new, "end)", ""]
        else:
            lines.insert(close, new)
        text = "\n".join(lines)
    tmp = exec_file + ".tmp-hi-shell"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, exec_file)
    print(json.dumps({"ok": True}))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("action", choices=["scan", "edit", "toggle", "delete", "add"])
    p.add_argument("--hypr")
    p.add_argument("--exec", dest="exec_file")
    p.add_argument("--file")
    p.add_argument("--line", type=int)
    p.add_argument("--orig")
    p.add_argument("--cmd")
    p.add_argument("--on")
    a = p.parse_args()
    try:
        if a.action == "scan":
            scan(os.path.abspath(a.hypr), os.path.abspath(a.exec_file))
        elif a.action == "add":
            if not (a.cmd or "").strip():
                fail("Empty command.")
            add(os.path.abspath(a.exec_file), a.cmd.strip())
        elif a.action == "edit":
            if not (a.cmd or "").strip():
                fail("Empty command.")
            rewrite(a.file, a.line, a.orig, lambda m: build(m, cmd=a.cmd.strip()))
        elif a.action == "toggle":
            rewrite(a.file, a.line, a.orig, lambda m: build(m, on=a.on == "1"))
        else:
            rewrite(a.file, a.line, a.orig, lambda m: None)
    except OSError as e:
        fail(str(e))


if __name__ == "__main__":
    main()
