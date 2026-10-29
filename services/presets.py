#!/usr/bin/env python3
"""Save and restore hi-shell presets: config + wallpaper + color scheme in one archive.

    presets.py export OUT.tar.gz --config CONFIG.json --colors COLORS.json --wallpaper FILE
    presets.py import IN.tar.gz --config CONFIG.json --wallpapers DIR [--search DIR...]
    presets.py list DIR

A preset is a gzipped tar with manifest.json, config.json, colors.json and
wallpaper.<ext>. Exports leave out API keys and this machine's monitor layout;
imports keep the current ones. The wallpaper goes to --wallpapers unless an identical
file already exists in a --search folder. `import` prints {"wallpaper": path, "mode": mode}.
`list` prints one JSON object per preset: {"path", "name", "created", "wallpaper"}.
"""

import argparse
import io
import json
import sys
import tarfile
import time
from pathlib import Path

VERSION = 1
# Config keys that belong to the machine or the person, not the look.
PRIVATE = [("wallpapers", "unsplashKey"), ("wallpapers", "wallhavenKey"), ("hyprland", "monitors"),
           ("weather", "latitude"), ("weather", "longitude"), ("weather", "city"),
           ("ai", "openrouterKey"), ("ai", "keys"), ("ai", "urls"), ("hyprland", "keepFiles"), ("hyprland", "autostart"), ("update", "channel")]
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".avif", ".jxl"}


def fail(msg: str) -> int:
    print(msg, file=sys.stderr)
    return 1


def add_bytes(tar: tarfile.TarFile, name: str, data: bytes) -> None:
    info = tarfile.TarInfo(name)
    info.size = len(data)
    info.mtime = int(time.time())
    tar.addfile(info, io.BytesIO(data))


def export(args) -> int:
    config = json.loads(Path(args.config).read_text())
    for section, key in PRIVATE:
        config.get(section, {}).pop(key, None)
    colors = {}
    if args.colors and Path(args.colors).is_file():
        c = json.loads(Path(args.colors).read_text())
        colors = {k: c[k] for k in ("mode", "scheme", "colors") if k in c}
    wallpaper = Path(args.wallpaper).expanduser() if args.wallpaper else None
    if wallpaper and not wallpaper.is_file():
        wallpaper = None

    out = Path(args.out).expanduser()
    out.parent.mkdir(parents=True, exist_ok=True)
    manifest = {
        "hiShellPreset": VERSION,
        "name": out.name.removesuffix(".tar.gz"),
        "created": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "wallpaper": f"wallpaper{wallpaper.suffix.lower()}" if wallpaper else "",
        "wallpaperName": wallpaper.name if wallpaper else "",
    }
    tmp = out.with_suffix(".part")
    with tarfile.open(tmp, "w:gz") as tar:
        add_bytes(tar, "manifest.json", json.dumps(manifest, indent=2).encode())
        add_bytes(tar, "config.json", json.dumps(config, indent=4, ensure_ascii=False).encode())
        add_bytes(tar, "colors.json", json.dumps(colors, indent=2).encode())
        if wallpaper:
            tar.add(wallpaper, arcname=manifest["wallpaper"])
    tmp.replace(out)
    print(out)
    return 0


def read_member(tar: tarfile.TarFile, name: str) -> bytes | None:
    try:
        m = tar.getmember(name)
    except KeyError:
        return None
    if not m.isfile():
        return None
    return tar.extractfile(m).read()


def merge(base: dict, new: dict) -> dict:
    """new over base, recursing into objects (so keys the preset lacks keep their value)."""
    out = dict(base)
    for k, v in new.items():
        out[k] = merge(base[k], v) if isinstance(v, dict) and isinstance(base.get(k), dict) else v
    return out


def import_(args) -> int:
    src = Path(args.file).expanduser()
    try:
        tar = tarfile.open(src, "r:gz")
    except (OSError, tarfile.TarError) as e:
        return fail(f"not a preset archive: {e}")
    with tar:
        manifest = json.loads(read_member(tar, "manifest.json") or b"{}")
        if manifest.get("hiShellPreset") != VERSION:
            return fail("not a hi-shell preset (manifest.json missing or wrong version)")
        preset_config = json.loads(read_member(tar, "config.json") or b"{}")
        colors = json.loads(read_member(tar, "colors.json") or b"{}")

        wall_out = ""
        name = manifest.get("wallpaper", "")
        # Only a flat file name with an image extension; never a path from the archive.
        if name and "/" not in name and Path(name).suffix.lower() in IMAGE_EXTS:
            data = read_member(tar, name)
            if data:
                original = Path(manifest.get("wallpaperName") or name).name
                filename = f"{Path(original).stem}{Path(name).suffix.lower()}"
                existing = [d / filename for d in map(lambda d: Path(d).expanduser(), args.search)
                            if (d / filename).is_file() and (d / filename).read_bytes() == data]
                if existing:
                    wall_out = str(existing[0])
                else:
                    dest_dir = Path(args.wallpapers).expanduser()
                    dest_dir.mkdir(parents=True, exist_ok=True)
                    (dest_dir / filename).write_bytes(data)
                    wall_out = str(dest_dir / filename)

    config_path = Path(args.config)
    current = json.loads(config_path.read_text()) if config_path.is_file() else {}
    for section, key in PRIVATE:
        preset_config.get(section, {}).pop(key, None)
    merged = merge(current, preset_config)
    tmp = config_path.with_suffix(".part")
    tmp.write_text(json.dumps(merged, indent=4, ensure_ascii=False))
    tmp.replace(config_path)

    print(json.dumps({"wallpaper": wall_out, "mode": colors.get("mode", "")}))
    return 0


def list_(args) -> int:
    d = Path(args.dir).expanduser()
    if not d.is_dir():
        return 0
    for p in sorted(d.glob("*.tar.gz"), key=lambda p: p.stat().st_mtime, reverse=True):
        try:
            with tarfile.open(p, "r:gz") as tar:
                m = json.loads(read_member(tar, "manifest.json") or b"{}")
        except (OSError, tarfile.TarError, json.JSONDecodeError):
            continue
        if m.get("hiShellPreset") != VERSION:
            continue
        print(json.dumps({"path": str(p), "name": p.name.removesuffix(".tar.gz"),
                          "created": m.get("created", ""), "wallpaper": m.get("wallpaperName", "")}), flush=True)
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("export")
    e.add_argument("out")
    e.add_argument("--config", required=True)
    e.add_argument("--colors")
    e.add_argument("--wallpaper")
    i = sub.add_parser("import")
    i.add_argument("file")
    i.add_argument("--config", required=True)
    i.add_argument("--wallpapers", required=True)
    i.add_argument("--search", nargs="*", default=[])
    l = sub.add_parser("list")
    l.add_argument("dir")
    args = ap.parse_args()
    return {"export": export, "import": import_, "list": list_}[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
