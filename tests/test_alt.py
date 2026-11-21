"""ALT Linux: install.sh installs the packages with apt-get (Sisyphus names), the icon font from GitHub and the
optional apps with apt-get or epm play; the installer window says apt-get and how to turn sudo on.

rpm, apt-get, sudo, epm, curl and fc-list are fakes on PATH that log what they were called with."""
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from helpers import ROOT

sys.path.insert(0, str(ROOT / "installer"))
import logic  # noqa: E402

INSTALL = ROOT / "install.sh"

FAKES = {
    # rpm -q --quiet <name>: installed when listed in FAKE_RPM_INSTALLED ("all": everything);
    # rpm -q --qf '%{VERSION}' hyprland: FAKE_HYPRLAND, not installed without it.
    "rpm": """#!/bin/sh
echo "rpm $*" >> "$FAKE_LOG"
if [ "$2" = --qf ]; then [ -n "$FAKE_HYPRLAND" ] || exit 1; printf %s "$FAKE_HYPRLAND"; exit 0; fi
name=$3
[ "$FAKE_RPM_INSTALLED" = all ] && exit 0
case " $FAKE_RPM_INSTALLED " in *" $name "*) exit 0 ;; esac
exit 1
""",
    "apt-get": '#!/bin/sh\necho "apt-get $*" >> "$FAKE_LOG"\nexit "${FAKE_APT_EXIT:-0}"\n',
    "sudo": '#!/bin/sh\nexec "$@"\n',
    "epm": '#!/bin/sh\necho "epm $*" >> "$FAKE_LOG"\n',
    "pacman": '#!/bin/sh\necho "pacman $*" >> "$FAKE_LOG"\nexit 1\n',
    "fc-list": "#!/bin/sh\nexit 1\n",
    "fc-cache": "#!/bin/sh\nexit 0\n",
    # curl -fL --retry 2 -o <file> <url>
    "curl": """#!/bin/sh
echo "curl $*" >> "$FAKE_LOG"
while [ $# -gt 0 ]; do [ "$1" = -o ] && { echo font > "$2"; }; shift; done
""",
    # Installed, no shell running.
    "qs": "#!/bin/sh\nexit 1\n",
}


class AltInstallTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="hi-alt-"))
        self.home = self.tmp / "home"
        (self.home / ".config" / "hypr").mkdir(parents=True)
        self.bin = self.tmp / "bin"
        self.bin.mkdir()
        for name, text in FAKES.items():
            (self.bin / name).write_text(text)
            (self.bin / name).chmod(0o755)
        self.log = self.tmp / "calls.log"
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(("XDG_", "HYPRLAND", "FAKE_"))}
        self.env.update(HOME=str(self.home), PATH=f"{self.bin}:{os.environ['PATH']}", HI_SHELL_DISTRO="alt",
                        FAKE_LOG=str(self.log), FAKE_HYPRLAND="0.56.2")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def install(self, *args, **env):
        return subprocess.run(["bash", str(INSTALL), "--yes", "--no-start", "--no-dots", "--skip=hypr", *args],
                              env={**self.env, **env}, capture_output=True, text=True, stdin=subprocess.DEVNULL,
                              timeout=60)

    def calls(self, prefix):
        lines = self.log.read_text().splitlines() if self.log.exists() else []
        return [line for line in lines if line.startswith(prefix)]

    def test_the_packages_part_says_apt_get(self):
        r = subprocess.run(["bash", str(INSTALL), "--list"], env=self.env, capture_output=True, text=True, check=True)
        self.assertIn("apt-get, ALT Sisyphus", r.stdout)

    def test_an_unknown_distro_is_refused(self):
        r = self.install(HI_SHELL_DISTRO="gentoo")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("arch, alt, debian or nixos", r.stderr)

    def test_missing_packages_come_from_apt_get_with_their_alt_names(self):
        r = self.install()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("Packages (ALT Linux)", logic.strip_ansi(r.stdout))
        apt = self.calls("apt-get")
        self.assertEqual(apt[0], "apt-get update")
        install = apt[1].split()
        self.assertEqual(install[:3], ["apt-get", "install", "-y"])
        for name in ("quickshell", "matugen", "notify-send", "libqt6-multimedia", "python3-module-fonttools",
                     "tesseract-langpack-ru", "ImageMagick-tools", "qalculate", "git-core"):
            self.assertIn(name, install)
        # Arch's names would not resolve on ALT.
        for name in ("qt6-multimedia-ffmpeg", "pacman-contrib", "libqalculate", "python-fonttools"):
            self.assertNotIn(name, install)
        self.assertEqual(self.calls("pacman"), [])

    def test_installed_packages_are_not_installed_again(self):
        r = self.install(FAKE_RPM_INSTALLED="all")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("All packages are installed.", r.stdout)
        self.assertEqual(self.calls("apt-get"), [])

    def test_the_icon_font_is_downloaded_when_no_package_has_it(self):
        r = self.install(FAKE_RPM_INSTALLED="all")
        self.assertEqual(r.returncode, 0, r.stderr)
        font = self.home / ".local" / "share" / "fonts" / "hi-shell" / "MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
        self.assertTrue(font.is_file())
        self.assertFalse(font.with_name(font.name + ".part").exists())
        self.assertIn("material-design-icons", self.calls("curl")[0])

    def test_a_failed_apt_get_explains_how_to_turn_sudo_on(self):
        r = self.install(FAKE_APT_EXIT="100")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("control sudowheel enabled", r.stderr)

    def test_a_hyprland_too_old_for_the_lua_config_is_reported(self):
        r = self.install(FAKE_RPM_INSTALLED="all", FAKE_HYPRLAND="0.42.0")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("Hyprland 0.42.0 is too old", r.stderr)
        self.assertNotIn("too old", self.install(FAKE_RPM_INSTALLED="all").stderr)

    def test_optional_apps_come_from_the_repository_or_epm_play(self):
        r = self.install("--with-apps", FAKE_RPM_INSTALLED="all")
        self.assertEqual(r.returncode, 0, r.stderr)
        # Installed already (FAKE_RPM_INSTALLED=all): only the epm ones run.
        self.assertEqual(self.calls("apt-get"), [])
        self.assertEqual(sorted(self.calls("epm")),
                         sorted(f"epm play --auto {p}" for p in ("zen-browser", "vesktop", "steam", "spotify")))

        self.log.unlink()
        r = self.install("--only=telegram,neovim,osu", FAKE_RPM_INSTALLED="hyprland")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.calls("apt-get")[1], "apt-get install -y telegram-desktop osu-lazer neovim")
        self.assertEqual(self.calls("epm"), [])


class AltInstallerWindowTest(unittest.TestCase):
    def root_with(self, **files):
        root = Path(tempfile.mkdtemp(prefix="hi-root-"))
        self.addCleanup(shutil.rmtree, root, True)
        (root / "etc").mkdir()
        for name, text in files.items():
            (root / "etc" / name.replace("_", "-")).write_text(text)
        return str(root)

    def test_distro_follows_install_sh(self):
        self.assertEqual(logic.distro({}, self.root_with(altlinux_release="ALT Regular Sisyphus\n")), "alt")
        self.assertEqual(logic.distro({}, self.root_with(os_release='NAME="ALT"\nID=altlinux\n')), "alt")
        self.assertEqual(logic.distro({}, self.root_with(os_release="ID=arch\n")), "arch")
        self.assertEqual(logic.distro({}, self.root_with(NIXOS="")), "nixos")
        self.assertEqual(logic.distro({"HI_SHELL_DISTRO": "alt"}, self.root_with()), "alt")

    def test_the_texts_name_apt_get_on_alt(self):
        for lang in ("ru", "en"):
            self.assertIn("apt-get", logic.describe(lang, "deps", "", "alt")["subtitle"])
            self.assertIn("pacman", logic.describe(lang, "deps", "", "arch")["subtitle"])
            self.assertIn("epm play", logic.describe(lang, "steam", "", "alt")["subtitle"])
            self.assertIn("apt-get", logic.tr(lang, "password.body", "alt"))
            self.assertIn("control sudowheel enabled", logic.tr(lang, "password.wrong", "alt"))
            self.assertNotIn("sudowheel", logic.tr(lang, "password.wrong", "arch"))

    def test_the_rest_of_a_part_stays_as_on_arch(self):
        row = logic.describe("en", "deps", "", "alt")
        self.assertEqual((row["group"], row["on"], row["sudo"]), ("system", True, True))


if __name__ == "__main__":
    unittest.main()
