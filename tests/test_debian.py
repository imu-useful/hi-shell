"""Debian: install.sh installs the packages with apt-get (Hyprland and Quickshell from trixie-backports on Debian
13, adding that suite to apt's sources when it's missing), matugen and the icon font from GitHub, the optional apps
with apt-get or flatpak; the installer window says apt-get and how to get into the sudo group.

dpkg-query, apt-cache, apt-get, sudo, flatpak, curl and fc-list are fakes on PATH that log what they were called
with; PATH has no matugen (one installed on this machine is left out)."""
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
TRIXIE = 'PRETTY_NAME="Debian GNU/Linux 13 (trixie)"\nID=debian\nVERSION_ID="13"\nVERSION_CODENAME=trixie\n'
SID = 'PRETTY_NAME="Debian GNU/Linux forky/sid"\nID=debian\nVERSION_CODENAME=forky\n'
# What this machine may have that would change the outcome.
HIDDEN = {"matugen", "flatpak", "qs", "apt-get", "apt-cache", "dpkg-query", "sudo", "curl", "fc-list", "fc-cache",
          "pacman", "rpm"}

FAKES = {
    # dpkg-query -W -f='${db:Status-Status}' <name>: installed when listed in FAKE_DEB_INSTALLED ("all":
    # everything); -f='${Version}' hyprland: FAKE_HYPRLAND, not installed without it.
    "dpkg-query": """#!/bin/sh
echo "dpkg-query $*" >> "$FAKE_LOG"
name=$3
case "$2" in *Version*) [ -n "$FAKE_HYPRLAND" ] || exit 1; printf %s "$FAKE_HYPRLAND"; exit 0 ;; esac
[ "$FAKE_DEB_INSTALLED" = all ] && { printf installed; exit 0; }
case " $FAKE_DEB_INSTALLED " in *" $name "*) printf installed; exit 0 ;; esac
exit 1
""",
    # apt-cache policy <name>: a candidate unless listed in FAKE_DEB_UNAVAILABLE.
    "apt-cache": """#!/bin/sh
case " $FAKE_DEB_UNAVAILABLE " in *" $2 "*) echo "  Candidate: (none)"; exit 0 ;; esac
echo "  Candidate: 1.0-1"
""",
    "apt-get": '#!/bin/sh\necho "apt-get $*" >> "$FAKE_LOG"\nexit "${FAKE_APT_EXIT:-0}"\n',
    "sudo": '#!/bin/sh\nexec "$@"\n',
    "flatpak": '#!/bin/sh\necho "flatpak $*" >> "$FAKE_LOG"\n',
    "pacman": '#!/bin/sh\necho "pacman $*" >> "$FAKE_LOG"\nexit 1\n',
    "fc-list": "#!/bin/sh\nexit 1\n",
    "fc-cache": "#!/bin/sh\nexit 0\n",
    # curl -fL --retry 2 -o <file> <url>: writes a file that isn't the real download.
    "curl": """#!/bin/sh
echo "curl $*" >> "$FAKE_LOG"
while [ $# -gt 0 ]; do [ "$1" = -o ] && { echo fake > "$2"; }; shift; done
""",
    "qs": "#!/bin/sh\nexit 1\n",
}


def system_bin(into: Path):
    """Links to every program on PATH but HIDDEN, so the fakes are the only ones of those."""
    into.mkdir()
    for d in os.environ["PATH"].split(":"):
        if not os.path.isdir(d):
            continue
        for name in os.listdir(d):
            target = into / name
            if name in HIDDEN or target.exists() or target.is_symlink():
                continue
            path = os.path.join(d, name)
            if os.path.isfile(path) and os.access(path, os.X_OK):
                target.symlink_to(path)


class DebianInstallTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sys_tmp = Path(tempfile.mkdtemp(prefix="hi-deb-bin-"))
        system_bin(cls.sys_tmp / "bin")

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.sys_tmp, ignore_errors=True)

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="hi-deb-"))
        self.home = self.tmp / "home"
        (self.home / ".config" / "hypr").mkdir(parents=True)
        self.bin = self.tmp / "bin"
        self.bin.mkdir()
        for name, text in FAKES.items():
            (self.bin / name).write_text(text)
            (self.bin / name).chmod(0o755)
        self.apt = self.tmp / "apt"
        (self.apt / "sources.list.d").mkdir(parents=True)
        self.os_release = self.tmp / "os-release"
        self.os_release.write_text(TRIXIE)
        self.log = self.tmp / "calls.log"
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(("XDG_", "HYPRLAND", "FAKE_", "HI_SHELL"))}
        self.env.update(HOME=str(self.home), PATH=f"{self.bin}:{self.sys_tmp / 'bin'}", HI_SHELL_DISTRO="debian",
                        HI_SHELL_OS_RELEASE=str(self.os_release), HI_SHELL_APT_DIR=str(self.apt),
                        FAKE_LOG=str(self.log), FAKE_HYPRLAND="0.56.2+ds-1")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def install(self, *args, **env):
        return subprocess.run(["bash", str(INSTALL), "--yes", "--no-start", "--no-dots", "--skip=hypr", *args],
                              env={**self.env, **env}, capture_output=True, text=True, stdin=subprocess.DEVNULL,
                              timeout=60)

    def calls(self, prefix):
        lines = self.log.read_text().splitlines() if self.log.exists() else []
        return [line for line in lines if line.startswith(prefix)]

    def backports_file(self):
        return self.apt / "sources.list.d" / "hi-shell-backports.sources"

    def test_the_packages_part_says_apt_get(self):
        r = subprocess.run(["bash", str(INSTALL), "--list"], env=self.env, capture_output=True, text=True, check=True)
        self.assertIn("apt-get, Debian", r.stdout)

    def test_missing_packages_come_from_apt_get_hyprland_from_the_backports(self):
        r = self.install()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("Packages (Debian)", logic.strip_ansi(r.stdout))
        apt = self.calls("apt-get")
        self.assertEqual(apt[0], "apt-get update")
        base, hypr = apt[1].split(), apt[2].split()
        self.assertEqual(base[:3], ["apt-get", "install", "-y"])
        for name in ("network-manager", "libnotify-bin", "qalc", "tesseract-ocr-rus", "python3-fonttools",
                     "qml6-module-qtmultimedia", "imagemagick"):
            self.assertIn(name, base)
        self.assertNotIn("hyprland", base)
        self.assertEqual(hypr, ["apt-get", "install", "-y", "-t", "trixie-backports",
                                "hyprland", "quickshell", "hyprlock", "hyprsunset", "hyprpicker"])
        # Arch's and ALT's names would not resolve on Debian.
        for name in ("libqalculate", "python-fonttools", "NetworkManager", "notify-send", "pacman-contrib", "matugen"):
            self.assertNotIn(name, base + hypr)
        self.assertEqual(self.calls("pacman"), [])

    def test_the_backports_are_added_once_when_missing(self):
        self.assertEqual(self.install(FAKE_DEB_INSTALLED="all").returncode, 0)
        text = self.backports_file().read_text()
        self.assertIn("Suites: trixie-backports", text)
        self.assertIn("Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg", text)

        self.backports_file().unlink()
        (self.apt / "sources.list").write_text("deb http://deb.debian.org/debian trixie-backports main\n")
        self.assertEqual(self.install(FAKE_DEB_INSTALLED="all").returncode, 0)
        self.assertFalse(self.backports_file().exists())

    def test_a_commented_backports_line_does_not_count(self):
        (self.apt / "sources.list").write_text("# deb http://deb.debian.org/debian trixie-backports main\n")
        self.assertEqual(self.install(FAKE_DEB_INSTALLED="all").returncode, 0)
        self.assertTrue(self.backports_file().exists())

    def test_testing_and_sid_need_no_backports(self):
        self.os_release.write_text(SID)
        r = self.install(FAKE_DEB_INSTALLED="python3")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(self.backports_file().exists())
        self.assertNotIn("-t", " ".join(self.calls("apt-get")).split())

    def test_installed_packages_are_not_installed_again(self):
        r = self.install(FAKE_DEB_INSTALLED="all")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("All packages are installed.", r.stdout)
        self.assertEqual(self.calls("apt-get"), [])

    def test_packages_no_source_has_are_named_and_the_rest_installs(self):
        r = self.install(FAKE_DEB_UNAVAILABLE="translate-shell")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("not in your apt sources: translate-shell", r.stderr)
        self.assertIn("contrib", r.stderr)
        self.assertNotIn("translate-shell", self.calls("apt-get")[1].split())

    def test_a_failed_apt_get_explains_the_sudo_group(self):
        r = self.install(FAKE_APT_EXIT="100")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("adduser", r.stderr)

    def test_matugen_is_not_installed_when_its_checksum_does_not_match(self):
        r = self.install(FAKE_DEB_INSTALLED="all")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("InioX/matugen/releases/download/v", " ".join(self.calls("curl")))
        self.assertIn("checksum didn't match", r.stderr)
        self.assertFalse((self.home / ".local" / "bin" / "matugen").exists())

    def test_the_icon_font_is_downloaded(self):
        self.assertEqual(self.install(FAKE_DEB_INSTALLED="all").returncode, 0)
        font = self.home / ".local" / "share" / "fonts" / "hi-shell" / "MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
        self.assertTrue(font.is_file())

    def test_the_hyprland_version_is_checked(self):
        r = self.install(FAKE_DEB_INSTALLED="all", FAKE_HYPRLAND="0.41.2+ds-1.3")
        self.assertIn("Hyprland 0.41.2 is too old", r.stderr)
        r = self.install(FAKE_DEB_INSTALLED="all", FAKE_HYPRLAND="0.55.2+ds-1~bpo13+1")
        self.assertNotIn("too old", r.stderr)
        self.assertIn("Hyprland 0.55.2: hi-shell is made for 0.56+", r.stdout)
        r = self.install(FAKE_DEB_INSTALLED="all")
        self.assertNotIn("too old", r.stderr)
        self.assertNotIn("is made for", r.stdout)

    def test_optional_apps_come_from_apt_get_or_flathub(self):
        (self.apt / "sources.list").write_text("deb http://deb.debian.org/debian trixie-backports main\n")
        r = self.install("--only=telegram,neovim,zen,vesktop,osu,steam,spotify", FAKE_DEB_INSTALLED="hyprland")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("apt-get install -y -t trixie-backports telegram-desktop neovim", self.calls("apt-get"))
        flatpak = self.calls("flatpak")
        self.assertIn("remote-add --user --if-not-exists flathub", flatpak[0])
        self.assertEqual(flatpak[1].split()[:5], ["flatpak", "install", "--user", "--noninteractive", "flathub"])
        self.assertEqual(sorted(flatpak[1].split()[5:]),
                         sorted(["app.zen_browser.zen", "dev.vencord.Vesktop", "sh.ppy.osu",
                                 "com.valvesoftware.Steam", "com.spotify.Client"]))


class DebianInstallerWindowTest(unittest.TestCase):
    def root_with(self, **files):
        root = Path(tempfile.mkdtemp(prefix="hi-root-"))
        self.addCleanup(shutil.rmtree, root, True)
        (root / "etc").mkdir()
        for name, text in files.items():
            (root / "etc" / name.replace("_", "-")).write_text(text)
        return str(root)

    def test_distro_follows_install_sh(self):
        self.assertEqual(logic.distro({}, self.root_with(os_release=TRIXIE)), "debian")
        self.assertEqual(logic.distro({}, self.root_with(os_release='ID="debian"\n')), "debian")
        # Debian's derivatives aren't Debian.
        self.assertEqual(logic.distro({}, self.root_with(os_release="ID=ubuntu\nID_LIKE=debian\n")), "arch")

    def test_the_texts_name_apt_get_and_the_sudo_group(self):
        for lang in ("ru", "en"):
            self.assertIn("apt-get", logic.describe(lang, "deps", "", "debian")["subtitle"])
            self.assertIn("Flathub", logic.describe(lang, "steam", "", "debian")["subtitle"])
            self.assertIn("apt-get", logic.tr(lang, "password.body", "debian"))
            self.assertIn("adduser", logic.tr(lang, "password.wrong", "debian"))


if __name__ == "__main__":
    unittest.main()
