#!/usr/bin/env python3
"""Find, change, switch off, delete and add the keybinds of the Hyprland config (Settings > Keybinds).

    binds.py scan   --hypr=DIR --binds=FILE [--shell-hypr=DIR]
    binds.py keys   --file=F --line=N --orig=TEXT --value=KEYS
    binds.py cmd    --file=F --line=N --orig=TEXT --value=COMMAND
    binds.py desc   --file=F --line=N --orig=TEXT --value=TEXT
    binds.py toggle --file=F --line=N --orig=TEXT --on=0|1
    binds.py delete --file=F --line=N --orig=TEXT
    binds.py add    --binds=FILE --value=KEYS --cmd=COMMAND [--desc=TEXT]

A bind is a statement  hl.bind("SUPER + V", <action>[, { description = "..." }])  that starts a line
(and may run over several: the end is found by matching the brackets, with Lua's strings and comments
skipped). Its keys are changed when they are a plain string, the command when the action is exactly
hl.dsp.exec_cmd("plain string"); other actions (functions, dispatchers built from variables) are listed
as the code they are and kept as they are. Switching off comments every line of the statement out.
The files are handled like execs.py does (line endings, symlinks, backups, one change at a time, a check
that the lines are still the ones listed). Prints JSON.
"""

import argparse
import json
import os
import re
import sys

import execs
from execs import decode, encode, fail, read, write, why_readonly, lua_files, mentions, MAX_FILE, MAX_ENTRIES

BIND = re.compile(r"^(?P<indent>[ \t]*)(?P<off>--+[ \t]*)?hl\.bind\(")
COMMENT_PREFIX = re.compile(r"^([ \t]*)--+[ \t]?")
LONG_OPEN = re.compile(r"\[(=*)\[")
STRING = re.compile(r"""^\s*(?P<q>["'])(?P<body>(?:\\.|(?!(?P=q)).)*)(?P=q)\s*$""", re.S)
EXEC = re.compile(r"""^\s*hl\.dsp\.exec_cmd\(\s*(?P<q>["'])(?P<body>(?:\\.|(?!(?P=q)).)*)(?P=q)\s*\)\s*$""", re.S)
DESCRIPTION = re.compile(r"""(?P<head>\bdescription\s*=\s*)(?P<q>["'])(?P<body>(?:\\.|(?!(?P=q)).)*)(?P=q)""", re.S)


def skip_string(text, i):
    """The index after the string or long string or comment that starts at i, or i when none does."""
    c = text[i]
    if c in "\"'":
        j = i + 1
        while j < len(text) and text[j] != c:
            j += 2 if text[j] == "\\" else 1
        return j + 1
    if text.startswith("--", i):
        m = LONG_OPEN.match(text, i + 2)
        if m:
            end = text.find("]" + m.group(1) + "]", m.end())
            return len(text) if end < 0 else end + len(m.group(1)) + 2
        end = text.find("\n", i)
        return len(text) if end < 0 else end
    if c == "[":
        m = LONG_OPEN.match(text, i)
        if m:
            end = text.find("]" + m.group(1) + "]", m.end())
            return len(text) if end < 0 else end + len(m.group(1)) + 2
    return i


def args_of(text):
    """The end of the hl.bind(...) call in `text` (index after its ")", or -1 while it isn't closed)
    and the spans of its top-level arguments."""
    depth, i, start, spans = 0, text.index("hl.bind(") + len("hl.bind"), None, []
    while i < len(text):
        j = skip_string(text, i)
        if j != i:
            i = j
            continue
        c = text[i]
        if c in "({[":
            depth += 1
            if depth == 1:
                start = i + 1
        elif c in ")}]":
            depth -= 1
            if depth == 0:
                spans.append((start, i))
                return i + 1, spans
        elif c == "," and depth == 1:
            spans.append((start, i))
            start = i + 1
        i += 1
    return -1, spans


def statement(lines, i):
    """The bind that starts at line index i: (last line index, text with comment marks off, off?),
    or None when it isn't closed or isn't a bind."""
    m = BIND.match(lines[i])
    if not m:
        return None
    off = bool(m.group("off"))
    parts = [COMMENT_PREFIX.sub(r"\1", lines[i], count=1) if off else lines[i]]
    j = i
    while True:
        end, _ = args_of("\n".join(parts))
        if end >= 0:
            return j, "\n".join(parts), off
        j += 1
        if j >= len(lines) or (off and not COMMENT_PREFIX.match(lines[j])):
            return None
        parts.append(COMMENT_PREFIX.sub(r"\1", lines[j], count=1) if off else lines[j])


def parse(text):
    """The parts of a statement's text: keys (str or None), action text, command (str or None), description."""
    end, spans = args_of(text)
    if len(spans) < 2:
        return None
    pieces = [text[a:b] for a, b in spans]
    keys = STRING.match(pieces[0])
    if not keys:
        return None
    action = pieces[1].strip()
    ex = EXEC.match(pieces[1])
    desc = DESCRIPTION.search(pieces[2]) if len(pieces) > 2 else None
    return {
        "spans": spans, "keys": decode(keys.group("body")),
        "action": re.sub(r"\s+", " ", action), "cmd": decode(ex.group("body")) if ex else None,
        "desc": decode(desc.group("body")) if desc else "",
    }


def block_comment_lines(lines):
    """Indexes of lines inside a --[[ ... ]] comment (nothing there is a bind)."""
    inside, out = None, set()
    for i, text in enumerate(lines):
        if inside is None:
            m = re.search(r"--\[(=*)\[", text)
            if m and "]" + m.group(1) + "]" not in text[m.end():]:
                inside = m.group(1)
        else:
            out.add(i)
            if "]" + inside + "]" in text:
                inside = None
    return out


def scan_file(path):
    try:
        if os.path.getsize(path) > MAX_FILE:
            return []
        lines = read(path)[1]
    except (OSError, ValueError):
        return []
    skip, out, i = block_comment_lines(lines), [], 0
    while i < len(lines):
        if i in skip or not BIND.match(lines[i]):
            i += 1
            continue
        st = statement(lines, i)
        info = parse(st[1]) if st else None
        if st and info:
            last, _, off = st
            out.append({"line": i + 1, "end": last + 1, "orig": "\n".join(lines[i:last + 1]), "enabled": not off,
                        "keys": info["keys"], "action": info["action"][:160], "cmd": info["cmd"], "desc": info["desc"],
                        "nested": bool(BIND.match(lines[i]).group("indent"))})
            i = last + 1
        else:
            i += 1
    return out


def scan(hypr, binds_file, shell_hypr):
    shell = os.path.realpath(os.path.join(hypr, "hi-shell"))
    paths = list(lua_files(hypr)) if os.path.isdir(hypr) else []
    own = os.path.realpath(binds_file)
    if os.path.exists(binds_file) and own not in {os.path.realpath(p) for p in paths}:
        paths.insert(0, binds_file)
    real_files = {os.path.realpath(p) for p in paths if not os.path.islink(p)}
    paths = [p for p in paths if not (os.path.islink(p) and os.path.realpath(p) in real_files)]
    entries = []
    for path in paths:
        mine = os.path.realpath(path) == own
        # hi-shell's own keybinds (hypr/hi-shell/keybinds.lua) are meant to be changed.
        reason = why_readonly(path, "/nonexistent")
        for e in scan_file(path):
            e.update(file=path, rel=os.path.relpath(path, hypr) if path.startswith(hypr) else path,
                     readonly=bool(reason), why=reason, own=mine)
            entries.append(e)
    entries.sort(key=lambda e: 0 if e["own"] else 1)
    roots = [r for r in (hypr, shell_hypr) if r and os.path.isdir(r)]
    outside = [p for p in lua_files(hypr) if not os.path.realpath(p).startswith(shell + os.sep)] if os.path.isdir(hypr) else []
    loaded = any(mentions(p, "hi-shell/hyprland.lua") for r in roots for p in lua_files(r)) \
        and any(mentions(p, "hi-shell/init.lua") or mentions(p, "hi-shell.lua") for p in outside)
    print(json.dumps({"entries": entries[:MAX_ENTRIES], "total": len(entries), "dir": hypr,
                      "exists": os.path.isdir(hypr), "loaded": loaded}))


def rewrite(path, line, orig, change):
    """Change the statement that starts at line `line` (1-based): change(lines_of_statement) -> new lines."""
    if os.path.islink(path):
        fail("That file is a symlink (managed elsewhere); change its target instead.")
    text, lines, eol = read(path)
    i = line - 1
    st = statement(lines, i) if 0 <= i < len(lines) else None
    if not st or "\n".join(lines[i:st[0] + 1]) != orig:
        fail("The file changed since the list was made; it's reloaded now.")
    last, body, off = st
    new = change(lines[i:last + 1], body, off)
    lines[i:last + 1] = new
    backup = path + ".backup-hi-shell-keybinds"
    if not os.path.exists(backup):
        write(backup, text, like=path)
    write(path, eol.join(lines), like=path)
    print(json.dumps({"ok": True}))


def replace_span(body, span, literal):
    a, b = span
    return body[:a] + literal + body[b:]


def set_keys(value):
    def change(old_lines, body, off):
        info = parse(body)
        a, b = info["spans"][0]
        new = replace_span(body, (a, b), encode(value))
        return restore(new, off)
    return change


def set_cmd(value):
    def change(old_lines, body, off):
        info = parse(body)
        if info["cmd"] is None:
            fail("That bind isn't a plain command; change it in the file.")
        a, b = info["spans"][1]
        piece = body[a:b]
        m = EXEC.match(piece)
        lit_a, lit_b = m.start("q") + a, m.end("body") + 1 + a
        return restore(body[:lit_a] + encode(value) + body[lit_b:], off)
    return change


def set_desc(value):
    def change(old_lines, body, off):
        info = parse(body)
        if len(info["spans"]) < 3 or not DESCRIPTION.search(body[info["spans"][2][0]:info["spans"][2][1]]):
            fail("That bind has no description to change in the file.")
        a, b = info["spans"][2]
        piece = DESCRIPTION.sub(lambda m: m.group("head") + encode(value), body[a:b], count=1)
        return restore(body[:a] + piece + body[b:], off)
    return change


def restore(text, off):
    """The statement text back as lines, commented out again when it was."""
    lines = text.split("\n")
    return ["-- " + t if off else t for t in lines] if off else lines


def toggle(on):
    def change(old_lines, body, off):
        if on == (not off):
            return old_lines
        if on:
            return [COMMENT_PREFIX.sub(r"\1", t, count=1) for t in old_lines]
        return [re.sub(r"^([ \t]*)", r"\1-- ", t, count=1) for t in old_lines]
    return change


def delete(old_lines, body, off):
    return []


def add(binds_file, keys, cmd, desc):
    os.makedirs(os.path.dirname(binds_file), exist_ok=True)
    if os.path.islink(binds_file):
        fail("binds.lua is a symlink (managed elsewhere); change its target instead.")
    opts = f", {{ description = {encode(desc)} }}" if desc else ""
    new = f"hl.bind({encode(keys)}, hl.dsp.exec_cmd({encode(cmd)}){opts})"
    head = ("-- hi-shell: keybinds added in Settings > Keybinds (editing this file by hand is fine).\n"
            "-- Loaded from ~/.config/hi-shell/hyprland.lua.\n")
    if not os.path.exists(binds_file):
        text = head + new + "\n"
    else:
        _, lines, eol = read(binds_file)
        if lines and lines[-1] == "":
            lines.pop()
        text = eol.join(lines + [new]) + eol
    write(binds_file, text, like=binds_file)
    print(json.dumps({"ok": True}))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("action", choices=["scan", "keys", "cmd", "desc", "toggle", "delete", "add"])
    for name in ("--hypr", "--binds", "--shell-hypr", "--file", "--orig", "--value", "--cmd", "--desc", "--on"):
        p.add_argument(name)
    p.add_argument("--line", type=int)
    a = p.parse_args()
    try:
        if a.action == "scan":
            scan(os.path.abspath(a.hypr), os.path.abspath(a.binds), os.path.abspath(a.shell_hypr) if a.shell_hypr else "")
        elif a.action == "add":
            if not (a.value or "").strip() or not (a.cmd or "").strip():
                fail("Keys and a command are needed.")
            add(os.path.abspath(a.binds), a.value.strip(), a.cmd.strip(), (a.desc or "").strip())
        elif a.action in ("keys", "cmd"):
            if not (a.value or "").strip():
                fail("Empty value.")
            rewrite(a.file, a.line, a.orig, (set_keys if a.action == "keys" else set_cmd)(a.value.strip()))
        elif a.action == "desc":
            rewrite(a.file, a.line, a.orig, set_desc((a.value or "").strip()))
        elif a.action == "toggle":
            rewrite(a.file, a.line, a.orig, toggle(a.on == "1"))
        else:
            rewrite(a.file, a.line, a.orig, delete)
    except SystemExit:
        raise
    except PermissionError as e:
        fail(f"No permission to write in {os.path.dirname(e.filename or '') or 'there'}.")
    except Exception as e:
        fail(f"{type(e).__name__}: {e}")


if __name__ == "__main__":
    main()
