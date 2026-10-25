#!/usr/bin/env python3
"""Generate hi-shell's Material 3 palette from the wallpaper with matugen.

Writes a JSON file that common/Colors.qml watches and reloads live:

    {"wallpaper": "...", "mtime": 0.0, "mode": "dark", "colors": {"primary": "#aac7ff", ...}}

Usage:
    theme_updater.py [--wallpaper PATH] [--mode dark|light] [--scheme NAME] [--output FILE] [--force]

Without --wallpaper the current wallpaper is detected (hi-shell's own state
file, illogical-impulse, hyprpaper, swww). Without --mode / --scheme the
previously used ones are kept. Schemes are matugen's: tonal-spot (default),
content, expressive, fidelity, fruit-salad, monochrome, neutral, rainbow, vibrant.
Only matugen's JSON output is used (--dry-run), so no other matugen templates
or system themes are touched.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

STATE_HOME = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
DEFAULT_OUTPUT = STATE_HOME / "hi-shell/colors.json"
HI_WALLPAPER_FILE = STATE_HOME / "hi-shell/wallpaper.txt"
II_WALLPAPER_FILE = STATE_HOME / "quickshell/user/generated/wallpaper/path.txt"
SCHEMES = ["tonal-spot", "content", "expressive", "fidelity", "fruit-salad", "monochrome", "neutral", "rainbow", "vibrant"]


def log(msg: str) -> None:
    print(f"theme_updater: {msg}", file=sys.stderr)


def run(cmd: list[str]) -> str:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=10, stdin=subprocess.DEVNULL).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def detect_wallpaper() -> Path | None:
    candidates: list[str] = []

    if HI_WALLPAPER_FILE.is_file():
        candidates.append(HI_WALLPAPER_FILE.read_text().strip())

    if II_WALLPAPER_FILE.is_file():
        candidates.append(II_WALLPAPER_FILE.read_text().strip())

    if shutil.which("hyprctl"):
        # "eDP-1 = /path/to/wall.png"
        for line in run(["hyprctl", "hyprpaper", "listactive"]).splitlines():
            if " = " in line:
                candidates.append(line.split(" = ", 1)[1].strip())

    if shutil.which("swww"):
        # "eDP-1: 1920x1080, scale: 1, currently displaying: image: /path/to/wall.png"
        for line in run(["swww", "query"]).splitlines():
            if "image: " in line:
                candidates.append(line.rsplit("image: ", 1)[1].strip())

    for c in candidates:
        p = Path(c).expanduser()
        if p.is_file():
            return p
    return None


def load_previous(output: Path) -> dict:
    try:
        return json.loads(output.read_text())
    except (OSError, ValueError):
        return {}


def generate(wallpaper: Path, mode: str, scheme: str) -> dict[str, str]:
    out = subprocess.run(
        ["matugen", "image", str(wallpaper), "--json", "hex", "--dry-run", "--quiet",
         "--prefer", "saturation", "--mode", mode, "--type", f"scheme-{scheme}"],
        capture_output=True, text=True, timeout=60, stdin=subprocess.DEVNULL,
    )
    if out.returncode != 0:
        raise RuntimeError(out.stderr.strip() or f"matugen exited with {out.returncode}")
    data = json.loads(out.stdout)
    return {name: variants[mode]["color"] for name, variants in data["colors"].items()}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--wallpaper", type=Path, help="image to generate colors from (default: detect)")
    ap.add_argument("--mode", choices=["dark", "light"], help="color scheme mode (default: keep previous, else dark)")
    ap.add_argument("--scheme", choices=SCHEMES, help="matugen scheme type (default: keep previous, else tonal-spot)")
    ap.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help=f"output JSON (default: {DEFAULT_OUTPUT})")
    ap.add_argument("--force", action="store_true", help="regenerate even if nothing changed")
    args = ap.parse_args()

    if not shutil.which("matugen"):
        log("matugen not found in PATH")
        return 1

    previous = load_previous(args.output)
    mode = args.mode or previous.get("mode", "dark")
    scheme = args.scheme or previous.get("scheme", "tonal-spot")

    wallpaper = args.wallpaper.expanduser() if args.wallpaper else detect_wallpaper()
    if wallpaper is None:
        log("could not detect the current wallpaper; pass --wallpaper PATH")
        return 1
    if not wallpaper.is_file():
        log(f"wallpaper not found: {wallpaper}")
        return 1
    wallpaper = wallpaper.resolve()
    mtime = wallpaper.stat().st_mtime

    unchanged = (previous.get("wallpaper") == str(wallpaper) and previous.get("mtime") == mtime
                 and previous.get("mode") == mode and previous.get("scheme", "tonal-spot") == scheme
                 and previous.get("colors"))
    if unchanged and not args.force:
        log(f"up to date ({wallpaper.name}, {mode}, {scheme})")
        return 0

    try:
        colors = generate(wallpaper, mode, scheme)
    except (OSError, RuntimeError, ValueError, KeyError, subprocess.SubprocessError) as e:
        log(f"matugen failed: {e}")
        return 1

    # Written in place with a single write (not tmp + rename): Quickshell's file
    # watcher follows the inode, so a rename would silently detach it.
    args.output.parent.mkdir(parents=True, exist_ok=True)
    # Atomic: the shell watches this file and would otherwise read it half-written.
    tmp = args.output.with_suffix(".tmp")
    tmp.write_text(json.dumps({"wallpaper": str(wallpaper), "mtime": mtime, "mode": mode, "scheme": scheme, "colors": colors}, indent=2))
    tmp.replace(args.output)
    log(f"generated {mode} {scheme} palette from {wallpaper.name} -> {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
