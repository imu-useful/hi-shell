#!/usr/bin/env python3
"""Icon themes for Settings > Themes and Store: the installed ones, the KDE Store's, installing, applying, removing.

    icon_themes.py installed                      -> {"current": ..., "themes": [{id, name, path, removable, samples}]}
    icon_themes.py search [--query Q] [--sort S] [--page N]
                                                  -> {"total": N, "items": [{id, name, author, downloads, score, ...}]}
    icon_themes.py install PRODUCT [--file N]     -> lines {"progress": 0..1}, then {"installed": [theme ids]}
    icon_themes.py apply THEME                    -> {"applied": THEME}
    icon_themes.py remove THEME                   -> {"removed": THEME}

Errors are {"error": "..."} on stdout with exit code 1. The store is store.kde.org's OCS API
(category 132, Full Icon Themes); installed themes go to ~/.local/share/icons. The store, download
and unpacking parts are shared with cursor_themes.py (category 107, Cursors).
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

API = "https://api.kde-look.org/ocs/v1/content/data"
CATEGORY = 132
PAGE_SIZE = 24
SORTS = {"popular": "down", "new": "new", "rating": "high", "name": "alpha"}
MAX_DOWNLOAD = 600 * 1024 * 1024
TIMEOUT = 30
ARCHIVES = (".tar.gz", ".tgz", ".tar.xz", ".txz", ".tar.bz2", ".tbz2", ".tar.zst", ".tar", ".zip")
NOT_THEMES = {"hicolor", "locolor", "default"}
# One picture per slot, the first name the theme has.
SAMPLES = [
    ["folder", "inode-directory"],
    ["system-file-manager", "org.gnome.Nautilus", "org.kde.dolphin"],
    ["utilities-terminal", "org.gnome.Terminal", "kitty", "org.kde.konsole", "konsole"],
    ["firefox", "web-browser", "internet-web-browser", "chromium"],
    ["preferences-system", "systemsettings", "org.gnome.Settings"],
    ["accessories-text-editor", "org.gnome.TextEditor", "org.kde.kate", "kate"],
]
USER_AGENT = "hi-shell-icon-store"


class Failure(Exception):
    pass


def home() -> Path:
    return Path(os.environ.get("HOME") or Path.home())


def data_home() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME") or home() / ".local" / "share")


def config_home() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME") or home() / ".config")


def user_icon_dir() -> Path:
    return data_home() / "icons"


def user_dirs() -> list[Path]:
    return [user_icon_dir(), home() / ".icons"]


def search_dirs() -> list[Path]:
    system = [Path(d) / "icons" for d in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":") if d]
    return user_dirs() + system


def valid_theme_id(name: str) -> bool:
    return bool(name) and name not in (".", "..") and "/" not in name and "\0" not in name


# --- index.theme ---------------------------------------------------------------------------------

def parse_ini(text: str) -> dict[str, dict[str, str]]:
    """Sections of a desktop-entry style file; the first value of a key wins, localized keys are skipped."""
    out: dict[str, dict[str, str]] = {}
    section = None
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = out.setdefault(line[1:-1].strip(), {})
            continue
        if section is None or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if "[" not in key:
            section.setdefault(key, value.strip())
    return out


def read_index(theme_dir: Path) -> dict[str, dict[str, str]] | None:
    try:
        return parse_ini((theme_dir / "index.theme").read_text(errors="replace"))
    except OSError:
        return None


def theme_dirs(index: dict[str, dict[str, str]]) -> list[str]:
    head = index.get("Icon Theme", {})
    names = [d.strip() for key in ("Directories", "ScaledDirectories") for d in head.get(key, "").split(",")]
    return list(dict.fromkeys(d for d in names if d))


def is_icon_theme(index: dict[str, dict[str, str]] | None) -> bool:
    """An index.theme of icons (not a cursor theme, not hidden)."""
    if not index or "Icon Theme" not in index:
        return False
    if index["Icon Theme"].get("Hidden", "").lower() == "true":
        return False
    return bool(theme_dirs(index))


def dir_rank(name: str, section: dict[str, str]) -> int:
    """Bigger first: scalable, then by size; symbolic icons last."""
    if "symbolic" in name:
        return -1
    if section.get("Type", "").lower() == "scalable" or "scalable" in name:
        return 10000
    try:
        size = int(section.get("Size", "0")) * int(section.get("Scale", "1"))
    except ValueError:
        size = 0
    return size if size >= 32 else size - 1000


def samples(theme_dir: Path, index: dict[str, dict[str, str]]) -> list[str]:
    dirs = sorted(theme_dirs(index), key=lambda d: dir_rank(d, index.get(d, {})), reverse=True)
    dirs = [d for d in dirs if "symbolic" not in d and (theme_dir / d).is_dir()]
    found = []
    for names in SAMPLES:
        hit = next((str(theme_dir / d / f"{n}{ext}") for n in names for d in dirs for ext in (".svg", ".png")
                    if (theme_dir / d / f"{n}{ext}").is_file()), None)
        if hit:
            found.append(hit)
    return found


# --- installed -----------------------------------------------------------------------------------

def current_theme() -> str:
    try:
        kde = parse_ini((config_home() / "kdeglobals").read_text(errors="replace"))
        theme = kde.get("Icons", {}).get("Theme", "")
        if theme:
            return theme
    except OSError:
        pass
    try:
        out = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"],
                             capture_output=True, text=True, timeout=5)
        return out.stdout.strip().strip("'") if out.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
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
            if path.name in seen or path.name in NOT_THEMES or not path.is_dir():
                continue
            index = read_index(path)
            if not is_icon_theme(index):
                continue
            seen[path.name] = {
                "id": path.name,
                "name": index["Icon Theme"].get("Name") or path.name,
                "path": str(path),
                "removable": base.resolve() in users,
                "samples": samples(path, index),
            }
    themes = sorted(seen.values(), key=lambda t: t["name"].lower())
    return {"current": current_theme(), "themes": themes}


# --- the store -----------------------------------------------------------------------------------

def fetch_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            data = json.loads(resp.read().decode("utf-8", "replace"))
    except (OSError, ValueError) as e:
        raise Failure(f"store unreachable: {e}") from e
    if data.get("status") != "ok":
        raise Failure(data.get("message") or "the store answered with an error")
    return data


def search_url(query: str, sort: str, page: int, category: int = CATEGORY) -> str:
    params = {"categories": category, "format": "json", "sortmode": SORTS.get(sort, "down"),
              "pagesize": PAGE_SIZE, "page": max(0, page)}
    if query.strip():
        params["search"] = query.strip()
    return f"{API}?{urllib.parse.urlencode(params)}"


def files_of(entry: dict) -> list[dict]:
    """The free downloadable files of a store entry: {index, name, size (bytes), version}."""
    out = []
    for key, link in entry.items():
        m = re.fullmatch(r"downloadlink(\d+)", key)
        if not m or not link:
            continue
        n = m.group(1)
        try:
            price = float(entry.get(f"downloadprice{n}") or 0)
        except ValueError:
            price = 0
        if price > 0:
            continue
        try:
            size = int(float(entry.get(f"downloadsize{n}") or 0) * 1024)
        except ValueError:
            size = 0
        out.append({"index": int(n), "name": entry.get(f"downloadname{n}") or "", "size": size,
                    "version": entry.get(f"download_version{n}") or ""})
    return sorted(out, key=lambda f: f["index"])


def item_of(entry: dict) -> dict:
    try:
        downloads = int(entry.get("downloads") or 0)
    except ValueError:
        downloads = 0
    try:
        score = int(entry.get("score") or 0)
    except ValueError:
        score = 0
    return {
        "id": str(entry.get("id", "")),
        "name": entry.get("name") or "",
        "author": entry.get("personid") or "",
        "summary": (entry.get("summary") or "").strip(),
        "downloads": downloads,
        "score": score,
        "changed": (entry.get("changed") or "")[:10],
        "preview": entry.get("smallpreviewpic1") or entry.get("previewpic1") or "",
        "page": entry.get("detailpage") or "",
        "files": [f for f in files_of(entry) if is_archive(f["name"])],
    }


def search(query: str, sort: str, page: int, category: int = CATEGORY) -> dict:
    data = fetch_json(search_url(query, sort, page, category))
    items = [item_of(e) for e in data.get("data") or [] if isinstance(e, dict)]
    return {"total": int(data.get("totalitems") or 0), "page": page, "items": items}


def is_archive(name: str) -> bool:
    """An archive we can unpack, and not a Windows build of the theme (.cur / .ico files)."""
    low = name.lower()
    return low.endswith(ARCHIVES) and "windows" not in low


# --- installing ----------------------------------------------------------------------------------

def emit(obj: dict) -> None:
    print(json.dumps(obj), flush=True)


def download(url: str, target: Path, report: bool = True) -> None:
    """Save url to target; report: progress lines on stdout as it comes."""
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp, open(target, "wb") as out:
            total = int(resp.headers.get("Content-Length") or 0)
            got = 0
            last = -1.0
            while chunk := resp.read(256 * 1024):
                got += len(chunk)
                if got > MAX_DOWNLOAD:
                    raise Failure("the download is too big")
                out.write(chunk)
                frac = got / total if total else -1
                if report and (frac < 0 or frac - last >= 0.02):
                    emit({"progress": round(frac, 3), "bytes": got})
                    last = frac
    except OSError as e:
        raise Failure(f"download failed: {e}") from e


def inside(base: Path, member: str) -> bool:
    target = (base / member).resolve()
    return target == base or base in target.parents


def extract(archive: Path, dest: Path) -> None:
    """Unpack into dest; members that would land outside it (or links pointing out) are refused."""
    dest = dest.resolve()
    name = archive.name.lower()
    try:
        if name.endswith(".zip"):
            with zipfile.ZipFile(archive) as z:
                bad = [m for m in z.namelist() if not inside(dest, m)]
                if bad:
                    raise Failure(f"unsafe path in the archive: {bad[0]}")
                z.extractall(dest)
            return
        if name.endswith(".tar.zst"):
            # Python's tarfile has no zstd before 3.14 everywhere: unpack to a plain tar first.
            plain = archive.with_name(archive.name[:-4])
            subprocess.run(["zstd", "-dqf", str(archive), "-o", str(plain)], check=True, capture_output=True, timeout=600)
            archive = plain
        with tarfile.open(archive) as t:
            t.extractall(dest, filter="data")
    except (tarfile.TarError, zipfile.BadZipFile, OSError, subprocess.SubprocessError) as e:
        raise Failure(f"couldn't unpack {archive.name}: {e}") from e


def find_themes(root: Path) -> list[Path]:
    """Directories under root holding an icon theme, outermost only."""
    found = []
    for index in sorted(root.rglob("index.theme")):
        theme = index.parent
        if any(f in theme.parents for f in found):
            continue
        if is_icon_theme(read_index(theme)):
            found.append(theme)
    return found


def unpack_all(archive: Path, work: Path, finder=find_themes) -> list[Path]:
    """Themes in the archive; archives inside it (one per variant, say) are unpacked when it has none."""
    out = work / "x"
    out.mkdir()
    extract(archive, out)
    themes = finder(out)
    if themes:
        return themes
    for i, inner in enumerate(p for p in sorted(out.rglob("*")) if p.is_file() and is_archive(p.name)):
        sub = work / f"inner{i}"
        sub.mkdir()
        extract(inner, sub)
        themes += finder(sub)
    return themes


def place(theme: Path, icons: Path) -> str:
    """Move a theme into icons (~/.local/share/icons, say) under its folder name, over an older copy."""
    name = theme.name
    if not valid_theme_id(name) or name in NOT_THEMES:
        raise Failure(f"bad theme folder name: {name}")
    target = icons / name
    old = icons / f".{name}.old"
    if target.exists() or target.is_symlink():
        if old.exists():
            shutil.rmtree(old, ignore_errors=True)
        target.rename(old)
    shutil.move(str(theme), str(target))
    shutil.rmtree(old, ignore_errors=True)
    return name


def pick_file(files: list[dict], index: int | None) -> dict:
    archives = [f for f in files if is_archive(f["name"])]
    if index is not None:
        hit = next((f for f in archives if f["index"] == index), None)
        if not hit:
            raise Failure("that file isn't a free archive of this theme")
        return hit
    if not archives:
        raise Failure("this theme has no archive to download (it may need its own installer)")
    return archives[0]


def record(product: str, themes: list[str], state_file: str = "icon-store.json") -> None:
    """Remember which theme folders came from which store entry (Settings shows Apply for them)."""
    state = Path(os.environ.get("XDG_STATE_HOME") or home() / ".local" / "state") / "hi-shell" / state_file
    try:
        data = json.loads(state.read_text())
    except (OSError, ValueError):
        data = {}
    data = {**data, product: sorted(set(data.get(product, [])) | set(themes))}
    state.parent.mkdir(parents=True, exist_ok=True)
    state.write_text(json.dumps(data, indent=1))


def install(product: str, file_index: int | None, category: int = CATEGORY, finder=find_themes,
            state_file: str = "icon-store.json", what: str = "icon theme", target: Path | None = None) -> dict:
    """Download a store entry's archive and move the themes in it to target (~/.local/share/icons)."""
    if not product.isdigit():
        raise Failure("not a store id")
    data = fetch_json(f"{API}/{product}?format=json")
    entries = data.get("data") or []
    if not entries:
        raise Failure("no such theme in the store")
    entry = entries[0]
    if str(entry.get("typeid")) != str(category):
        raise Failure(f"that isn't an {what}" if what[0] in "aeiou" else f"that isn't a {what}")
    chosen = pick_file(files_of(entry), file_index)
    link = entry.get(f"downloadlink{chosen['index']}") or ""
    if not link.startswith("https://"):
        raise Failure("the store gave no download link")
    icons = target or user_icon_dir()
    icons.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".hi-icon-store-", dir=icons) as tmp:
        work = Path(tmp)
        archive = work / Path(chosen["name"]).name
        download(link, archive)
        emit({"progress": 1, "status": "unpacking"})
        themes = unpack_all(archive, work, finder)
        if not themes:
            raise Failure(f"no {what} in the archive (it may need its own installer)")
        names = [place(t, icons) for t in themes]
    record(product, names, state_file)
    return {"installed": names, "product": product}


# --- applying and removing -----------------------------------------------------------------------

def set_ini_key(path: Path, section: str, key: str, value: str) -> None:
    """Set key=value in [section] of an ini file, keeping the rest of it as it is."""
    try:
        lines = path.read_text().splitlines()
    except OSError:
        lines = []
    out, cur, done = [], None, False
    for line in lines:
        s = line.strip()
        if s.startswith("[") and s.endswith("]"):
            if cur == section and not done:
                out.append(f"{key}={value}")
                done = True
            cur = s[1:-1]
        elif cur == section and not done and s.split("=", 1)[0].strip() == key:
            out.append(f"{key}={value}")
            done = True
            continue
        out.append(line)
    if not done:
        if cur != section:
            if out and out[-1].strip():
                out.append("")
            out.append(f"[{section}]")
        out.append(f"{key}={value}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(out) + "\n")


def run_quiet(cmd: list[str]) -> None:
    if shutil.which(cmd[0]):
        try:
            subprocess.run(cmd, capture_output=True, timeout=10)
        except (OSError, subprocess.SubprocessError):
            pass


def apply(theme: str) -> dict:
    if not valid_theme_id(theme) or not any(is_icon_theme(read_index(d / theme)) for d in search_dirs()):
        raise Failure(f"no icon theme named {theme}")
    cfg = config_home()
    set_ini_key(cfg / "kdeglobals", "Icons", "Theme", theme)
    for gtk in ("gtk-3.0", "gtk-4.0"):
        if (cfg / gtk / "settings.ini").is_file():
            set_ini_key(cfg / gtk / "settings.ini", "Settings", "gtk-icon-theme-name", theme)
    for qt in ("qt5ct", "qt6ct"):
        if (cfg / qt / f"{qt}.conf").is_file():
            set_ini_key(cfg / qt / f"{qt}.conf", "Appearance", "icon_theme", theme)
    run_quiet(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", theme])
    run_quiet(["dbus-send", "--session", "--type=signal", "/KIconLoader", "org.kde.KIconLoader.iconChanged", "int32:0"])
    return {"applied": theme}


def remove(theme: str) -> dict:
    if not valid_theme_id(theme):
        raise Failure("bad theme name")
    if theme == current_theme():
        raise Failure("that theme is in use: apply another one first")
    for base in user_dirs():
        target = base / theme
        if target.is_dir() and not target.is_symlink() and is_icon_theme(read_index(target)):
            shutil.rmtree(target)
            return {"removed": theme}
    raise Failure("only themes in ~/.local/share/icons or ~/.icons can be removed")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("installed")
    s = sub.add_parser("search")
    s.add_argument("--query", default="")
    s.add_argument("--sort", default="popular", choices=sorted(SORTS))
    s.add_argument("--page", type=int, default=0)
    i = sub.add_parser("install")
    i.add_argument("product")
    i.add_argument("--file", type=int)
    sub.add_parser("apply").add_argument("theme")
    sub.add_parser("remove").add_argument("theme")
    args = ap.parse_args(argv)
    try:
        if args.cmd == "installed":
            emit(installed())
        elif args.cmd == "search":
            emit(search(args.query, args.sort, args.page))
        elif args.cmd == "install":
            emit(install(args.product, args.file))
        elif args.cmd == "apply":
            emit(apply(args.theme))
        else:
            emit(remove(args.theme))
    except Failure as e:
        emit({"error": str(e)})
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
