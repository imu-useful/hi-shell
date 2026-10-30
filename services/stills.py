#!/usr/bin/env python3
"""A still picture for a live (video) wallpaper: one frame of it, cached.

The palette (matugen), the lock screen and the thumbnails all need an image; a video has none.
Other files are answered with themselves.

Usage: stills.py [--cache DIR] FILE      prints the path of an image for FILE
"""

import argparse
import hashlib
import os
import subprocess
import sys
from pathlib import Path

VIDEO_EXTENSIONS = {".mp4", ".webm", ".mkv", ".mov", ".avi", ".m4v", ".ogv", ".flv", ".wmv", ".ts", ".mpg", ".mpeg"}
# Animated pictures Qt plays by itself (AnimatedImage); a frame of them is the picture's own first one.
ANIMATED_EXTENSIONS = {".gif", ".apng"}
DEFAULT_CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "hi-shell/thumbnails"
# A second in: the first frame of a clip is often black (a fade-in).
SEEK = "1"


def is_video(path: Path) -> bool:
    return path.suffix.lower() in VIDEO_EXTENSIONS


def is_live(path: Path) -> bool:
    return path.suffix.lower() in VIDEO_EXTENSIONS | ANIMATED_EXTENSIONS


def frame(video: Path, out: Path, scale_filter: str | None = None) -> bool:
    """Write one frame of `video` to `out` (a .jpg); False when ffmpeg can't."""
    part = out.with_name(out.stem + ".part.jpg")
    # Clips shorter than the seek have no frame there: try again from the start.
    for seek in (["-ss", SEEK], []):
        cmd = ["ffmpeg", "-v", "error", "-y", *seek, "-i", str(video), "-frames:v", "1", "-an", "-q:v", "2"]
        if scale_filter:
            cmd += ["-vf", scale_filter]
        try:
            ok = subprocess.run(cmd + [str(part)], capture_output=True, timeout=60, stdin=subprocess.DEVNULL).returncode == 0
        except (OSError, subprocess.SubprocessError):
            return False
        if ok and part.is_file() and part.stat().st_size > 0:
            part.replace(out)
            return True
    part.unlink(missing_ok=True)
    return False


def still_for(path: Path, cache: Path = DEFAULT_CACHE) -> Path | None:
    """An image for `path`: itself, or a cached frame when it's a video (None if that failed)."""
    if not is_video(path):
        return path
    try:
        st = path.stat()
    except OSError:
        return None
    key = hashlib.sha1(f"{path}:{st.st_mtime_ns}:{st.st_size}".encode()).hexdigest()[:20]
    out = cache / f"still-{key}.jpg"
    if out.is_file():
        return out
    cache.mkdir(parents=True, exist_ok=True)
    return out if frame(path, out) else None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    ap.add_argument("file", type=Path)
    args = ap.parse_args()
    result = still_for(args.file.expanduser().resolve(), args.cache)
    if result is None:
        print("stills: couldn't take a frame of", args.file, file=sys.stderr)
        return 1
    print(result)
    return 0


if __name__ == "__main__":
    sys.exit(main())
