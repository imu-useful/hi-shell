"""services/gtk_themes.py and font_store.py: finding GTK themes and their colors, applying; the font catalog and installs."""
import importlib.util
import json
import os
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

from helpers import ROOT

sys.path.insert(0, str(ROOT / "services"))


def load(name: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / "services" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


gtk = load("gtk_themes")
fonts = load("font_store")
core = gtk.core


def make_gtk_theme(base: Path, name: str, css: str = "@define-color theme_bg_color #112233;\n") -> Path:
    theme = base / name
    (theme / "gtk-3.0").mkdir(parents=True)
    (theme / "gtk-3.0/gtk.css").write_text(css)
    return theme


class Sandbox(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="hi-gtk-"))
        self.home = self.tmp / "home"
        self.system = self.tmp / "sys"
        (self.system / "themes").mkdir(parents=True)
        env = {"HOME": str(self.home), "XDG_DATA_HOME": "", "XDG_CONFIG_HOME": "", "XDG_STATE_HOME": "",
               "XDG_CACHE_HOME": "", "XDG_DATA_DIRS": str(self.system)}
        for p in (mock.patch.dict(os.environ, env), mock.patch.object(gtk, "current_theme", return_value="")):
            p.start()
            self.addCleanup(p.stop)
        quiet = mock.patch.object(core, "run_quiet")
        self.run_quiet = quiet.start()
        self.addCleanup(quiet.stop)
        self.themes = self.home / ".local/share/themes"
        self.themes.mkdir(parents=True)


class GtkTest(Sandbox):
    def test_colors_are_read_through_references_imports_and_rgb(self):
        make_gtk_theme(self.themes, "T", '@import url("colors.css");\n@define-color theme_fg_color rgba(255, 0, 16, 0.5);\n'
                                         "@define-color theme_selected_bg_color @accent;\n")
        (self.themes / "T/gtk-3.0/colors.css").write_text("@define-color theme_bg_color #fafafa;\n@define-color accent #3584e4;\n")
        self.assertEqual(gtk.colors_of(self.themes / "T"), ["#fafafa", "#ff0010", "#3584e4"])

    def test_an_import_outside_the_theme_is_not_read(self):
        (self.tmp / "evil.css").write_text("@define-color theme_bg_color #000000;\n")
        make_gtk_theme(self.themes, "T", f'@import url("../../../evil.css");\n')
        self.assertEqual(gtk.colors_of(self.themes / "T"), [])

    def test_installed_lists_user_and_system_themes(self):
        make_gtk_theme(self.themes, "Mine")
        make_gtk_theme(self.system / "themes", "Sys")
        (self.system / "themes/Default/gtk-3.0").mkdir(parents=True)
        (self.system / "themes/Default/gtk-3.0/gtk-keys.css").write_text("")
        got = {t["id"]: (t["removable"], t["colors"]) for t in gtk.installed()["themes"]}
        self.assertEqual(got, {"Mine": (True, ["#112233"]), "Sys": (False, ["#112233"])})

    def test_themes_in_an_archive(self):
        root = self.tmp / "x"
        make_gtk_theme(root / "pack", "A")
        (root / "pack/B/gtk-4.0").mkdir(parents=True)
        (root / "pack/B/gtk-4.0/gtk.css").write_text("")
        (root / "pack/A/gnome-shell").mkdir()
        self.assertEqual([t.name for t in gtk.find_themes(root)], ["A", "B"])

    def test_apply_writes_gtk_settings_and_gsettings(self):
        make_gtk_theme(self.themes, "Mine")
        self.assertEqual(gtk.apply("Mine"), {"applied": "Mine"})
        cfg = self.home / ".config"
        self.assertEqual((cfg / "gtk-3.0/settings.ini").read_text(), "[Settings]\ngtk-theme-name=Mine\n")
        self.assertFalse((cfg / "gtk-4.0").exists())
        self.assertIn(mock.call(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", "Mine"]), self.run_quiet.call_args_list)
        with self.assertRaises(gtk.Failure):
            gtk.apply("../Mine")


CATALOG = [
    {"id": "inter", "family": "Inter", "category": "sans-serif", "popularity": 4, "lastModified": "2025-09-10",
     "variants": ["300", "regular", "700", "italic"], "subsets": ["latin", "cyrillic"]},
    {"id": "roboto-mono", "family": "Roboto Mono", "category": "monospace", "popularity": 2, "lastModified": "2026-01-01",
     "variants": ["300", "500"], "subsets": ["latin"]},
    {"id": "abel", "family": "Abel", "category": "sans-serif", "popularity": 90, "lastModified": "2024-01-01",
     "variants": ["regular"], "subsets": ["latin"]},
]


class FontTest(Sandbox):
    def setUp(self):
        super().setUp()
        cache = fonts.cache_file()
        cache.parent.mkdir(parents=True)
        cache.write_text(json.dumps(CATALOG))

    def test_search_filters_sorts_and_pages(self):
        self.assertEqual([i["id"] for i in fonts.search("", "popular", 0, "")["items"]], ["roboto-mono", "inter", "abel"])
        self.assertEqual([i["id"] for i in fonts.search("", "new", 0, "")["items"]], ["roboto-mono", "inter", "abel"])
        self.assertEqual([i["id"] for i in fonts.search("", "name", 0, "sans-serif")["items"]], ["abel", "inter"])
        self.assertEqual(fonts.search("rob mono", "popular", 0, "")["total"], 1)
        self.assertEqual(fonts.search("", "popular", 1, "")["items"], [])

    def test_the_preview_is_the_regular_weight_or_the_nearest(self):
        items = {i["id"]: i["preview"] for i in fonts.search("", "name", 0, "")["items"]}
        self.assertTrue(items["inter"].endswith("/inter@latest/latin-400-normal.ttf"))
        self.assertTrue(items["roboto-mono"].endswith("latin-300-normal.ttf"))

    def test_a_stale_catalog_is_refetched_and_kept_when_offline(self):
        old = time.time() - fonts.CATALOG_TTL - 10
        os.utime(fonts.cache_file(), (old, old))
        with mock.patch.object(core.urllib.request, "urlopen", side_effect=OSError("offline")):
            self.assertEqual(len(fonts.catalog()), 3)

    def test_install_saves_every_style_and_remove_takes_it_away(self):
        detail = {"variants": [{"id": "regular", "ttf": "https://fonts.gstatic.com/s/inter/a.ttf"},
                               {"id": "700", "ttf": "https://fonts.gstatic.com/s/inter/b.ttf"},
                               {"id": "evil", "ttf": "https://elsewhere.example/c.ttf"}]}
        got = []

        def fake_download(url, target, report=True):
            got.append(url)
            Path(target).write_bytes(b"ttf")

        with mock.patch.object(fonts, "fetch_plain", return_value=detail), mock.patch.object(core, "download", fake_download):
            self.assertEqual(fonts.install("inter")["family"], "Inter")
        self.assertEqual(len(got), 2)
        listed = fonts.installed()["themes"]
        self.assertEqual([(t["id"], t["name"]) for t in listed], [("inter", "Inter")])
        self.assertTrue(listed[0]["regular"].endswith("inter-regular.ttf"))
        self.assertEqual(fonts.remove("inter"), {"removed": "inter"})
        self.assertEqual(fonts.installed()["themes"], [])

    def test_bad_ids_are_refused(self):
        for bad in ("../x", "Inter", ""):
            with self.assertRaises(fonts.Failure):
                fonts.install(bad)
            with self.assertRaises(fonts.Failure):
                fonts.remove(bad)


if __name__ == "__main__":
    unittest.main()
