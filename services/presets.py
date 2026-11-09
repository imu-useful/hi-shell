#!/usr/bin/env python3
"""Save, share and restore hi-shell presets and profiles.

    presets.py export OUT.tar.gz --config CONFIG [--colors COLORS] [--wallpaper FILE] [--profile --widgets-dir DIR --binds FILE]
    presets.py import IN.tar.gz --config CONFIG --wallpapers DIR [--search DIR...] [--only PARTS] [--trust]
                       [--dry-run] [--widgets-dir DIR] [--binds FILE] [--backup-dir DIR]
    presets.py diff   IN.tar.gz --config CONFIG [--only PARTS] [--trust]
    presets.py dump   DIR  --config CONFIG [same options as export]        (a folder for git, one file per section)
    presets.py restore DIR --config CONFIG --wallpapers DIR [same options as import]
    presets.py undo   --config CONFIG --backup-dir DIR [--widgets-dir DIR] [--binds FILE]
    presets.py list DIR

A preset is a gzipped tar (or, with `dump`, a folder) with manifest.json, config.json, colors.json and
wallpaper.<ext>. A *profile* (--profile) also carries your rules, script widgets, QML widgets (widgets/*.qml)
and keybinds (binds.lua). Exports leave out API keys, location and this machine's monitor layout; imports keep
the current ones.

Presets come from other people, so an import leaves out everything that can run code: rules, script widgets,
widget files and keybinds. A profile you made yourself is loaded with --trust.

--only takes a comma separated list of parts: config sections (bar, dock, desktop, appearance, ...) and colors,
wallpaper, widgets, keybinds. Before anything is overwritten the current files are copied to --backup-dir
(`undo` puts the last copy back). `import` prints {"wallpaper": path, "mode": mode, "changes": n}.
`list` prints one JSON object per preset: {"path", "name", "created", "wallpaper", "profile"}.
"""

from __future__ import annotations

import argparse
import copy
import io
import json
import re
import shutil
import sys
import tarfile
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

VERSION = 1
# Config keys that belong to the machine or the person, not the look.
PRIVATE = [("wallpapers", "unsplashKey"), ("wallpapers", "wallhavenKey"), ("hyprland", "monitors"),
           ("weather", "latitude"), ("weather", "longitude"), ("weather", "city"),
           ("ai", "openrouterKey"), ("ai", "keys"), ("ai", "urls"), ("hyprland", "keepFiles"), ("update", "channel")]
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".avif", ".jxl"}
# Top-level config keys that run code: only a trusted profile brings them.
CODE_KEYS = ("rules", "rulesEnabled")
WIDGET_NAME = re.compile(r"^[A-Za-z][A-Za-z0-9_]*\.qml$")
MAX_FILE = 256 * 1024
MAX_WIDGETS = 50
PSEUDO_PARTS = ("colors", "wallpaper", "widgets", "keybinds")
KEEP_BACKUPS = 20


def fail(msg: str) -> int:
    print(msg, file=sys.stderr)
    return 1


# --------------------------------------------------------------------------- bundle


@dataclass(frozen=True)
class Bundle:
    """What a preset or profile holds, read from a tar or a folder."""

    manifest: dict
    config: dict
    colors: dict
    wallpaper_name: str = ""
    wallpaper_data: bytes = b""
    widgets: dict[str, bytes] = field(default_factory=dict)
    binds: bytes | None = None

    @property
    def is_profile(self) -> bool:
        return bool(self.manifest.get("profile"))


def add_bytes(tar: tarfile.TarFile, name: str, data: bytes) -> None:
    info = tarfile.TarInfo(name)
    info.size = len(data)
    info.mtime = int(time.time())
    tar.addfile(info, io.BytesIO(data))


def read_member(tar: tarfile.TarFile, name: str) -> bytes | None:
    try:
        m = tar.getmember(name)
    except KeyError:
        return None
    if not m.isfile() or m.size > 64 * 1024 * 1024:
        return None
    f = tar.extractfile(m)
    return f.read() if f else None


def load_json(data: bytes | None) -> dict:
    try:
        value = json.loads(data or b"{}")
    except (ValueError, UnicodeDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def load_tar(path: Path) -> Bundle:
    try:
        tar = tarfile.open(path, "r:gz")
    except (OSError, tarfile.TarError) as e:
        raise ValueError(f"not a preset archive: {e}") from e
    with tar:
        manifest = load_json(read_member(tar, "manifest.json"))
        if manifest.get("hiShellPreset") != VERSION:
            raise ValueError("not a hi-shell preset (manifest.json missing or wrong version)")
        wall = manifest.get("wallpaper", "")
        # Only a flat file name with an image extension; never a path from the archive.
        wall_ok = bool(wall) and "/" not in wall and Path(wall).suffix.lower() in IMAGE_EXTS
        widgets: dict[str, bytes] = {}
        for member in tar.getmembers():
            name = member.name
            if name.startswith("widgets/") and member.isfile() and member.size <= MAX_FILE:
                base = name[len("widgets/"):]
                if WIDGET_NAME.match(base) and len(widgets) < MAX_WIDGETS:
                    widgets[base] = read_member(tar, name) or b""
        binds = read_member(tar, "binds.lua")
        return Bundle(
            manifest=manifest,
            config=load_json(read_member(tar, "config.json")),
            colors=load_json(read_member(tar, "colors.json")),
            wallpaper_name=wall if wall_ok else "",
            wallpaper_data=(read_member(tar, wall) or b"") if wall_ok else b"",
            widgets=widgets,
            binds=binds if binds is not None and len(binds) <= MAX_FILE else None,
        )


def dir_name_of(key: str) -> str:
    return re.sub(r"[^A-Za-z0-9_-]", "_", key)


def load_dir(path: Path) -> Bundle:
    manifest = load_json((path / "manifest.json").read_bytes() if (path / "manifest.json").is_file() else None)
    if manifest.get("hiShellPreset") != VERSION:
        raise ValueError("not a hi-shell preset folder (manifest.json missing or wrong version)")
    config: dict = {}
    cdir = path / "config"
    if cdir.is_dir():
        for f in sorted(cdir.glob("*.json")):
            part = load_json(f.read_bytes())
            if f.stem == "_root":
                config.update(part)
            else:
                config[f.stem] = part
    wall = manifest.get("wallpaper", "")
    wall_ok = bool(wall) and "/" not in wall and Path(wall).suffix.lower() in IMAGE_EXTS and (path / wall).is_file()
    widgets = {}
    wdir = path / "widgets"
    if wdir.is_dir():
        for f in sorted(wdir.glob("*.qml"))[:MAX_WIDGETS]:
            if WIDGET_NAME.match(f.name) and f.stat().st_size <= MAX_FILE:
                widgets[f.name] = f.read_bytes()
    binds_file = path / "binds.lua"
    return Bundle(
        manifest=manifest,
        config=config,
        colors=load_json((path / "colors.json").read_bytes() if (path / "colors.json").is_file() else None),
        wallpaper_name=wall if wall_ok else "",
        wallpaper_data=(path / wall).read_bytes() if wall_ok else b"",
        widgets=widgets,
        binds=binds_file.read_bytes() if binds_file.is_file() and binds_file.stat().st_size <= MAX_FILE else None,
    )


def load_bundle(path: Path) -> Bundle:
    return load_dir(path) if path.is_dir() else load_tar(path)


# --------------------------------------------------------------------------- building


def build_bundle(args: argparse.Namespace, name: str) -> Bundle:
    config = json.loads(Path(args.config).read_text())
    for section, key in PRIVATE:
        if isinstance(config.get(section), dict):
            config[section].pop(key, None)
    colors: dict = {}
    if args.colors and Path(args.colors).is_file():
        c = json.loads(Path(args.colors).read_text())
        colors = {k: c[k] for k in ("mode", "scheme", "colors", "seed", "contrast") if k in c}
    wallpaper = Path(args.wallpaper).expanduser() if args.wallpaper else None
    if wallpaper and not wallpaper.is_file():
        wallpaper = None
    profile = bool(args.profile)
    if not profile:
        # A plain preset is for sharing: it carries no code.
        for key in CODE_KEYS:
            config.pop(key, None)
        drop_scripts(config, quiet=True)
    widgets: dict[str, bytes] = {}
    binds: bytes | None = None
    if profile:
        wdir = Path(args.widgets_dir).expanduser() if args.widgets_dir else None
        if wdir and wdir.is_dir():
            for f in sorted(wdir.glob("*.qml"))[:MAX_WIDGETS]:
                if WIDGET_NAME.match(f.name) and f.stat().st_size <= MAX_FILE:
                    widgets[f.name] = f.read_bytes()
        bfile = Path(args.binds).expanduser() if args.binds else None
        if bfile and bfile.is_file() and bfile.stat().st_size <= MAX_FILE:
            binds = bfile.read_bytes()
    manifest = {
        "hiShellPreset": VERSION,
        "name": name,
        "created": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "profile": profile,
        "wallpaper": f"wallpaper{wallpaper.suffix.lower()}" if wallpaper else "",
        "wallpaperName": wallpaper.name if wallpaper else "",
    }
    return Bundle(manifest, config, colors, manifest["wallpaper"], wallpaper.read_bytes() if wallpaper else b"", widgets, binds)


def write_tar(bundle: Bundle, out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_suffix(".part")
    with tarfile.open(tmp, "w:gz") as tar:
        add_bytes(tar, "manifest.json", json.dumps(bundle.manifest, indent=2).encode())
        add_bytes(tar, "config.json", json.dumps(bundle.config, indent=4, ensure_ascii=False).encode())
        add_bytes(tar, "colors.json", json.dumps(bundle.colors, indent=2).encode())
        if bundle.wallpaper_data:
            add_bytes(tar, bundle.wallpaper_name, bundle.wallpaper_data)
        for name, data in sorted(bundle.widgets.items()):
            add_bytes(tar, f"widgets/{name}", data)
        if bundle.binds is not None:
            add_bytes(tar, "binds.lua", bundle.binds)
    tmp.replace(out)


def write_dir(bundle: Bundle, out: Path) -> None:
    """A folder that reads well in git: one JSON file per config section, sorted keys, fixed indentation."""
    if out.exists() and not out.is_dir():
        raise ValueError(f"{out} is not a folder")
    out.mkdir(parents=True, exist_ok=True)
    cdir = out / "config"
    if cdir.exists():
        shutil.rmtree(cdir)
    cdir.mkdir()
    root_values: dict = {}
    for key, value in sorted(bundle.config.items()):
        if isinstance(value, dict):
            (cdir / f"{dir_name_of(key)}.json").write_text(json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
        else:
            root_values[key] = value
    if root_values:
        (cdir / "_root.json").write_text(json.dumps(root_values, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
    (out / "manifest.json").write_text(json.dumps(bundle.manifest, indent=2, sort_keys=True) + "\n")
    (out / "colors.json").write_text(json.dumps(bundle.colors, indent=2, sort_keys=True) + "\n")
    for old in out.glob("wallpaper.*"):
        old.unlink()
    if bundle.wallpaper_data:
        (out / bundle.wallpaper_name).write_bytes(bundle.wallpaper_data)
    wdir = out / "widgets"
    if wdir.exists():
        shutil.rmtree(wdir)
    if bundle.widgets:
        wdir.mkdir()
        for name, data in bundle.widgets.items():
            (wdir / name).write_bytes(data)
    if (out / "binds.lua").exists():
        (out / "binds.lua").unlink()
    if bundle.binds is not None:
        (out / "binds.lua").write_bytes(bundle.binds)


# --------------------------------------------------------------------------- planning


def drop_scripts(config: dict, quiet: bool = False) -> None:
    """A preset is shared, so it must not bring commands with it: script widgets (bar.instances "script#...") run
    a shell command from their options, so they are left out (with their place in the bar lists), and so are the
    rules (they can run commands too). A script widget you made yourself stays."""
    if any(key in config for key in CODE_KEYS):
        had_rules = bool(config.get("rules"))
        for key in CODE_KEYS:
            config.pop(key, None)
        if had_rules and not quiet:
            print("presets: left out the preset's rules (they can run commands)", file=sys.stderr)
    bar = config.get("bar")
    if not isinstance(bar, dict):
        return
    instances = bar.get("instances")
    dropped: list[str] = []
    if isinstance(instances, dict):
        dropped = [k for k in instances if k.startswith("script#")]
        for k in dropped:
            del instances[k]
    lists = [bar.get(k) for k in ("left", "center", "right")]
    for entry in bar.get("extra", []) if isinstance(bar.get("extra"), list) else []:
        if isinstance(entry, dict):
            lists += [entry.get(k) for k in ("left", "center", "right")]
    for monitor in bar.get("monitors", {}).values() if isinstance(bar.get("monitors"), dict) else []:
        if isinstance(monitor, dict):
            lists += [monitor.get(k) for k in ("left", "center", "right")]
    for lst in lists:
        if isinstance(lst, list):
            lst[:] = [w for w in lst if not (isinstance(w, str) and w.startswith("script#"))]
    if dropped and not quiet:
        print(f"presets: left out {len(dropped)} script widget(s) from the preset (they run commands): {', '.join(dropped)}", file=sys.stderr)


def merge(base: dict, new: dict) -> dict:
    """new over base, recursing into objects (so keys the preset lacks keep their value)."""
    out = dict(base)
    for k, v in new.items():
        out[k] = merge(base[k], v) if isinstance(v, dict) and isinstance(base.get(k), dict) else v
    return out


def flatten(value: Any, prefix: str = "") -> dict[str, Any]:
    """Dotted path -> leaf. Lists and empty objects are leaves."""
    if isinstance(value, dict) and value:
        out: dict[str, Any] = {}
        for k, v in value.items():
            out.update(flatten(v, f"{prefix}.{k}" if prefix else k))
        return out
    return {prefix: value}


@dataclass(frozen=True)
class Change:
    path: str
    old: Any
    new: Any


def diff_configs(before: dict, after: dict) -> tuple[Change, ...]:
    a, b = flatten(before), flatten(after)
    changes = [Change(p, a.get(p), b[p]) for p in sorted(b) if a.get(p, object()) != b[p]]
    return tuple(changes)


def parse_only(text: str | None) -> frozenset[str] | None:
    if not text:
        return None
    return frozenset(p.strip() for p in text.split(",") if p.strip())


@dataclass(frozen=True)
class Plan:
    config: dict
    changes: tuple[Change, ...]
    colors: dict
    wallpaper: bool
    widgets: dict[str, bytes]
    binds: bytes | None
    skipped: tuple[str, ...]


def make_plan(bundle: Bundle, current: dict, only: frozenset[str] | None, trust: bool) -> Plan:
    """What applying `bundle` would do: the merged config and the other parts that come along."""
    incoming = copy.deepcopy(bundle.config)
    for section, key in PRIVATE:
        if isinstance(incoming.get(section), dict):
            incoming[section].pop(key, None)
    skipped: list[str] = []
    if not (trust and bundle.is_profile):
        if any(incoming.get(k) for k in CODE_KEYS):
            skipped.append("rules")
        dropped = [k for k in (incoming.get("bar", {}).get("instances", {}) if isinstance(incoming.get("bar"), dict) else {}) if str(k).startswith("script#")]
        if dropped:
            skipped.append("script widgets: " + ", ".join(dropped))
        drop_scripts(incoming, quiet=True)
        if bundle.widgets:
            skipped.append(f"{len(bundle.widgets)} widget file(s)")
        if bundle.binds is not None:
            skipped.append("keybinds")
    if only is not None:
        incoming = {k: v for k, v in incoming.items() if k in only}
    merged = merge(current, incoming)
    code = trust and bundle.is_profile
    return Plan(
        config=merged,
        changes=diff_configs(current, merged),
        colors=bundle.colors if only is None or "colors" in only else {},
        wallpaper=bool(bundle.wallpaper_data) and (only is None or "wallpaper" in only),
        widgets=bundle.widgets if code and (only is None or "widgets" in only) else {},
        binds=bundle.binds if code and (only is None or "keybinds" in only) else None,
        skipped=tuple(skipped),
    )


def format_value(v: Any) -> str:
    text = json.dumps(v, ensure_ascii=False)
    return text if len(text) <= 60 else text[:57] + "..."


def format_plan(plan: Plan, current_widgets: set[str], current_binds: bool) -> str:
    lines = [f"{c.path}: {format_value(c.old)} -> {format_value(c.new)}" for c in plan.changes]
    if plan.colors:
        lines.append(f"colors: {plan.colors.get('mode', '')} {plan.colors.get('scheme', '')}".rstrip())
    if plan.wallpaper:
        lines.append("wallpaper: set from the preset")
    for name in sorted(plan.widgets):
        lines.append(f"widgets/{name}: {'replaced' if name in current_widgets else 'new'}")
    if plan.binds is not None:
        lines.append(f"keybinds: {'replaced' if current_binds else 'new'}")
    for s in plan.skipped:
        lines.append(f"left out (they can run code): {s}")
    return "\n".join(lines)


# --------------------------------------------------------------------------- applying


def backup(args: argparse.Namespace) -> Path | None:
    """Copy what an import may overwrite to a new folder in --backup-dir; keep the last KEEP_BACKUPS."""
    if not getattr(args, "backup_dir", None):
        return None
    root = Path(args.backup_dir).expanduser()
    dest = root / time.strftime("%Y%m%d-%H%M%S")
    n = 1
    while dest.exists():
        dest = root / f"{time.strftime('%Y%m%d-%H%M%S')}-{n}"
        n += 1
    dest.mkdir(parents=True)
    config = Path(args.config)
    if config.is_file():
        shutil.copy2(config, dest / "config.json")
    binds = Path(args.binds).expanduser() if getattr(args, "binds", None) else None
    if binds and binds.is_file():
        shutil.copy2(binds, dest / "binds.lua")
    wdir = Path(args.widgets_dir).expanduser() if getattr(args, "widgets_dir", None) else None
    if wdir and wdir.is_dir():
        (dest / "widgets").mkdir()
        for f in wdir.glob("*.qml"):
            shutil.copy2(f, dest / "widgets" / f.name)
        (dest / "widgets.present").write_text("\n".join(sorted(f.name for f in wdir.glob("*.qml"))))
    old = sorted(p for p in root.iterdir() if p.is_dir())
    for p in old[:-KEEP_BACKUPS]:
        shutil.rmtree(p, ignore_errors=True)
    return dest


def write_atomic(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".part")
    tmp.write_bytes(data)
    tmp.replace(path)


def place_wallpaper(bundle: Bundle, args: argparse.Namespace) -> str:
    original = Path(bundle.manifest.get("wallpaperName") or bundle.wallpaper_name).name
    filename = f"{Path(original).stem}{Path(bundle.wallpaper_name).suffix.lower()}"
    for d in (Path(s).expanduser() for s in args.search):
        candidate = d / filename
        if candidate.is_file() and candidate.read_bytes() == bundle.wallpaper_data:
            return str(candidate)
    dest_dir = Path(args.wallpapers).expanduser()
    dest_dir.mkdir(parents=True, exist_ok=True)
    (dest_dir / filename).write_bytes(bundle.wallpaper_data)
    return str(dest_dir / filename)


def current_state(args: argparse.Namespace) -> tuple[dict, set[str], bool]:
    config_path = Path(args.config)
    current = load_json(config_path.read_bytes()) if config_path.is_file() else {}
    wdir = Path(args.widgets_dir).expanduser() if getattr(args, "widgets_dir", None) else None
    widgets = {f.name for f in wdir.glob("*.qml")} if wdir and wdir.is_dir() else set()
    binds = Path(args.binds).expanduser() if getattr(args, "binds", None) else None
    return current, widgets, bool(binds and binds.is_file())


# --------------------------------------------------------------------------- commands


def cmd_export(args: argparse.Namespace) -> int:
    out = Path(args.out).expanduser()
    bundle = build_bundle(args, out.name.removesuffix(".tar.gz"))
    write_tar(bundle, out)
    print(out)
    return 0


def cmd_dump(args: argparse.Namespace) -> int:
    out = Path(args.out).expanduser()
    try:
        write_dir(build_bundle(args, out.name), out)
    except ValueError as e:
        return fail(str(e))
    print(out)
    return 0


def run_import(args: argparse.Namespace, source: Path) -> int:
    try:
        bundle = load_bundle(source)
    except (ValueError, OSError) as e:
        return fail(str(e))
    current, widgets_now, binds_now = current_state(args)
    plan = make_plan(bundle, current, parse_only(args.only), bool(args.trust))
    if args.dry_run:
        print(format_plan(plan, widgets_now, binds_now))
        return 0
    for line in plan.skipped:
        print(f"presets: left out (it can run code): {line}", file=sys.stderr)
    backup(args)
    wall_out = place_wallpaper(bundle, args) if plan.wallpaper else ""
    if plan.widgets and getattr(args, "widgets_dir", None):
        wdir = Path(args.widgets_dir).expanduser()
        for name, data in plan.widgets.items():
            write_atomic(wdir / name, data)
    if plan.binds is not None and getattr(args, "binds", None):
        write_atomic(Path(args.binds).expanduser(), plan.binds)
    config_path = Path(args.config)
    write_atomic(config_path, json.dumps(plan.config, indent=4, ensure_ascii=False).encode())
    print(json.dumps({"wallpaper": wall_out, "mode": plan.colors.get("mode", ""), "changes": len(plan.changes)}))
    return 0


def cmd_import(args: argparse.Namespace) -> int:
    return run_import(args, Path(args.file).expanduser())


def cmd_restore(args: argparse.Namespace) -> int:
    return run_import(args, Path(args.dir).expanduser())


def cmd_diff(args: argparse.Namespace) -> int:
    try:
        bundle = load_bundle(Path(args.file).expanduser())
    except (ValueError, OSError) as e:
        return fail(str(e))
    current, widgets_now, binds_now = current_state(args)
    plan = make_plan(bundle, current, parse_only(args.only), bool(args.trust))
    text = format_plan(plan, widgets_now, binds_now)
    print(text if text else "No changes.")
    return 0


def cmd_undo(args: argparse.Namespace) -> int:
    root = Path(args.backup_dir).expanduser()
    done = sorted(p for p in root.iterdir() if p.is_dir()) if root.is_dir() else []
    if not done:
        return fail("no backup to go back to")
    last = done[-1]
    if (last / "config.json").is_file():
        write_atomic(Path(args.config), (last / "config.json").read_bytes())
    if getattr(args, "binds", None) and (last / "binds.lua").is_file():
        write_atomic(Path(args.binds).expanduser(), (last / "binds.lua").read_bytes())
    if getattr(args, "widgets_dir", None) and (last / "widgets.present").is_file():
        wdir = Path(args.widgets_dir).expanduser()
        present = set((last / "widgets.present").read_text().split("\n")) - {""}
        for f in wdir.glob("*.qml"):
            if f.name not in present:
                f.unlink()
        for name in present:
            if (last / "widgets" / name).is_file():
                write_atomic(wdir / name, (last / "widgets" / name).read_bytes())
    shutil.rmtree(last)
    print(json.dumps({"restored": last.name}))
    return 0


def cmd_list(args: argparse.Namespace) -> int:
    d = Path(args.dir).expanduser()
    if not d.is_dir():
        return 0
    for p in sorted(d.glob("*.tar.gz"), key=lambda p: p.stat().st_mtime, reverse=True):
        try:
            with tarfile.open(p, "r:gz") as tar:
                m = load_json(read_member(tar, "manifest.json"))
        except (OSError, tarfile.TarError):
            continue
        if m.get("hiShellPreset") != VERSION:
            continue
        print(json.dumps({"path": str(p), "name": p.name.removesuffix(".tar.gz"), "created": m.get("created", ""),
                          "wallpaper": m.get("wallpaperName", ""), "profile": bool(m.get("profile"))}), flush=True)
    return 0


def add_build_args(p: argparse.ArgumentParser) -> None:
    p.add_argument("--config", required=True)
    p.add_argument("--colors")
    p.add_argument("--wallpaper")
    p.add_argument("--profile", action="store_true")
    p.add_argument("--widgets-dir")
    p.add_argument("--binds")


def add_apply_args(p: argparse.ArgumentParser) -> None:
    p.add_argument("--config", required=True)
    p.add_argument("--only")
    p.add_argument("--trust", action="store_true")
    p.add_argument("--widgets-dir")
    p.add_argument("--binds")


def add_import_args(p: argparse.ArgumentParser) -> None:
    add_apply_args(p)
    p.add_argument("--wallpapers", required=True)
    p.add_argument("--search", nargs="*", default=[])
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--backup-dir")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("export")
    e.add_argument("out")
    add_build_args(e)
    d = sub.add_parser("dump")
    d.add_argument("out")
    add_build_args(d)
    i = sub.add_parser("import")
    i.add_argument("file")
    add_import_args(i)
    r = sub.add_parser("restore")
    r.add_argument("dir")
    add_import_args(r)
    df = sub.add_parser("diff")
    df.add_argument("file")
    add_apply_args(df)
    u = sub.add_parser("undo")
    u.add_argument("--config", required=True)
    u.add_argument("--backup-dir", required=True)
    u.add_argument("--widgets-dir")
    u.add_argument("--binds")
    ls = sub.add_parser("list")
    ls.add_argument("dir")
    args = ap.parse_args()
    handlers = {"export": cmd_export, "dump": cmd_dump, "import": cmd_import, "restore": cmd_restore, "diff": cmd_diff,
                "undo": cmd_undo, "list": cmd_list}
    return handlers[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
