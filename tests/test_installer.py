"""The installer window's logic (installer/logic.py) and how it talks to install.sh; no GTK needed."""
import subprocess
import sys
import unittest

from helpers import ROOT

sys.path.insert(0, str(ROOT / "installer"))
import logic  # noqa: E402

INSTALL = ROOT / "install.sh"


def listed():
    out = subprocess.run(["bash", str(INSTALL), "--list"], capture_output=True, text=True, check=True).stdout
    return logic.parse_list(out)


class PartsTest(unittest.TestCase):
    def test_every_part_of_install_sh_is_described_in_both_languages(self):
        names = [n for n, _ in listed()]
        self.assertIn("deps", names)
        for name in names:
            self.assertIn(name, logic.PARTS, f"{name}: add it to installer/logic.py PARTS")
            for lang in ("ru", "en"):
                self.assertEqual(len(logic.PARTS[name][lang]), 2, name)

    def test_no_part_is_described_that_install_sh_lacks(self):
        self.assertEqual(set(logic.PARTS), {n for n, _ in listed()})

    def test_an_unknown_part_still_shows_up_with_install_sh_text(self):
        row = logic.describe("ru", "newthing", "Something new")
        self.assertEqual((row["group"], row["subtitle"], row["on"]), ("other", "Something new", True))

    def test_rows_follow_the_group_order(self):
        groups = [r["group"] for r in logic.rows("en", listed())]
        self.assertEqual(groups, sorted(groups, key=logic.GROUPS.index))
        self.assertEqual(groups[0], "system")

    def test_apps_are_off_and_need_sudo_by_default(self):
        for name, meta in logic.PARTS.items():
            if meta["group"] == "apps":
                self.assertFalse(meta["on"], name)
                self.assertTrue(meta["sudo"], name)

    def test_every_text_key_exists_in_both_languages(self):
        self.assertEqual(set(logic.TEXT["ru"]), set(logic.TEXT["en"]))


class ArgsTest(unittest.TestCase):
    names = ["deps", "hypr", "fish", "zen", "start"]

    def test_only_the_picked_parts_in_install_sh_order(self):
        args = logic.install_args(["start", "deps"], self.names, "release")
        self.assertEqual(args, ["--yes", "--channel=release", "--only=deps,start"])

    def test_nothing_picked_skips_every_part(self):
        # an empty --only would mean "everything" to install.sh
        self.assertEqual(logic.install_args([], self.names, "git")[-1], "--skip=deps,hypr,fish,zen,start")

    def test_unknown_channel_is_refused(self):
        with self.assertRaises(ValueError):
            logic.install_args(["deps"], self.names, "nightly")

    def test_install_sh_accepts_the_arguments(self):
        # --list checks the part names, then exits before anything is done
        names = [n for n, _ in listed()]
        for picked in (["hypr", "fish"], []):
            args = logic.install_args(picked, names, "release")
            r = subprocess.run(["bash", str(INSTALL), *args, "--list"], capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
        r = subprocess.run(["bash", str(INSTALL), "--only=nosuchpart", "--list"], capture_output=True, text=True)
        self.assertNotEqual(r.returncode, 0)

    def test_sudo_only_for_packages_and_apps(self):
        self.assertFalse(logic.needs_sudo(["hypr", "fish", "start"]))
        self.assertTrue(logic.needs_sudo(["hypr", "deps"]))
        self.assertTrue(logic.needs_sudo(["telegram"]))


class ProgressTest(unittest.TestCase):
    def test_expected_steps_follow_the_parts(self):
        self.assertEqual(logic.expected_steps(["hypr"]), ["Source", "Link", "Hyprland"])
        steps = logic.expected_steps(["deps", "zen", "kitty", "start"])
        self.assertEqual(steps, ["Packages", "Optional apps", "Source", "Link", "Hyprland", "Terminal configs", "Start"])

    def test_every_step_is_a_heading_install_sh_prints(self):
        text = INSTALL.read_text()
        for heading, _ in logic.STEPS:
            self.assertIn(f'step "{heading}', text, heading)

    def test_progress_grows_and_stays_below_one(self):
        expected = logic.expected_steps(["deps", "start"])
        values = [logic.progress(h, expected) for h in expected]
        self.assertEqual(values, sorted(values))
        self.assertLess(values[-1], 1)
        self.assertGreater(logic.progress(None, expected), 0)

    def test_step_heading_ignores_pacman_lines(self):
        self.assertEqual(logic.step_heading(":: Packages (NixOS)"), "Packages")
        self.assertEqual(logic.step_heading(":: Hyprland"), "Hyprland")
        self.assertIsNone(logic.step_heading(":: Proceed with installation? [Y/n]"))
        self.assertIsNone(logic.step_heading("Packages"))


class TerminalTest(unittest.TestCase):
    def test_lines_and_colors(self):
        t = logic.Terminal()
        self.assertEqual(t.feed("\x1b[1m\x1b[32m::\x1b[0m\x1b[1m Link\x1b[0m\nhalf"), [":: Link"])
        self.assertEqual(t.line, "half")
        self.assertEqual(t.feed(" done\n"), ["half done"])

    def test_carriage_return_rewrites_the_line(self):
        t = logic.Terminal()
        self.assertEqual(t.feed(" pkg  10%\r pkg  50%\r pkg 100%\n"), [" pkg 100%"])

    def test_crlf_keeps_the_line(self):
        self.assertEqual(logic.Terminal().feed("a\r\nb\r\n"), ["a", "b"])

    def test_escape_split_between_chunks(self):
        t = logic.Terminal()
        self.assertEqual(t.feed("x\x1b[3"), [])
        self.assertEqual(t.feed("2my\n"), ["xy"])

    def test_password_prompt(self):
        t = logic.Terminal()
        t.feed("resolving...\n" + logic.SUDO_PROMPT)
        self.assertTrue(t.asks_password())
        t.feed("\n[sudo] password for someone: ")
        self.assertFalse(t.asks_password())


class LanguageTest(unittest.TestCase):
    def test_language_from_the_locale(self):
        self.assertEqual(logic.language({"LANG": "ru_RU.UTF-8"}), "ru")
        self.assertEqual(logic.language({"LANG": "ru_RU.UTF-8", "LC_ALL": "C"}), "en")
        self.assertEqual(logic.language({}), "en")
        self.assertEqual(logic.tr("ru", "done.fail.body", code=1, log="/x"), "Код выхода 1. Журнал: /x")


class SetupTest(unittest.TestCase):
    def test_scripts_parse(self):
        for f in ("setup.sh", "install.sh"):
            subprocess.run(["bash", "-n", str(ROOT / f)], check=True)

    def test_setup_downloads_every_file_the_window_imports(self):
        text = (ROOT / "setup.sh").read_text()
        for f in ("install.sh", "installer/gui.py", "installer/logic.py"):
            self.assertIn(f, text)

    def test_setup_text_mode_runs_install_sh(self):
        r = subprocess.run(["bash", str(ROOT / "setup.sh"), "--list"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("deps", r.stdout)


if __name__ == "__main__":
    unittest.main()
