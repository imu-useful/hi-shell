"""services/cursor_themes.py: Xcursor previews, finding cursor themes, applying and removing."""
import importlib.util
import os
import struct
import sys
import tempfile
import unittest
import zlib
from pathlib import Path
from unittest import mock

from helpers import ROOT

sys.path.insert(0, str(ROOT / "services"))
spec = importlib.util.spec_from_file_location("cursor_themes", ROOT / "services" / "cursor_themes.py")
ct = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ct)
core = ct.core


def xcursor(*sizes: int) -> bytes:
    """An Xcursor file with one square image per size; each pixel is half-transparent red (premultiplied)."""
    header = 16
    toc_len = 12 * len(sizes)
    toc, images = b"", b""
    pos = header + toc_len
    for s in sizes:
        pixel = bytes((0, 0, 128, 128))  # B G R A, premultiplied
        image = struct.pack("<IIIIIIIII", 36, ct.XCURSOR_IMAGE, s, 1, s, s, 0, 0, 0) + pixel * (s * s)
        toc += struct.pack("<III", ct.XCURSOR_IMAGE, s, pos)
        images += image
        pos += len(image)
    return b"Xcur" + struct.pack("<III", header, 0x10000, len(sizes)) + toc + images


def make_cursor_theme(base: Path, name: str, title: str = "") -> Path:
    theme = base / name
    (theme / "cursors").mkdir(parents=True)
    (theme / "cursors/left_ptr").write_bytes(xcursor(24, 32, 48))
    (theme / "cursors/hand2").write_bytes(xcursor(32))
    if title:
        (theme / "index.theme").write_text(f"[Icon Theme]\nName={title}\n")
    return theme


class XcursorTest(unittest.TestCase):
    def test_the_size_nearest_32_is_picked(self):
        w, h, pixels = ct.xcursor_image(xcursor(24, 48, 32))
        self.assertEqual((w, h, len(pixels)), (32, 32, 32 * 32 * 4))
        # A tie goes to the bigger one.
        self.assertEqual(ct.xcursor_image(xcursor(24, 40))[0], 40)

    def test_bad_files_give_nothing(self):
        self.assertIsNone(ct.xcursor_image(b"nope"))
        self.assertIsNone(ct.xcursor_image(xcursor(32)[:60]))
        self.assertIsNone(ct.xcursor_image(b"Xcur" + struct.pack("<III", 16, 1, 0)))

    def test_the_png_has_straight_alpha(self):
        png = ct.png_of(1, 1, bytes((0, 0, 128, 128)))
        self.assertTrue(png.startswith(b"\x89PNG"))
        idat = png.index(b"IDAT")
        size = struct.unpack(">I", png[idat - 4:idat])[0]
        raw = zlib.decompress(png[idat + 4:idat + 4 + size])
        self.assertEqual(raw, bytes((0, 255, 0, 0, 128)))


class Sandbox(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="hi-cursors-"))
        self.home = self.tmp / "home"
        self.system = self.tmp / "sys"
        (self.system / "icons").mkdir(parents=True)
        env = {"HOME": str(self.home), "XDG_DATA_HOME": "", "XDG_CONFIG_HOME": "", "XDG_STATE_HOME": "",
               "XDG_CACHE_HOME": "", "XDG_DATA_DIRS": str(self.system)}
        for p in (mock.patch.dict(os.environ, env), mock.patch.object(ct, "current_theme", return_value="")):
            p.start()
            self.addCleanup(p.stop)
        quiet = mock.patch.object(core, "run_quiet")
        self.run_quiet = quiet.start()
        self.addCleanup(quiet.stop)
        self.icons = self.home / ".local/share/icons"
        self.icons.mkdir(parents=True)


class ThemesTest(Sandbox):
    def test_cursor_themes_are_listed_with_previews_and_icon_themes_are_not(self):
        make_cursor_theme(self.icons, "Mine", "My Cursors")
        make_cursor_theme(self.system / "icons", "Sys")
        (self.icons / "Icons").mkdir()
        (self.icons / "Icons/index.theme").write_text("[Icon Theme]\nName=Icons\nDirectories=a\n")
        make_cursor_theme(self.icons, "default")
        got = ct.installed()["themes"]
        self.assertEqual([(t["id"], t["name"], t["removable"]) for t in got], [("Mine", "My Cursors", True), ("Sys", "Sys", False)])
        self.assertEqual([Path(s).name for s in got[0]["samples"]], ["left_ptr.png", "hand2.png"])
        self.assertTrue(all(Path(s).read_bytes().startswith(b"\x89PNG") for s in got[0]["samples"]))

    def test_themes_in_an_archive_are_the_folders_holding_cursors(self):
        root = self.tmp / "x"
        make_cursor_theme(root / "pack", "A")
        make_cursor_theme(root / "pack", "B")
        (root / "pack/Hypr").mkdir()
        (root / "pack/Hypr/manifest.hl").write_text("name = Hypr\n")
        self.assertEqual([t.name for t in ct.find_themes(root)], ["A", "B", "Hypr"])

    def test_apply_writes_gtk_kde_and_the_default_theme_and_tells_hyprland(self):
        make_cursor_theme(self.icons, "Mine")
        cfg = self.home / ".config"
        (cfg / "gtk-3.0").mkdir(parents=True)
        (cfg / "gtk-3.0/settings.ini").write_text("[Settings]\ngtk-cursor-theme-name=Old\n")
        self.assertEqual(ct.apply("Mine", 32), {"applied": "Mine", "size": 32})
        self.assertEqual((cfg / "gtk-3.0/settings.ini").read_text(),
                         "[Settings]\ngtk-cursor-theme-name=Mine\ngtk-cursor-theme-size=32\n")
        self.assertEqual((cfg / "kcminputrc").read_text(), "[Mouse]\ncursorTheme=Mine\ncursorSize=32\n")
        self.assertEqual((self.home / ".icons/default/index.theme").read_text(), "[Icon Theme]\nInherits=Mine\n")
        self.assertIn(mock.call(["hyprctl", "setcursor", "Mine", "32"]), self.run_quiet.call_args_list)

    def test_apply_refuses_unknown_themes_and_odd_sizes(self):
        make_cursor_theme(self.icons, "Mine")
        for theme, size in (("Nope", 24), ("../Mine", 24), ("Mine", 4), ("Mine", 500)):
            with self.assertRaises(ct.Failure):
                ct.apply(theme, size)

    def test_remove_only_user_themes_not_in_use(self):
        make_cursor_theme(self.icons, "Mine")
        make_cursor_theme(self.system / "icons", "Sys")
        self.assertEqual(ct.remove("Mine"), {"removed": "Mine"})
        self.assertFalse((self.icons / "Mine").exists())
        with self.assertRaises(ct.Failure):
            ct.remove("Sys")
        make_cursor_theme(self.icons, "Used")
        with mock.patch.object(ct, "current_theme", return_value="Used"), self.assertRaises(ct.Failure):
            ct.remove("Used")


class StoreTest(unittest.TestCase):
    def test_windows_builds_are_not_offered(self):
        entry = {"downloadlink1": "https://a", "downloadname1": "Bibata-Windows.zip",
                 "downloadlink2": "https://b", "downloadname2": "Bibata.tar.xz"}
        self.assertEqual([f["name"] for f in core.item_of(entry)["files"]], ["Bibata.tar.xz"])

    def test_the_search_asks_for_cursors(self):
        self.assertIn("categories=107", core.search_url("", "popular", 0, ct.CATEGORY))


if __name__ == "__main__":
    unittest.main()
