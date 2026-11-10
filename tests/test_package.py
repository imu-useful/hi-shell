"""hi-shell installed as a pacman package (packaging/aur): the files in a folder that isn't a git checkout,
marked by .package, where pacman does the updates and install.sh only sets up the user."""
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from helpers import ROOT

# What the PKGBUILD puts in /usr/share/hi-shell.
SHIPPED = ["common", "docs", "dots", "hypr", "modules", "services", "sh", "sounds", "tools", "translations", "wait-mode",
           "shell.qml", "run.sh", "install.sh", "update.sh", "uninstall.sh", "README.md", "KEYBINDS.md"]


class PackageTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp(prefix="hi-pkg-"))
        cls.pkg = cls.tmp / "usr" / "share" / "hi-shell"
        cls.pkg.mkdir(parents=True)
        for name in SHIPPED:
            src = ROOT / name
            if src.is_dir():
                shutil.copytree(src, cls.pkg / name, ignore=shutil.ignore_patterns("__pycache__"))
            else:
                shutil.copy2(src, cls.pkg / name)
        (cls.pkg / ".package").write_text("hi-shell 9.9.9-1\n")

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def setUp(self):
        self.home = Path(tempfile.mkdtemp(prefix="home-", dir=self.tmp))
        (self.home / ".config" / "hypr").mkdir(parents=True)
        (self.home / ".config" / "hypr" / "hyprland.lua").write_text('hl.exec_cmd("kitty")\n')
        # A qs that is installed but has no shell running.
        bin_dir = self.home / "bin"
        bin_dir.mkdir()
        (bin_dir / "qs").write_text("#!/bin/sh\nexit 1\n")
        (bin_dir / "qs").chmod(0o755)
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(("XDG_", "HYPRLAND"))}
        self.env.update(HOME=str(self.home), PATH=f"{bin_dir}:{os.environ['PATH']}")

    def run_pkg(self, *args):
        return subprocess.run([str(self.pkg / args[0]), *args[1:]], env=self.env, capture_output=True, text=True,
                              stdin=subprocess.DEVNULL, timeout=60)

    def test_version_comes_from_the_package_file(self):
        r = self.run_pkg("sh/hi-shell", "version")
        self.assertIn("hi-shell 9.9.9-1 (pacman package hi-shell)", r.stdout)

    def test_update_leaves_it_to_pacman(self):
        for args in ([], ["--check"]):
            r = self.run_pkg("update.sh", *args)
            self.assertEqual(r.returncode, 1)
            self.assertIn("installed with pacman", r.stdout)

    def test_channel_can_not_be_switched(self):
        r = self.run_pkg("sh/hi-shell", "channel", "git")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("pacman", r.stderr)

    def test_the_packages_step_is_not_offered(self):
        r = self.run_pkg("install.sh", "--list")
        self.assertNotIn("deps", r.stdout.split())
        self.assertIn("hypr", r.stdout)

    def test_install_sets_up_the_user_and_uninstall_takes_it_back(self):
        r = self.run_pkg("install.sh", "--yes", "--no-start", "--no-dots")
        self.assertEqual(r.returncode, 0, r.stderr)
        link = self.home / ".config" / "quickshell" / "hi-shell"
        self.assertEqual(link.resolve(), self.pkg.resolve())
        # No links of its own in ~/.local/bin: hi is in /usr/bin.
        self.assertFalse((self.home / ".local" / "bin" / "hi").exists())
        hypr = self.home / ".config" / "hypr"
        self.assertIn("hypr/hi-shell/init.lua", (hypr / "hyprland.lua").read_text())
        # The keybinds call fallback.sh from there, so it's copied with the Lua files.
        self.assertTrue((hypr / "hi-shell" / "fallback.sh").is_file())

        r = self.run_pkg("uninstall.sh")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(link.is_symlink())
        self.assertNotIn("hi-shell", (hypr / "hyprland.lua").read_text())
        self.assertFalse((hypr / "hi-shell").exists())
        self.assertIn("sudo pacman -R hi-shell", r.stdout)


if __name__ == "__main__":
    unittest.main()
