#!/usr/bin/env python3
"""Write or remove hi-shell's block in an app's config.

  app_themes.py block <file> <comment-open> <comment-close> <block text>
  app_themes.py file <file> <file text>

An empty text removes the block / deletes the file. `block` keeps everything else in the
file and replaces only what sits between the "hi-shell begin" / "hi-shell end" markers
(a new block goes first: CSS @import lines must come before any rule).
"""
import os
import re
import sys
import tempfile

BEGIN, END = "hi-shell begin (generated; edits inside are overwritten)", "hi-shell end"


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
    with os.fdopen(fd, "w") as f:
        f.write(text)
    os.replace(tmp, path)


def main():
    mode, path = sys.argv[1], os.path.expanduser(sys.argv[2])
    body = sys.argv[-1]
    if mode == "file":
        if body.strip():
            write(path, body)
        elif os.path.exists(path):
            os.remove(path)
        return
    open_c, close_c = sys.argv[3], sys.argv[4]
    begin, end = f"{open_c} {BEGIN} {close_c}", f"{open_c} {END} {close_c}"
    try:
        old = open(path).read()
    except FileNotFoundError:
        old = ""
    pattern = re.compile(re.escape(begin) + r".*?" + re.escape(end) + r"\n?", re.S)
    stripped = pattern.sub("", old)
    if not body.strip():
        if stripped != old:
            write(path, stripped)
        return
    block = f"{begin}\n{body.rstrip()}\n{end}\n"
    # In place when the block exists; otherwise at the top (CSS @import lines must come first).
    new = pattern.sub(lambda m: block, old, count=1) if pattern.search(old) else block + stripped
    if new != old:
        write(path, new)


main()
