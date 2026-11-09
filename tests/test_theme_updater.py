import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from helpers import ROOT

SCRIPT = ROOT / "services" / "theme_updater.py"
HAS_MATUGEN = shutil.which("matugen") is not None


def run(*args):
    return subprocess.run([sys.executable, str(SCRIPT), *args], capture_output=True, text=True)


class ThemeUpdaterTest(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.dir, True)
        self.out = self.dir / "colors.json"

    def test_a_bad_seed_is_refused(self):
        for bad in ("red", "#12345", "--help", "#gggggg"):
            r = run("--output", str(self.out), "--seed", bad)
            self.assertNotEqual(r.returncode, 0, bad)
            self.assertFalse(self.out.exists())

    @unittest.skipUnless(HAS_MATUGEN, "matugen isn't installed")
    def test_a_seed_palette_needs_no_wallpaper(self):
        r = run("--output", str(self.out), "--seed", "#336699", "--wallpaper", "/nonexistent", "--force")
        self.assertEqual(r.returncode, 0, r.stderr)
        data = json.loads(self.out.read_text())
        self.assertEqual(data["seed"], "#336699")
        self.assertEqual(data["wallpaper"], "")
        self.assertIn("primary", data["colors"])

    @unittest.skipUnless(HAS_MATUGEN, "matugen isn't installed")
    def test_seed_and_contrast_change_the_palette(self):
        run("--output", str(self.out), "--seed", "#336699", "--wallpaper", "/x", "--force")
        a = json.loads(self.out.read_text())["colors"]
        run("--output", str(self.out), "--seed", "#336699", "--contrast", "1", "--wallpaper", "/x", "--force")
        b = json.loads(self.out.read_text())
        self.assertEqual(b["contrast"], 1.0)
        self.assertNotEqual(a, b["colors"])

    def test_without_a_seed_a_missing_wallpaper_is_an_error(self):
        r = run("--output", str(self.out), "--seed", "", "--wallpaper", "/nonexistent")
        self.assertEqual(r.returncode, 1)


if __name__ == "__main__":
    unittest.main()
