#!/usr/bin/env python3
"""Cursor themes for Settings > Themes and Store: the installed ones, the KDE Store's, installing, applying, removing.

    cursor_themes.py installed                    -> {"current": ..., "themes": [{id, name, path, removable, samples}]}
    cursor_themes.py search [--query Q] [--sort S] [--page N]
    cursor_themes.py install PRODUCT [--file N]   -> lines {"progress": 0..1}, then {"installed": [theme ids]}
    cursor_themes.py apply THEME [--size N]       -> {"applied": THEME, "size": N}
    cursor_themes.py remove THEME                 -> {"removed": THEME}

The store, download and unpacking are icon_themes.py's (category 107, Cursors, instead of 132).
An Xcursor file can't be shown by Qt, so a few cursors of each theme are drawn to PNGs in
~/.cache/hi-shell/cursor-previews for the samples.
"""
import argparse
import os
import shutil
import struct
import sys
import zlib
from pathlib import Path

# Our own folder only (python -I leaves it off sys.path), for the shared store code.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import icon_themes as core  # noqa: E402

CATEGORY = 107
STATE_FILE = "cursor-store.json"
XCURSOR_IMAGE = 0xFFFD0002
PREVIEW_SIZE = 32
MAX_SIDE = 512
SIZES = range(12, 129)
# One picture per slot, the first name the theme has.
SAMPLES = [
    ["left_ptr", "default", "arrow"],
    ["pointer", "hand2", "pointing_hand", "hand1"],
    ["text", "xterm", "ibeam"],
    ["wait", "watch"],
    ["progress", "left_ptr_watch", "half-busy"],
    ["grabbing", "closedhand", "fleur", "move"],
]
Failure = core.Failure


def is_cursor_theme(path: Path) -> bool:
    """A folder with Xcursor files (cursors/) or a hyprcursor theme (manifest.hl / manifest.toml)."""
    return (path / "cursors").is_dir() or (path / "manifest.hl").is_file() or (path / "manifest.toml").is_file()


def theme_name(path: Path) -> str:
    index = core.read_index(path) or {}
    return index.get("Icon Theme", {}).get("Name") or path.name


# --- Xcursor to PNG ------------------------------------------------------------------------------

def xcursor_image(data: bytes, want: int = PREVIEW_SIZE) -> tuple[int, int, bytes] | None:
    """The image of an Xcursor file nearest `want` (the first frame): (width, height, ARGB premultiplied)."""
    if len(data) < 16 or data[:4] != b"Xcur":
        return None
    header, _version, ntoc = struct.unpack_from("<III", data, 4)
    toc = []
    for i in range(min(ntoc, 4096)):
        at = header + i * 12
        if at + 12 > len(data):
            break
        kind, size, pos = struct.unpack_from("<III", data, at)
        if kind == XCURSOR_IMAGE:
            toc.append((size, pos))
    if not toc:
        return None
    # The nearest size, the bigger one on a tie; the first of a size is the first frame.
    size, pos = min(toc, key=lambda e: (abs(e[0] - want), -e[0]))
    if pos + 36 > len(data):
        return None
    _hsize, kind, _sub, _ver, w, h = struct.unpack_from("<IIIIII", data, pos)
    if kind != XCURSOR_IMAGE or not (0 < w <= MAX_SIDE and 0 < h <= MAX_SIDE):
        return None
    start = pos + 36
    pixels = data[start:start + w * h * 4]
    if len(pixels) != w * h * 4:
        return None
    return w, h, pixels


def png_of(w: int, h: int, argb: bytes) -> bytes:
    """PNG (RGBA, straight alpha) from little-endian premultiplied ARGB pixels."""
    rows = bytearray()
    for y in range(h):
        rows.append(0)
        for x in range(w):
            b, g, r, a = argb[(y * w + x) * 4:(y * w + x) * 4 + 4]
            if 0 < a < 255:
                r, g, b = (min(255, c * 255 // a) for c in (r, g, b))
            rows += bytes((r, g, b, a))

    def chunk(tag: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(rows), 6)) + chunk(b"IEND", b""))


def cache_dir() -> Path:
    return Path(os.environ.get("XDG_CACHE_HOME") or core.home() / ".cache") / "hi-shell" / "cursor-previews"


def preview(source: Path, target: Path) -> bool:
    """Draw source (an Xcursor file) to target unless a fresh copy is there."""
    try:
        if target.is_file() and target.stat().st_mtime >= source.stat().st_mtime:
            return True
        image = xcursor_image(source.read_bytes())
        if not image:
            return False
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(png_of(*image))
        return True
    except OSError:
        return False


def samples(path: Path) -> list[str]:
    cursors = path / "cursors"
    if not cursors.is_dir():
        return []
    out = []
    for names in SAMPLES:
        for n in names:
            source = cursors / n
            target = cache_dir() / path.name / f"{n}.png"
            if source.is_file() and preview(source, target):
                out.append(str(target))
                break
    return out


# --- installed -----------------------------------------------------------------------------------

def current_theme() -> str:
    try:
        out = core.subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", "cursor-theme"],
                                  capture_output=True, text=True, timeout=5)
        if out.returncode == 0 and out.stdout.strip().strip("'"):
            return out.stdout.strip().strip("'")
    except (OSError, core.subprocess.SubprocessError):
        pass
    for path, section, key in ((core.config_home() / "kcminputrc", "Mouse", "cursorTheme"),
                               (core.home() / ".icons" / "default" / "index.theme", "Icon Theme", "Inherits")):
        try:
            value = core.parse_ini(path.read_text(errors="replace")).get(section, {}).get(key, "")
        except OSError:
            continue
        if value:
            return value.split(",")[0].strip()
    return ""


def installed() -> dict:
    seen: dict[str, dict] = {}
    users = [d.resolve() for d in core.user_dirs() if d.exists()]
    for base in core.search_dirs():
        try:
            entries = sorted(base.iterdir(), key=lambda p: p.name.lower())
        except OSError:
            continue
        for path in entries:
            if path.name in seen or path.name == "default" or not path.is_dir() or not is_cursor_theme(path):
                continue
            seen[path.name] = {
                "id": path.name,
                "name": theme_name(path),
                "path": str(path),
                "removable": base.resolve() in users,
                "samples": samples(path),
            }
    return {"current": current_theme(), "themes": sorted(seen.values(), key=lambda t: t["name"].lower())}


def find_themes(root: Path) -> list[Path]:
    """Cursor themes under root (the folders holding cursors/ or a hyprcursor manifest), outermost only."""
    found: list[Path] = []
    marks = sorted(list(root.rglob("cursors")) + list(root.rglob("manifest.hl")) + list(root.rglob("manifest.toml")))
    for mark in marks:
        theme = mark.parent
        if mark.name == "cursors" and not mark.is_dir():
            continue
        if theme == root or theme in found or any(f in theme.parents for f in found):
            continue
        found.append(theme)
    return found


# --- applying and removing -----------------------------------------------------------------------

def apply(theme: str, size: int) -> dict:
    if not core.valid_theme_id(theme) or not any(is_cursor_theme(d / theme) for d in core.search_dirs()):
        raise Failure(f"no cursor theme named {theme}")
    if size not in SIZES:
        raise Failure(f"cursor size {size} is out of range")
    cfg = core.config_home()
    for gtk in ("gtk-3.0", "gtk-4.0"):
        ini = cfg / gtk / "settings.ini"
        if ini.is_file():
            core.set_ini_key(ini, "Settings", "gtk-cursor-theme-name", theme)
            core.set_ini_key(ini, "Settings", "gtk-cursor-theme-size", str(size))
    core.set_ini_key(cfg / "kcminputrc", "Mouse", "cursorTheme", theme)
    core.set_ini_key(cfg / "kcminputrc", "Mouse", "cursorSize", str(size))
    # The fallback X apps and toolkits without settings of their own read.
    default = core.home() / ".icons" / "default"
    if not is_cursor_theme(default):
        core.set_ini_key(default / "index.theme", "Icon Theme", "Inherits", theme)
    core.run_quiet(["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", theme])
    core.run_quiet(["gsettings", "set", "org.gnome.desktop.interface", "cursor-size", str(size)])
    core.run_quiet(["hyprctl", "setcursor", theme, str(size)])
    return {"applied": theme, "size": size}


def remove(theme: str) -> dict:
    if not core.valid_theme_id(theme) or theme == "default":
        raise Failure("bad theme name")
    if theme == current_theme():
        raise Failure("that theme is in use: apply another one first")
    for base in core.user_dirs():
        target = base / theme
        if target.is_dir() and not target.is_symlink() and is_cursor_theme(target):
            shutil.rmtree(target)
            shutil.rmtree(cache_dir() / theme, ignore_errors=True)
            return {"removed": theme}
    raise Failure("only themes in ~/.local/share/icons or ~/.icons can be removed")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("installed")
    s = sub.add_parser("search")
    s.add_argument("--query", default="")
    s.add_argument("--sort", default="popular", choices=sorted(core.SORTS))
    s.add_argument("--page", type=int, default=0)
    i = sub.add_parser("install")
    i.add_argument("product")
    i.add_argument("--file", type=int)
    a = sub.add_parser("apply")
    a.add_argument("theme")
    a.add_argument("--size", type=int, default=24)
    sub.add_parser("remove").add_argument("theme")
    args = ap.parse_args(argv)
    try:
        if args.cmd == "installed":
            core.emit(installed())
        elif args.cmd == "search":
            core.emit(core.search(args.query, args.sort, args.page, CATEGORY))
        elif args.cmd == "install":
            core.emit(core.install(args.product, args.file, CATEGORY, find_themes, STATE_FILE, "cursor theme"))
        elif args.cmd == "apply":
            core.emit(apply(args.theme, args.size))
        else:
            core.emit(remove(args.theme))
    except Failure as e:
        core.emit({"error": str(e)})
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
