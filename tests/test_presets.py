import io
import json
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path

from helpers import ROOT

sys.path.insert(0, str(ROOT / "services"))
import presets  # noqa: E402


def make_preset(directory: Path, config: dict) -> Path:
    path = directory / "p.tar.gz"
    with tarfile.open(path, "w:gz") as tar:
        for name, value in (("manifest.json", {"hiShellPreset": presets.VERSION}), ("config.json", config), ("colors.json", {})):
            data = json.dumps(value).encode()
            info = tarfile.TarInfo(name)
            info.size = len(data)
            tar.addfile(info, io.BytesIO(data))
    return path


class DropScriptsTest(unittest.TestCase):
    def test_script_instances_and_their_list_entries_are_removed(self):
        cfg = {"bar": {"left": ["launcher", "script#a"], "center": ["clock"], "right": ["script#b", "tray"],
                       "instances": {"script#a": {"command": "id"}, "script#b": {"command": "id"}, "zoneClock#t": {"zone": "Asia/Tokyo"}},
                       "extra": [{"id": "x", "center": ["script#a", "media"]}],
                       "monitors": {"eDP-1": {"left": ["script#a"]}}}}
        presets.drop_scripts(cfg)
        bar = cfg["bar"]
        self.assertEqual(bar["left"], ["launcher"])
        self.assertEqual(bar["right"], ["tray"])
        self.assertEqual(list(bar["instances"]), ["zoneClock#t"])
        self.assertEqual(bar["extra"][0]["center"], ["media"])
        self.assertEqual(bar["monitors"]["eDP-1"]["left"], [])

    def test_config_without_a_bar_is_left_alone(self):
        cfg = {"dock": {"enabled": True}}
        presets.drop_scripts(cfg)
        self.assertEqual(cfg, {"dock": {"enabled": True}})

    def test_odd_shapes_do_not_crash(self):
        for cfg in ({"bar": []}, {"bar": {"instances": []}}, {"bar": {"extra": "x", "monitors": 3}}):
            presets.drop_scripts(cfg)


class ImportTest(unittest.TestCase):
    def test_importing_a_preset_never_brings_a_command(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            preset = make_preset(d, {"bar": {"left": ["launcher", "script#evil"], "instances": {"script#evil": {"command": "id"}}}})
            (d / "c.json").write_text("{}")
            r = subprocess.run([sys.executable, str(ROOT / "services" / "presets.py"), "import", str(preset), "--config", str(d / "c.json"), "--wallpapers", str(d / "w")],
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            merged = json.loads((d / "c.json").read_text())
            self.assertEqual(merged["bar"]["left"], ["launcher"])
            self.assertNotIn("script#evil", json.dumps(merged))
            self.assertIn("script#evil", r.stderr)


if __name__ == "__main__":
    unittest.main()
