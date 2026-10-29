#!/usr/bin/env python3
"""Find, change, switch off and add the commands Hyprland runs at its start (Settings > Autostart).

    execs.py scan   --hypr DIR --exec FILE [--shell-hypr DIR]
    execs.py edit   --file=F --line=N --orig=TEXT --cmd=NEW
    execs.py toggle --file=F --line=N --orig=TEXT --on=0|1
    execs.py delete --file=F --line=N --orig=TEXT
    execs.py add    --exec=FILE --cmd=NEW
(values joined with = : a line like `--hl.exec_cmd(...)` starts with dashes)

The Hyprland config is Lua, so an autostart command is a statement on a line of its own:

    hl.exec_cmd("hypridle")            inside hl.on("hyprland.start", function() ... end): once, at the start
    -- hl.exec_cmd("hypridle")         the same, switched off (commented out)
    hl.exec_cmd("hyprctl setcursor …") outside it: on every reload ("former exec", in the dots' words)

Only those one-line statements with a plain string are handled (not commands built from variables or
spread over lines). Files that are symlinks (NixOS, stow) or can't be written are listed but not changed. `scan` lists them from every .lua file under DIR plus the hi-shell file FILE (exec.lua,
where `add` puts new ones). The others write to the line a command is on: a change checks that the line is
still the one that was listed, keeps the indentation and the trailing comment, and the first change of a
file keeps a copy next to it (<name>.backup-hi-shell-autostart). Prints JSON.
"""

import argparse
import json
import os
import re
import shutil
import sys

STATEMENT = re.compile(
    r"""^(?P<indent>[ \t]*)(?P<off>--+[ \t]*)?hl\.exec_cmd\(\s*(?P<q>["'])(?P<body>(?:\\.|(?!(?P=q)).)*)(?P=q)\s*\)[ \t]*(?P<tail>--.*)?$"""
)
START = re.compile(r"""^[ \t]*hl\.on\(\s*["']hyprland\.start["']""")
# Don't wander through a huge or odd config: skip big files and some folders, and stop at a limit.
MAX_FILE = 512 * 1024
MAX_FILES = 600
MAX_ENTRIES = 300
SKIP_DIRS = {"node_modules", "venv", ".venv", "__pycache__", "site-packages"}
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


def read(path):
    """The text of a file, its lines without line endings, and its line ending (\n or \r\n)."""
    with open(path, encoding="utf-8", errors="surrogateescape", newline="") as f:
        text = f.read()
    eol = "\r\n" if "\r\n" in text else "\n"
    return text, text.split("\n") if eol == "\n" else text.split("\r\n"), eol


def scan_file(path):
    """The handled statements of one file: [{ line, cmd, enabled, kind }]."""
    try:
        if os.path.getsize(path) > MAX_FILE:
            return []
        lines = read(path)[1]
    except (OSError, ValueError):
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
    count = 0
    for base, dirs, files in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs if not d.startswith(".") and "backup" not in d and d not in SKIP_DIRS)
        for name in sorted(files):
            # The dots keep older copies next to the real ones (.old, .backup-...).
            if name.endswith(".lua") and "backup" not in name:
                count += 1
                if count > MAX_FILES:
                    return
                yield os.path.join(base, name)


def why_readonly(path, shell_dir):
    """Why a file shouldn't be written, or "" when it can be."""
    # A symlinked file (NixOS, stow) would be replaced by a plain file; a symlinked folder is fine.
    if os.path.islink(path):
        return "symlink"
    if not os.access(path, os.W_OK) or not os.access(os.path.dirname(path), os.W_OK):
        return "no-write"
    if os.path.realpath(path).startswith(shell_dir + os.sep):
        # hi-shell's own start-up (hypr/hi-shell/startup.lua) isn't for editing.
        return "hi-shell"
    return ""


def mentions(path, needle):
    try:
        if os.path.getsize(path) > MAX_FILE:
            return False
        return needle in read(path)[0]
    except (OSError, ValueError):
        return False


def scan(hypr, exec_file, shell_hypr):
    shell = os.path.realpath(os.path.join(hypr, "hi-shell"))
    paths = list(lua_files(hypr)) if os.path.isdir(hypr) else []
    own = os.path.realpath(exec_file)
    if os.path.exists(exec_file) and own not in {os.path.realpath(p) for p in paths}:
        paths.insert(0, exec_file)
    # A symlink to a file that is listed anyway (stow, dots linked into place) would show it twice.
    real_files = {os.path.realpath(p) for p in paths if not os.path.islink(p)}
    paths = [p for p in paths if not (os.path.islink(p) and os.path.realpath(p) in real_files)]
    entries = []
    for path in paths:
        mine = os.path.realpath(path) == own
        reason = "" if mine and os.access(path, os.W_OK) else why_readonly(path, shell)
        for e in scan_file(path):
            e.update(file=path, rel=os.path.relpath(path, hypr) if path.startswith(hypr) else path,
                     readonly=bool(reason), why=reason, own=mine)
            entries.append(e)
    # Your own (exec.lua) first, then the config in the order of its files.
    entries.sort(key=lambda e: 0 if e["own"] else 1)
    # Is hi-shell's part of the Hyprland config loaded (so that exec.lua is)? Its overrides.lua
    # loads ~/.config/hi-shell/hyprland.lua, which loads exec.lua. Looked for in your config and in
    # the repo's copy (an older install loads that one).
    roots = [r for r in (hypr, shell_hypr) if r and os.path.isdir(r)]
    outside = [p for p in lua_files(hypr) if not os.path.realpath(p).startswith(shell + os.sep)] if os.path.isdir(hypr) else []
    loaded = any(mentions(p, "hi-shell/hyprland.lua") for r in roots for p in lua_files(r)) \
        and any(mentions(p, "hi-shell/init.lua") or mentions(p, "hi-shell.lua") for p in outside)
    print(json.dumps({"entries": entries[:MAX_ENTRIES], "total": len(entries), "dir": hypr,
                      "exists": os.path.isdir(hypr), "loaded": loaded}))


def write(path, text, like=None):
    tmp = path + ".tmp-hi-shell"
    with open(tmp, "w", encoding="utf-8", errors="surrogateescape", newline="") as f:
        f.write(text)
    if like and os.path.exists(like):
        shutil.copymode(like, tmp)
    os.replace(tmp, path)


def rewrite(path, line, orig, make):
    """Replace line `line` (1-based) of `path` by make(match) (a string, or None to delete it)."""
    if os.path.islink(path):
        fail("That file is a symlink (managed elsewhere); change its target instead.")
    text, lines, eol = read(path)
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
        write(backup, text, like=path)
    write(path, eol.join(lines), like=path)
    print(json.dumps({"ok": True}))


def build(m, cmd=None, on=None):
    on = (not m.group("off")) if on is None else on
    tail = (" " + m.group("tail")) if m.group("tail") else ""
    cmd_lit = encode(cmd) if cmd is not None else m.group("q") + m.group("body") + m.group("q")
    return f'{m.group("indent")}{"" if on else "-- "}hl.exec_cmd({cmd_lit}){tail}'


def add(exec_file, cmd):
    os.makedirs(os.path.dirname(exec_file), exist_ok=True)
    if os.path.islink(exec_file):
        fail("exec.lua is a symlink (managed elsewhere); change its target instead.")
    new = f"    hl.exec_cmd({encode(cmd)})"
    if not os.path.exists(exec_file):
        text = HEAD + 'hl.on("hyprland.start", function()\n' + new + "\nend)\n"
    else:
        _, lines, eol = read(exec_file)
        # Before the closing "end)" of the (last) start block; one is made when there's none.
        close = max((i for i, t in enumerate(lines) if re.match(r"^end\)\s*$", t)), default=None)
        if close is None:
            lines += ([""] if lines and lines[-1] else []) + ['hl.on("hyprland.start", function()', new, "end)", ""]
        else:
            lines.insert(close, new)
        text = eol.join(lines)
    write(exec_file, text, like=exec_file)
    print(json.dumps({"ok": True}))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("action", choices=["scan", "edit", "toggle", "delete", "add"])
    p.add_argument("--hypr")
    p.add_argument("--exec", dest="exec_file")
    p.add_argument("--shell-hypr")
    p.add_argument("--file")
    p.add_argument("--line", type=int)
    p.add_argument("--orig")
    p.add_argument("--cmd")
    p.add_argument("--on")
    a = p.parse_args()
    try:
        if a.action == "scan":
            scan(os.path.abspath(a.hypr), os.path.abspath(a.exec_file), os.path.abspath(a.shell_hypr) if a.shell_hypr else "")
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
    except SystemExit:
        raise
    except PermissionError as e:
        fail(f"No permission to write in {os.path.dirname(e.filename or '') or 'there'}.")
    except Exception as e:  # whatever the file system does, the page gets a message
        fail(f"{type(e).__name__}: {e}")


if __name__ == "__main__":
    main()
