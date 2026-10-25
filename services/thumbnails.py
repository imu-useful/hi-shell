#!/usr/bin/env python3
"""List wallpapers in folders and make cached thumbnails for them.

Prints one JSON object per image as soon as its thumbnail exists (cached ones
first), so the wallpaper grid fills in while new thumbnails are generated:

    {"path": "/abs/wall.png", "name": "wall", "thumb": "/cache/ab12.jpg"}

Usage: thumbnails.py --cache DIR FOLDER [FOLDER...]
"""

import argparse
import hashlib
import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif", ".avif", ".jxl"}
SIZE = "480x270"


def emit(path: Path, thumb: Path) -> None:
    print(json.dumps({"path": str(path), "name": path.stem, "thumb": str(thumb)}), flush=True)


def thumb_for(path: Path, cache: Path) -> Path:
    st = path.stat()
    key = hashlib.sha1(f"{path}:{st.st_mtime_ns}:{st.st_size}".encode()).hexdigest()[:20]
    return cache / f"{key}.jpg"


def make(path: Path, thumb: Path) -> bool:
    # [0]: first frame of animated images; ^ + extent: fill and center-crop.
    cmd = ["magick", f"{path}[0]", "-auto-orient", "-thumbnail", f"{SIZE}^", "-gravity", "center",
           "-extent", SIZE, "-quality", "82", str(thumb)]
    try:
        return subprocess.run(cmd, capture_output=True, timeout=60).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cache", type=Path, required=True)
    ap.add_argument("folders", nargs="+", type=Path)
    args = ap.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)

    images: list[Path] = []
    for folder in args.folders:
        folder = folder.expanduser()
        if not folder.is_dir():
            continue
        for root, dirs, files in os.walk(folder):
            dirs[:] = [d for d in dirs if not d.startswith(".")]
            images += [Path(root) / f for f in files if Path(f).suffix.lower() in EXTENSIONS]
    images.sort(key=lambda p: p.name.lower())

    missing = []
    for path in images:
        try:
            thumb = thumb_for(path, args.cache)
        except OSError:
            continue
        if thumb.is_file():
            emit(path, thumb)
        else:
            missing.append((path, thumb))

    with ThreadPoolExecutor(max_workers=min(6, os.cpu_count() or 2)) as pool:
        for (path, thumb), ok in zip(missing, pool.map(lambda pt: make(*pt), missing)):
            if ok:
                emit(path, thumb)
    return 0


if __name__ == "__main__":
    sys.exit(main())
