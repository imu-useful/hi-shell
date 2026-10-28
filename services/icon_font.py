#!/usr/bin/env python3
"""A small copy of the icon font with only the icons hi-shell uses (common/IconFont.qml).

    icon_font.py --family "Material Symbols Rounded" --scan SHELL_DIR --out DIR

Material Symbols holds ~3800 icons (15 MB, mapped once per variant by Qt, ~50 MB of
memory); the shell uses a few hundred. This finds the icon names in the shell's QML and
JS (quoted words, and templates like `battery_${n}_bar`), keeps just those ligatures,
pins the axes the shell never changes (weight 400, grade 0; FILL and opsz stay), and
renames the family to "<family> hi-shell <key>" (the key changes with every rebuild: Qt keeps
a family it has loaded once, so a rebuilt font under the same name would show the old glyphs).
The key follows the icons found, not every word in the code, so the font is rebuilt only when the
set of icons changes (the icon names of the source font are cached in DIR/names.json).
Writes DIR/icons.ttf (loaded by the shell from the first frame) and prints its path; a
hash of the font and the names found, in DIR/icons.key, keeps it from being rebuilt
until either changes. Needs python-fonttools; prints nothing (and
the shell keeps the full font) without it.
"""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys

WORD = re.compile(r"""["'`]([a-z][a-z0-9_]{1,60})["'`]""")
TEMPLATE = re.compile(r"`([a-z0-9_]*\$\{[^`]*\}[a-z0-9_]*)`")


def candidates(root):
    words, templates = set(), set()
    for base, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if not d.startswith(".") and d != "__pycache__"]
        for f in files:
            if f.endswith((".qml", ".js")):
                text = open(os.path.join(base, f), encoding="utf-8", errors="ignore").read()
                words.update(WORD.findall(text))
                for t in TEMPLATE.findall(text):
                    # Some fixed text around the variable part, or it would match every icon.
                    fixed = re.sub(r"\$\{[^}]*\}", "", t)
                    if re.fullmatch(r"[a-z0-9_]*(\$\{[^}]*\}[a-z0-9_]*)+", t) and len(fixed) >= 3:
                        templates.add(re.sub(r"\$\{[^}]*\}", "[a-z0-9_]*", t))
    return words, templates


def font_file(family):
    out = subprocess.run(["fc-match", "-f", "%{file}", family], capture_output=True, text=True).stdout.strip()
    return out if out and family.split()[0].lower() in os.path.basename(out).lower() else ""


def ligatures(font):
    """icon name -> ligature glyph"""
    cmap = {g: chr(u) for u, g in font.getBestCmap().items()}
    names = {}
    for lookup in font["GSUB"].table.LookupList.Lookup:
        for sub in lookup.SubTable:
            if sub.LookupType == 7:
                sub = sub.ExtSubTable
            if getattr(sub, "LookupType", None) != 4:
                continue
            for first, ligs in sub.ligatures.items():
                for lig in ligs:
                    chars = [cmap.get(g) for g in [first] + list(lig.Component)]
                    if all(chars):
                        names["".join(chars)] = lig.LigGlyph
    return names


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--family", required=True)
    p.add_argument("--scan", required=True)
    p.add_argument("--out", required=True)
    args = p.parse_args()

    src = font_file(args.family)
    if not src:
        return 1
    words, templates = candidates(args.scan)
    st = os.stat(src)
    out = os.path.join(args.out, "icons.ttf")
    stamp = os.path.join(args.out, "icons.key")
    names_cache = os.path.join(args.out, "names.json")
    source = [src, st.st_size, int(st.st_mtime)]

    def pick(names):
        used = {n for n in names if n in words}
        for t in templates:
            used.update(n for n in names if re.fullmatch(t, n))
        return used

    def key_of(used):
        return hashlib.sha1(repr((4, args.family, source, sorted(used))).encode()).hexdigest()[:12]

    # With the names cached, the key is known without opening the font.
    try:
        with open(names_cache) as f:
            cached = json.load(f)
        if cached["source"] == source and os.path.exists(out) and os.path.exists(stamp):
            if open(stamp).read().strip() == key_of(pick(cached["names"])):
                print(out)
                return 0
    except (OSError, ValueError, KeyError):
        pass

    try:
        from fontTools.ttLib import TTFont
        from fontTools.subset import Options, Subsetter
        from fontTools.varLib import instancer
    except ImportError:
        return 1

    font = TTFont(src)
    names = ligatures(font)
    used = pick(names)
    key = key_of(used)
    os.makedirs(args.out, exist_ok=True)
    with open(names_cache, "w") as f:
        json.dump({"source": source, "names": sorted(names)}, f)
    if os.path.exists(out) and os.path.exists(stamp) and open(stamp).read().strip() == key:
        print(out)
        return 0

    options = Options()
    options.layout_features = ["liga", "rlig", "calt", "ccmp"]
    options.layout_closure = False
    options.name_IDs = ["*"]
    options.notdef_outline = True
    sub = Subsetter(options)
    # The font's plain characters (letters the ligatures are typed with, digits, …):
    # few and small, and text set in the icon font falls back to other fonts without them.
    letters = [c for c in font.getBestCmap() if c < 0x2000]
    sub.populate(glyphs=sorted(names[n] for n in used), unicodes=letters)
    sub.subset(font)

    # Pinned on the small font: quick there.
    axes = {a.axisTag for a in font["fvar"].axes} if "fvar" in font else set()
    pin = {tag: value for tag, value in (("wght", 400), ("GRAD", 0)) if tag in axes}
    if pin:
        font = instancer.instantiateVariableFont(font, pin)

    family = f"{args.family} hi-shell {key[:6]}"
    for rec in font["name"].names:
        if rec.nameID in (1, 4, 16):
            rec.string = family
        elif rec.nameID == 6:
            rec.string = family.replace(" ", "")

    os.makedirs(args.out, exist_ok=True)
    tmp = out + ".tmp"
    font.save(tmp)
    os.replace(tmp, out)
    with open(stamp, "w") as f:
        f.write(key + "\n")
    print(f"icon_font: {len(used)} of {len(names)} icons, {os.path.getsize(out) // 1024} KB", file=sys.stderr)
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
