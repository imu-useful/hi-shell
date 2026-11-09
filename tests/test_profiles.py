import io
import json
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path

from helpers import ROOT

SCRIPT = ROOT / "services" / "presets.py"
CONFIG = {
    "bar": {"height": 36, "left": ["launcher", "script#cpu"], "instances": {"script#cpu": {"command": "id"}, "zoneClock#t": {"zone": "Asia/Tokyo"}}},
    "dock": {"enabled": True, "iconSize": 50},
    "appearance": {"cornerScale": 0.5},
    "rules": [{"id": "r", "when": {"dark": True}, "then": [{"run": "id"}]}],
    "rulesEnabled": True,
    "weather": {"city": "Berlin", "imperial": True},
    "language": "ru",
}
WIDGET = b"import QtQuick\nItem {}\n"


def run(*args):
    return subprocess.run([sys.executable, str(SCRIPT), *map(str, args)], capture_output=True, text=True)


class ProfileTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.d = Path(self.tmp.name)
        (self.d / "config.json").write_text(json.dumps(CONFIG))
        (self.d / "colors.json").write_text(json.dumps({"mode": "dark", "scheme": "tonal-spot", "colors": {"primary": "#fff"}, "wallpaper": "/x"}))
        (self.d / "wid").mkdir()
        (self.d / "wid" / "hello.qml").write_bytes(WIDGET)
        (self.d / "binds.lua").write_text("-- my binds\n")
        # the machine that imports: another config, no widgets, no binds
        self.target = self.d / "target"
        self.target.mkdir()
        (self.target / "config.json").write_text(json.dumps({"bar": {"height": 40, "left": ["clock"]}, "dock": {"enabled": False, "iconSize": 44}, "weather": {"city": "Paris"}}))
        (self.target / "wid").mkdir()

    def export(self, name, *extra):
        out = self.d / name
        r = run("export", out, "--config", self.d / "config.json", "--colors", self.d / "colors.json", *extra)
        self.assertEqual(r.returncode, 0, r.stderr)
        return out

    def import_(self, path, *extra):
        return run("import", path, "--config", self.target / "config.json", "--wallpapers", self.d / "walls",
                   "--widgets-dir", self.target / "wid", "--binds", self.target / "binds.lua", "--backup-dir", self.target / "backups", *extra)

    def target_config(self):
        return json.loads((self.target / "config.json").read_text())

    def members(self, path):
        with tarfile.open(path, "r:gz") as t:
            return t.getnames()

    # --- export

    def test_a_plain_preset_carries_no_code_and_no_private_values(self):
        out = self.export("p.tar.gz", "--widgets-dir", self.d / "wid", "--binds", self.d / "binds.lua")
        self.assertEqual(sorted(self.members(out)), ["colors.json", "config.json", "manifest.json"])
        with tarfile.open(out, "r:gz") as t:
            cfg = json.load(t.extractfile("config.json"))
        self.assertNotIn("rules", cfg)
        self.assertNotIn("script#cpu", json.dumps(cfg))
        self.assertNotIn("city", cfg["weather"])
        self.assertEqual(cfg["bar"]["left"], ["launcher"])

    def test_a_profile_carries_rules_scripts_widgets_and_keybinds(self):
        out = self.export("prof.tar.gz", "--profile", "--widgets-dir", self.d / "wid", "--binds", self.d / "binds.lua")
        self.assertIn("widgets/hello.qml", self.members(out))
        self.assertIn("binds.lua", self.members(out))
        with tarfile.open(out, "r:gz") as t:
            cfg = json.load(t.extractfile("config.json"))
        self.assertIn("rules", cfg)
        self.assertIn("script#cpu", cfg["bar"]["instances"])

    # --- import

    def test_importing_a_profile_without_trust_leaves_the_code_out(self):
        out = self.export("prof.tar.gz", "--profile", "--widgets-dir", self.d / "wid", "--binds", self.d / "binds.lua")
        r = self.import_(out)
        self.assertEqual(r.returncode, 0, r.stderr)
        cfg = self.target_config()
        self.assertNotIn("rules", cfg)
        self.assertNotIn("script#cpu", json.dumps(cfg))
        self.assertFalse((self.target / "wid" / "hello.qml").exists())
        self.assertFalse((self.target / "binds.lua").exists())
        self.assertEqual(cfg["bar"]["height"], 36)
        self.assertEqual(cfg["weather"]["city"], "Paris")  # this machine's value stays
        self.assertIn("rules", r.stderr)

    def test_importing_a_profile_with_trust_brings_everything(self):
        out = self.export("prof.tar.gz", "--profile", "--widgets-dir", self.d / "wid", "--binds", self.d / "binds.lua")
        r = self.import_(out, "--trust")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual((self.target / "wid" / "hello.qml").read_bytes(), WIDGET)
        self.assertEqual((self.target / "binds.lua").read_text(), "-- my binds\n")
        cfg = self.target_config()
        self.assertEqual(cfg["rules"][0]["id"], "r")
        self.assertIn("script#cpu", cfg["bar"]["instances"])

    def test_trust_does_not_open_a_plain_preset(self):
        plain = self.export("p.tar.gz")
        self.import_(plain, "--trust")
        self.assertNotIn("rules", self.target_config())

    def test_only_limits_the_parts(self):
        out = self.export("p.tar.gz")
        self.import_(out, "--only", "bar")
        cfg = self.target_config()
        self.assertEqual(cfg["bar"]["height"], 36)
        self.assertEqual(cfg["dock"], {"enabled": False, "iconSize": 44})
        self.assertNotIn("appearance", cfg)

    def test_only_colors_changes_no_config(self):
        out = self.export("p.tar.gz")
        r = self.import_(out, "--only", "colors")
        self.assertEqual(json.loads(r.stdout)["mode"], "dark")
        self.assertEqual(json.loads(r.stdout)["changes"], 0)
        self.assertEqual(self.target_config()["bar"]["height"], 40)

    # --- diff and dry run

    def test_diff_lists_the_changes_and_writes_nothing(self):
        out = self.export("p.tar.gz")
        before = (self.target / "config.json").read_text()
        r = run("diff", out, "--config", self.target / "config.json", "--widgets-dir", self.target / "wid")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("bar.height: 40 -> 36", r.stdout)
        self.assertIn("dock.iconSize: 44 -> 50", r.stdout)
        self.assertNotIn("weather.city", r.stdout)
        self.assertEqual((self.target / "config.json").read_text(), before)

    def test_diff_says_what_is_left_out(self):
        prof = self.export("prof.tar.gz", "--profile", "--widgets-dir", self.d / "wid", "--binds", self.d / "binds.lua")
        r = run("diff", prof, "--config", self.target / "config.json")
        self.assertIn("left out", r.stdout)
        self.assertIn("rules", r.stdout)
        trusted = run("diff", prof, "--config", self.target / "config.json", "--trust", "--widgets-dir", self.target / "wid")
        self.assertIn("widgets/hello.qml: new", trusted.stdout)
        self.assertIn("keybinds: new", trusted.stdout)
        self.assertNotIn("left out", trusted.stdout)

    def test_dry_run_changes_nothing(self):
        out = self.export("p.tar.gz")
        before = (self.target / "config.json").read_text()
        r = self.import_(out, "--dry-run")
        self.assertIn("bar.height", r.stdout)
        self.assertEqual((self.target / "config.json").read_text(), before)
        self.assertFalse((self.target / "backups").exists())

    # --- backup and undo

    def test_an_import_is_backed_up_and_can_be_undone(self):
        (self.target / "wid" / "mine.qml").write_bytes(b"mine")
        (self.target / "binds.lua").write_text("-- old binds\n")
        original = (self.target / "config.json").read_text()
        out = self.export("prof.tar.gz", "--profile", "--widgets-dir", self.d / "wid", "--binds", self.d / "binds.lua")
        self.import_(out, "--trust")
        self.assertNotEqual((self.target / "config.json").read_text(), original)
        r = run("undo", "--config", self.target / "config.json", "--backup-dir", self.target / "backups",
                "--widgets-dir", self.target / "wid", "--binds", self.target / "binds.lua")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual((self.target / "config.json").read_text(), original)
        self.assertEqual((self.target / "binds.lua").read_text(), "-- old binds\n")
        self.assertEqual(sorted(p.name for p in (self.target / "wid").glob("*.qml")), ["mine.qml"])

    def test_undo_without_a_backup_fails(self):
        r = run("undo", "--config", self.target / "config.json", "--backup-dir", self.target / "nothing")
        self.assertNotEqual(r.returncode, 0)

    # --- folders for git

    def test_a_folder_round_trips_and_is_readable(self):
        folder = self.d / "dots"
        r = run("dump", folder, "--config", self.d / "config.json", "--colors", self.d / "colors.json", "--profile",
                "--widgets-dir", self.d / "wid", "--binds", self.d / "binds.lua")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((folder / "config" / "bar.json").is_file())
        self.assertTrue((folder / "config" / "_root.json").is_file())
        self.assertEqual(json.loads((folder / "config" / "dock.json").read_text())["iconSize"], 50)
        self.assertTrue((folder / "widgets" / "hello.qml").is_file())
        # the same dump twice gives the same bytes (git shows only real changes)
        first = (folder / "config" / "bar.json").read_text()
        run("dump", folder, "--config", self.d / "config.json", "--colors", self.d / "colors.json", "--profile")
        self.assertEqual((folder / "config" / "bar.json").read_text(), first)
        r = run("restore", folder, "--config", self.target / "config.json", "--wallpapers", self.d / "walls", "--trust",
                "--widgets-dir", self.target / "wid")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.target_config()["dock"]["iconSize"], 50)

    # --- hostile archives

    def hostile(self, members):
        path = self.d / "evil.tar.gz"
        with tarfile.open(path, "w:gz") as t:
            for name, data in members.items():
                info = tarfile.TarInfo(name)
                info.size = len(data)
                t.addfile(info, io.BytesIO(data))
        return path

    def test_widget_names_from_an_archive_are_checked(self):
        members = {"manifest.json": json.dumps({"hiShellPreset": 1, "profile": True}).encode(), "config.json": b"{}", "colors.json": b"{}",
                   "widgets/ok.qml": WIDGET, "widgets/../../evil.qml": b"x", "widgets/a b.qml": b"x", "widgets/sub/x.qml": b"x", "widgets/.hidden.qml": b"x"}
        r = self.import_(self.hostile(members), "--trust")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(sorted(p.name for p in (self.target / "wid").glob("*.qml")), ["ok.qml"])
        self.assertFalse((self.d / "evil.qml").exists())

    def test_a_wallpaper_name_with_a_path_is_ignored(self):
        members = {"manifest.json": json.dumps({"hiShellPreset": 1, "wallpaper": "../x.png", "wallpaperName": "x.png"}).encode(),
                   "config.json": b"{}", "colors.json": b"{}", "../x.png": b"png"}
        r = self.import_(self.hostile(members))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(json.loads(r.stdout)["wallpaper"], "")

    def test_a_file_that_is_not_a_preset_is_refused(self):
        bad = self.d / "bad.tar.gz"
        bad.write_bytes(b"nope")
        r = self.import_(bad)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("not a preset", r.stderr)

    def test_list_marks_profiles(self):
        self.export("a.tar.gz")
        self.export("b.tar.gz", "--profile")
        r = run("list", self.d)
        rows = {json.loads(l)["name"]: json.loads(l)["profile"] for l in r.stdout.splitlines()}
        self.assertEqual(rows, {"a": False, "b": True})


if __name__ == "__main__":
    unittest.main()
