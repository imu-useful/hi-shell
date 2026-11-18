"""services/icon_themes.py: reading themes, the store's answers, safe unpacking, applying and removing."""
import importlib.util
import io
import os
import tarfile
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock

from helpers import ROOT

spec = importlib.util.spec_from_file_location("icon_themes", ROOT / "services" / "icon_themes.py")
it = importlib.util.module_from_spec(spec)
spec.loader.exec_module(it)

INDEX = """[Icon Theme]
Name=Demo Icons
Name[ru]=Демо
Inherits=hicolor
Directories=16x16/apps,scalable/apps,scalable/places,symbolic/apps

[16x16/apps]
Size=16
Type=Fixed

[scalable/apps]
Size=64
Type=Scalable

[scalable/places]
Size=64
Type=Scalable

[symbolic/apps]
Size=16
Type=Scalable
"""


def make_theme(base: Path, name: str, index: str = INDEX) -> Path:
    theme = base / name
    for d in ("16x16/apps", "scalable/apps", "scalable/places", "symbolic/apps"):
        (theme / d).mkdir(parents=True, exist_ok=True)
    (theme / "index.theme").write_text(index)
    (theme / "16x16/apps/firefox.png").write_bytes(b"png")
    (theme / "scalable/apps/firefox.svg").write_text("<svg/>")
    (theme / "symbolic/apps/kitty.svg").write_text("<svg/>")
    (theme / "scalable/places/folder.svg").write_text("<svg/>")
    return theme


class Sandbox(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="hi-icons-"))
        self.home = self.tmp / "home"
        self.system = self.tmp / "sys"
        (self.system / "icons").mkdir(parents=True)
        env = {"HOME": str(self.home), "XDG_DATA_HOME": "", "XDG_CONFIG_HOME": "", "XDG_STATE_HOME": "",
               "XDG_DATA_DIRS": str(self.system)}
        patcher = mock.patch.dict(os.environ, env)
        patcher.start()
        self.addCleanup(patcher.stop)
        # Never touch the real session (gsettings, D-Bus).
        quiet = mock.patch.object(it, "run_quiet")
        self.run_quiet = quiet.start()
        self.addCleanup(quiet.stop)
        self.icons = self.home / ".local/share/icons"
        self.icons.mkdir(parents=True)


class ReadingTest(Sandbox):
    def test_a_theme_is_listed_with_its_name_and_big_non_symbolic_samples(self):
        make_theme(self.icons, "Demo")
        got = it.installed()["themes"]
        self.assertEqual([t["id"] for t in got], ["Demo"])
        self.assertEqual(got[0]["name"], "Demo Icons")
        self.assertTrue(got[0]["removable"])
        names = [Path(s).relative_to(self.icons / "Demo").as_posix() for s in got[0]["samples"]]
        self.assertEqual(names, ["scalable/places/folder.svg", "scalable/apps/firefox.svg"])

    def test_cursor_and_hidden_themes_and_hicolor_are_left_out(self):
        (self.icons / "Cursor").mkdir()
        (self.icons / "Cursor/index.theme").write_text("[Icon Theme]\nName=Cursor\n")
        make_theme(self.icons, "Hidden", INDEX.replace("Inherits=hicolor", "Hidden=true"))
        make_theme(self.icons, "hicolor")
        self.assertEqual(it.installed()["themes"], [])

    def test_a_user_theme_hides_a_system_one_of_the_same_folder(self):
        make_theme(self.system / "icons", "Demo")
        make_theme(self.system / "icons", "Other")
        make_theme(self.icons, "Demo")
        got = {t["id"]: t["removable"] for t in it.installed()["themes"]}
        self.assertEqual(got, {"Demo": True, "Other": False})

    def test_the_current_theme_comes_from_kdeglobals(self):
        (self.home / ".config").mkdir()
        (self.home / ".config/kdeglobals").write_text("[General]\nX=1\n\n[Icons]\nTheme=Papirus\n")
        self.assertEqual(it.current_theme(), "Papirus")


class StoreTest(unittest.TestCase):
    ENTRY = {
        "id": 42, "name": "Demo", "personid": "me", "downloads": "1200", "score": 88, "typeid": 132,
        "changed": "2026-10-01T00:00:00+00:00", "smallpreviewpic1": "https://x/p.png", "detailpage": "https://store/p/42",
        "downloadlink1": "https://dl/1", "downloadname1": "Demo.tar.xz", "downloadsize1": "10", "downloadprice1": "0",
        "downloadlink2": "https://dl/2", "downloadname2": "README.md", "downloadsize2": "1",
        "downloadlink3": "https://dl/3", "downloadname3": "Paid.zip", "downloadprice3": "5",
        "downloadlink4": "", "downloadname4": "Empty.zip",
    }

    def test_an_entry_keeps_only_free_archives(self):
        item = it.item_of(self.ENTRY)
        self.assertEqual(item["id"], "42")
        self.assertEqual(item["downloads"], 1200)
        self.assertEqual(item["changed"], "2026-10-01")
        self.assertEqual([f["name"] for f in item["files"]], ["Demo.tar.xz"])
        self.assertEqual(item["files"][0]["size"], 10240)

    def test_the_search_url_asks_for_icon_themes(self):
        url = it.search_url("tela circle", "rating", 2)
        self.assertIn("categories=132", url)
        self.assertIn("sortmode=high", url)
        self.assertIn("page=2", url)
        self.assertIn("search=tela+circle", url)
        self.assertNotIn("search=", it.search_url("  ", "nope", 0))

    def test_picking_a_file(self):
        files = it.files_of(self.ENTRY)
        self.assertEqual(it.pick_file(files, None)["index"], 1)
        with self.assertRaises(it.Failure):
            it.pick_file(files, 2)
        with self.assertRaises(it.Failure):
            it.pick_file([], None)


class UnpackTest(Sandbox):
    def tar_of(self, members: dict[str, bytes], path: Path, links: dict[str, str] | None = None) -> Path:
        with tarfile.open(path, "w:gz") as t:
            for name, data in members.items():
                info = tarfile.TarInfo(name)
                info.size = len(data)
                t.addfile(info, io.BytesIO(data))
            for name, target in (links or {}).items():
                info = tarfile.TarInfo(name)
                info.type = tarfile.SYMTYPE
                info.linkname = target
                t.addfile(info)
        return path

    def test_themes_are_found_in_the_archive_and_placed_over_an_older_copy(self):
        archive = self.tar_of({"pack/A/index.theme": INDEX.encode(), "pack/A/scalable/apps/x.svg": b"<svg/>",
                               "pack/B/index.theme": INDEX.encode(), "pack/README": b"hi"}, self.tmp / "t.tar.gz")
        make_theme(self.icons, "A")
        (self.icons / "A/stale").write_text("old")
        work = self.tmp / "w"
        work.mkdir()
        names = [it.place(t, self.icons) for t in it.unpack_all(archive, work)]
        self.assertEqual(names, ["A", "B"])
        self.assertTrue((self.icons / "A/scalable/apps/x.svg").is_file())
        self.assertFalse((self.icons / "A/stale").exists())
        self.assertFalse((self.icons / ".A.old").exists())

    def test_variants_packed_as_archives_inside_the_archive_are_unpacked(self):
        inner = self.tar_of({"Dark/index.theme": INDEX.encode()}, self.tmp / "Dark.tar.gz")
        outer = self.tmp / "all.zip"
        with zipfile.ZipFile(outer, "w") as z:
            z.write(inner, "variants/Dark.tar.gz")
        work = self.tmp / "w"
        work.mkdir()
        self.assertEqual([t.name for t in it.unpack_all(outer, work)], ["Dark"])

    def test_paths_and_links_leaving_the_folder_are_refused(self):
        work = self.tmp / "w"
        work.mkdir()
        evil = self.tar_of({"../../evil": b"x"}, self.tmp / "evil.tar.gz")
        with self.assertRaises(it.Failure):
            it.extract(evil, work)
        link = self.tar_of({}, self.tmp / "link.tar.gz", {"out": "/etc"})
        with self.assertRaises(it.Failure):
            it.extract(link, work)
        zipped = self.tmp / "evil.zip"
        with zipfile.ZipFile(zipped, "w") as z:
            z.writestr("../evil", "x")
        with self.assertRaises(it.Failure):
            it.extract(zipped, work)
        self.assertFalse((self.tmp / "evil").exists())


class ApplyRemoveTest(Sandbox):
    def test_apply_writes_kde_gtk_and_keeps_the_rest_of_the_files(self):
        make_theme(self.icons, "Demo")
        cfg = self.home / ".config"
        (cfg / "gtk-3.0").mkdir(parents=True)
        (cfg / "gtk-3.0/settings.ini").write_text("[Settings]\ngtk-theme-name=Adw\ngtk-icon-theme-name=Old\n")
        (cfg / "kdeglobals").write_text("[General]\nColorScheme=X\n\n[Icons]\nTheme=Old\n\n[KDE]\nA=1\n")
        self.assertEqual(it.apply("Demo"), {"applied": "Demo"})
        self.assertEqual((cfg / "kdeglobals").read_text(), "[General]\nColorScheme=X\n\n[Icons]\nTheme=Demo\n\n[KDE]\nA=1\n")
        self.assertEqual((cfg / "gtk-3.0/settings.ini").read_text(), "[Settings]\ngtk-theme-name=Adw\ngtk-icon-theme-name=Demo\n")
        self.assertFalse((cfg / "gtk-4.0").exists())
        self.assertEqual(self.run_quiet.call_args_list[0].args[0][:3], ["gsettings", "set", "org.gnome.desktop.interface"])

    def test_a_missing_section_is_added(self):
        f = self.tmp / "a.ini"
        f.write_text("[General]\nX=1\n")
        it.set_ini_key(f, "Icons", "Theme", "Demo")
        self.assertEqual(f.read_text(), "[General]\nX=1\n\n[Icons]\nTheme=Demo\n")

    def test_apply_refuses_unknown_or_odd_names(self):
        for bad in ("Nope", "../Demo", ""):
            with self.assertRaises(it.Failure):
                it.apply(bad)

    def test_remove_only_user_themes_not_in_use(self):
        make_theme(self.icons, "Mine")
        make_theme(self.icons, "Used")
        make_theme(self.system / "icons", "System")
        (self.home / ".config").mkdir()
        (self.home / ".config/kdeglobals").write_text("[Icons]\nTheme=Used\n")
        self.assertEqual(it.remove("Mine"), {"removed": "Mine"})
        self.assertFalse((self.icons / "Mine").exists())
        for name in ("Used", "System", "../x"):
            with self.assertRaises(it.Failure):
                it.remove(name)
        self.assertTrue((self.system / "icons/System").is_dir())


if __name__ == "__main__":
    unittest.main()
