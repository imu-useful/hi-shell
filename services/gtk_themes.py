#!/usr/bin/env python3
"""GTK themes for Settings > Themes and Store: the installed ones, the KDE Store's, installing, applying, removing.

    gtk_themes.py installed                    -> {"current": ..., "themes": [{id, name, path, removable, colors}]}
    gtk_themes.py search [--query Q] [--sort S] [--page N]
    gtk_themes.py install PRODUCT [--file N]   -> lines {"progress": 0..1}, then {"installed": [theme ids]}
    gtk_themes.py apply THEME                  -> {"applied": THEME}
    gtk_themes.py remove THEME                 -> {"removed": THEME}

The store, download and unpacking are icon_themes.py's (category 135, GTK3/4 Themes); themes go to
~/.local/share/themes. A theme's main colors are read from its gtk-3.0/gtk.css for the samples.
hi-shell's own wallpaper colors (appThemes.gtk) sit on top of whichever theme is picked.
"""
import argparse
import os
import re
import shutil
import sys
from pathlib import Path

# Our own folder only (python -I leaves it off sys.path), for the shared store code.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import icon_themes as core  # noqa: E402

CATEGORY = 135
STATE_FILE = "gtk-store.json"
# The colors shown for a theme, in this order, when its gtk.css defines them.
COLOR_NAMES = ["theme_bg_color", "theme_base_color", "theme_fg_color", "theme_selected_bg_color"]
COLOR = re.compile(r"@define-color\s+([\w-]+)\s+([^;]+);")
IMPORT = re.compile(r"""@import\s+(?:url\()?["']([^"')]+)["']\)?""")
NOT_THEMES = {"Default", "Emacs"}
Failure = core.Failure


def user_dirs() -> list[Path]:
    return [core.data_home() / "themes", core.home() / ".themes"]


def search_dirs() -> list[Path]:
    system = [Path(d) / "themes" for d in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":") if d]
    return user_dirs() + system


def is_gtk_theme(path: Path) -> bool:
    return (path / "gtk-3.0" / "gtk.css").is_file() or (path / "gtk-4.0" / "gtk.css").is_file()


def theme_name(path: Path) -> str:
    index = core.read_index(path) or {}
    return index.get("Desktop Entry", {}).get("Name") or index.get("X-GNOME-Metatheme", {}).get("Name") or path.name


def css_colors(css: Path, depth: int = 0) -> dict[str, str]:
    """@define-color values of a gtk.css and the files it imports (one level), first one wins."""
    try:
        text = css.read_text(errors="replace")
    except OSError:
        return {}
    found: dict[str, str] = {}
    for name, value in COLOR.findall(text):
        found.setdefault(name, value.strip())
    if depth < 1:
        for ref in IMPORT.findall(text):
            if "://" in ref and not ref.startswith("file://"):
                continue
            target = (css.parent / ref.removeprefix("file://")).resolve()
            if css.parent.resolve() in target.parents:
                for k, v in css_colors(target, depth + 1).items():
                    found.setdefault(k, v)
    return found


def resolve(value: str, colors: dict[str, str], depth: int = 0) -> str:
    """A color as #rrggbb (or #rgb / rgb() as the theme wrote it); "" for what QML can't read."""
    value = value.strip()
    if value.startswith("@") and depth < 5:
        return resolve(colors.get(value[1:], ""), colors, depth + 1)
    if re.fullmatch(r"#[0-9a-fA-F]{3}|#[0-9a-fA-F]{6}|#[0-9a-fA-F]{8}", value):
        return value
    m = re.fullmatch(r"rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*[\d.]+)?\s*\)", value)
    if m:
        return "#" + "".join(f"{min(255, int(c)):02x}" for c in m.groups())
    return ""


def colors_of(path: Path) -> list[str]:
    for css in (path / "gtk-3.0" / "gtk.css", path / "gtk-4.0" / "gtk.css"):
        defined = css_colors(css)
        out = [c for c in (resolve(defined.get(n, ""), defined) for n in COLOR_NAMES) if c]
        if out:
            return out
    return []


def current_theme() -> str:
    try:
        out = core.subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", "gtk-theme"],
                                  capture_output=True, text=True, timeout=5)
        if out.returncode == 0 and out.stdout.strip().strip("'"):
            return out.stdout.strip().strip("'")
    except (OSError, core.subprocess.SubprocessError):
        pass
    try:
        ini = core.parse_ini((core.config_home() / "gtk-3.0" / "settings.ini").read_text(errors="replace"))
        return ini.get("Settings", {}).get("gtk-theme-name", "")
    except OSError:
        return ""


def installed() -> dict:
    seen: dict[str, dict] = {}
    users = [d.resolve() for d in user_dirs() if d.exists()]
    for base in search_dirs():
        try:
            entries = sorted(base.iterdir(), key=lambda p: p.name.lower())
        except OSError:
            continue
        for path in entries:
            if path.name in seen or path.name in NOT_THEMES or not path.is_dir() or not is_gtk_theme(path):
                continue
            seen[path.name] = {"id": path.name, "name": theme_name(path), "path": str(path),
                               "removable": base.resolve() in users, "samples": [], "colors": colors_of(path)}
    return {"current": current_theme(), "themes": sorted(seen.values(), key=lambda t: t["name"].lower())}


def find_themes(root: Path) -> list[Path]:
    """GTK themes under root (the folders holding gtk-3.0/ or gtk-4.0/ with a gtk.css), outermost only."""
    found: list[Path] = []
    for css in sorted(root.rglob("gtk.css")):
        if css.parent.name not in ("gtk-3.0", "gtk-4.0"):
            continue
        theme = css.parent.parent
        if theme == root or theme in found or any(f in theme.parents for f in found):
            continue
        found.append(theme)
    return found


def apply(theme: str) -> dict:
    if not core.valid_theme_id(theme) or not any(is_gtk_theme(d / theme) for d in search_dirs()):
        raise Failure(f"no GTK theme named {theme}")
    cfg = core.config_home()
    for gtk in ("gtk-3.0", "gtk-4.0"):
        ini = cfg / gtk / "settings.ini"
        if ini.is_file() or gtk == "gtk-3.0":
            core.set_ini_key(ini, "Settings", "gtk-theme-name", theme)
    core.run_quiet(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", theme])
    return {"applied": theme}


def remove(theme: str) -> dict:
    if not core.valid_theme_id(theme):
        raise Failure("bad theme name")
    if theme == current_theme():
        raise Failure("that theme is in use: apply another one first")
    for base in user_dirs():
        target = base / theme
        if target.is_dir() and not target.is_symlink() and is_gtk_theme(target):
            shutil.rmtree(target)
            return {"removed": theme}
    raise Failure("only themes in ~/.local/share/themes or ~/.themes can be removed")


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
    sub.add_parser("apply").add_argument("theme")
    sub.add_parser("remove").add_argument("theme")
    args = ap.parse_args(argv)
    try:
        if args.cmd == "installed":
            core.emit(installed())
        elif args.cmd == "search":
            core.emit(core.search(args.query, args.sort, args.page, CATEGORY))
        elif args.cmd == "install":
            core.emit(core.install(args.product, args.file, CATEGORY, find_themes, STATE_FILE, "GTK theme",
                                   core.data_home() / "themes"))
        elif args.cmd == "apply":
            core.emit(apply(args.theme))
        else:
            core.emit(remove(args.theme))
    except Failure as e:
        core.emit({"error": str(e)})
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
