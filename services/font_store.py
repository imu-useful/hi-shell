#!/usr/bin/env python3
"""Fonts for Settings > Store and Themes: Google Fonts' families to install for this user, and removing them.

    font_store.py installed                                 -> {"current": "", "themes": [{id, name, path, removable, files}]}
    font_store.py search [--query Q] [--sort S] [--page N] [--filter CATEGORY]
                                                            -> {"total": N, "items": [{id, name, category, styles, preview}]}
    font_store.py install FAMILY_ID                         -> lines {"progress": 0..1}, then {"installed": [FAMILY_ID]}
    font_store.py remove FAMILY_ID                          -> {"removed": FAMILY_ID}

The catalog and the files' addresses come from google-webfonts-helper (gwfh.mranftl.com: every
style of a family as one TTF with all its scripts), the files from fonts.gstatic.com, a preview
of each family from Fontsource's CDN. Families go to ~/.local/share/fonts/hi-shell/<id>, then
fc-cache. The catalog is kept for a day in ~/.cache/hi-shell/font-catalog.json.
"""
import argparse
import json
import os
import re
import shutil
import sys
import time
import urllib.parse
from pathlib import Path

# Our own folder only (python -I leaves it off sys.path), for the shared download code.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import icon_themes as core  # noqa: E402

CATALOG = "https://gwfh.mranftl.com/api/fonts"
PREVIEW = "https://cdn.jsdelivr.net/fontsource/fonts/{id}@latest/latin-{weight}-normal.ttf"
FILES_HOST = "https://fonts.gstatic.com/"
CATALOG_TTL = 24 * 3600
PAGE_SIZE = 24
MAX_STYLES = 40
SORTS = ("popular", "new", "name")
CATEGORIES = ("sans-serif", "serif", "monospace", "display", "handwriting")
FAMILY_ID = re.compile(r"[a-z0-9][a-z0-9-]{0,80}")
Failure = core.Failure


def fonts_dir() -> Path:
    return core.data_home() / "fonts" / "hi-shell"


def cache_file() -> Path:
    return Path(os.environ.get("XDG_CACHE_HOME") or core.home() / ".cache") / "hi-shell" / "font-catalog.json"


def catalog() -> list[dict]:
    """Every family of the catalog, from the cache when it's less than a day old."""
    cache = cache_file()
    try:
        if time.time() - cache.stat().st_mtime < CATALOG_TTL:
            data = json.loads(cache.read_text())
            if isinstance(data, list) and data:
                return data
    except (OSError, ValueError):
        pass
    req = core.urllib.request.Request(CATALOG, headers={"User-Agent": core.USER_AGENT, "Accept": "application/json"})
    try:
        with core.urllib.request.urlopen(req, timeout=core.TIMEOUT) as resp:
            data = json.loads(resp.read().decode("utf-8", "replace"))
    except (OSError, ValueError) as e:
        # A stale copy beats nothing.
        try:
            return json.loads(cache.read_text())
        except (OSError, ValueError):
            raise Failure(f"font catalog unreachable: {e}") from e
    if not isinstance(data, list):
        raise Failure("the font catalog answered with something else")
    cache.parent.mkdir(parents=True, exist_ok=True)
    cache.write_text(json.dumps(data))
    return data


def preview_weight(variants: list[str]) -> str:
    plain = [v for v in variants if v.isdigit()] + (["400"] if "regular" in variants else [])
    return "400" if "400" in plain else (min(plain, key=lambda w: abs(int(w) - 400)) if plain else "400")


def item_of(f: dict) -> dict:
    variants = f.get("variants") or []
    return {
        "id": f.get("id", ""),
        "name": f.get("family", ""),
        "category": f.get("category", ""),
        "styles": len(variants),
        "scripts": f.get("subsets") or [],
        "changed": f.get("lastModified", ""),
        "preview": PREVIEW.format(id=f.get("id", ""), weight=preview_weight(variants)),
        "page": f"https://fonts.google.com/specimen/{urllib.parse.quote(f.get('family', '').replace(' ', '+'), safe='+')}",
    }


def search(query: str, sort: str, page: int, category: str) -> dict:
    words = query.lower().split()
    found = [f for f in catalog() if isinstance(f, dict) and f.get("id")
             and all(w in f.get("family", "").lower() for w in words)
             and (not category or f.get("category") == category)]
    if sort == "new":
        found.sort(key=lambda f: f.get("lastModified", ""), reverse=True)
    elif sort == "name":
        found.sort(key=lambda f: f.get("family", "").lower())
    else:
        found.sort(key=lambda f: f.get("popularity") or 10 ** 6)
    start = max(0, page) * PAGE_SIZE
    return {"total": len(found), "page": page, "items": [item_of(f) for f in found[start:start + PAGE_SIZE]]}


def installed() -> dict:
    themes = []
    base = fonts_dir()
    for d in sorted(base.iterdir()) if base.is_dir() else []:
        if not d.is_dir():
            continue
        try:
            meta = json.loads((d / "font.json").read_text())
        except (OSError, ValueError):
            meta = {}
        files = sorted(str(p) for p in d.glob("*.ttf"))
        if not files:
            continue
        regular = next((f for f in files if f.endswith("-regular.ttf")), files[0])
        themes.append({"id": d.name, "name": meta.get("family") or d.name, "category": meta.get("category", ""),
                       "path": str(d), "removable": True, "samples": [], "files": files, "regular": regular})
    return {"current": "", "themes": sorted(themes, key=lambda t: t["name"].lower())}


def refresh_cache() -> None:
    core.run_quiet(["fc-cache", "-f", str(fonts_dir())])


def install(family_id: str) -> dict:
    if not FAMILY_ID.fullmatch(family_id):
        raise Failure("not a font id")
    entry = next((f for f in catalog() if f.get("id") == family_id), None)
    if not entry:
        raise Failure("no such font in the catalog")
    subsets = ",".join(entry.get("subsets") or ["latin"])
    data = fetch_plain(f"{CATALOG}/{family_id}?subsets={urllib.parse.quote(subsets)}")
    styles = [v for v in data.get("variants") or [] if str(v.get("ttf", "")).startswith(FILES_HOST)][:MAX_STYLES]
    if not styles:
        raise Failure("the catalog has no files for this font")
    target = fonts_dir() / family_id
    work = fonts_dir() / f".{family_id}.part"
    shutil.rmtree(work, ignore_errors=True)
    work.mkdir(parents=True)
    try:
        for n, style in enumerate(styles):
            name = re.sub(r"[^a-z0-9]", "", str(style.get("id", n)).lower()) or str(n)
            core.download(style["ttf"], work / f"{family_id}-{name}.ttf", report=False)
            core.emit({"progress": round((n + 1) / len(styles), 3)})
        (work / "font.json").write_text(json.dumps({"family": entry.get("family", family_id), "category": entry.get("category", "")}))
        shutil.rmtree(target, ignore_errors=True)
        work.rename(target)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    refresh_cache()
    return {"installed": [family_id], "family": entry.get("family", family_id)}


def fetch_plain(url: str) -> dict:
    req = core.urllib.request.Request(url, headers={"User-Agent": core.USER_AGENT, "Accept": "application/json"})
    try:
        with core.urllib.request.urlopen(req, timeout=core.TIMEOUT) as resp:
            data = json.loads(resp.read().decode("utf-8", "replace"))
    except (OSError, ValueError) as e:
        raise Failure(f"font catalog unreachable: {e}") from e
    if not isinstance(data, dict):
        raise Failure("the font catalog answered with something else")
    return data


def remove(family_id: str) -> dict:
    if not FAMILY_ID.fullmatch(family_id):
        raise Failure("not a font id")
    target = fonts_dir() / family_id
    if not target.is_dir() or target.is_symlink():
        raise Failure("only fonts installed from the store can be removed")
    shutil.rmtree(target)
    refresh_cache()
    return {"removed": family_id}


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("installed")
    s = sub.add_parser("search")
    s.add_argument("--query", default="")
    s.add_argument("--sort", default="popular", choices=SORTS + ("rating",))
    s.add_argument("--page", type=int, default=0)
    s.add_argument("--filter", default="", choices=("",) + CATEGORIES)
    i = sub.add_parser("install")
    i.add_argument("product")
    i.add_argument("--file", type=int)
    sub.add_parser("remove").add_argument("theme")
    args = ap.parse_args(argv)
    try:
        if args.cmd == "installed":
            core.emit(installed())
        elif args.cmd == "search":
            core.emit(search(args.query, args.sort, args.page, args.filter))
        elif args.cmd == "install":
            core.emit(install(args.product))
        else:
            core.emit(remove(args.theme))
    except Failure as e:
        core.emit({"error": str(e)})
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
