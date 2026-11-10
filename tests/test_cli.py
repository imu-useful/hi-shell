import json
import unittest

from helpers import FakeQs


class CliTest(unittest.TestCase):
    def setUp(self):
        self.qs = FakeQs()
        self.addCleanup(self.qs.close)

    def last(self):
        return self.qs.calls[-1][4:]

    def test_config_set_sends_the_value_with_a_leading_space(self):
        self.qs.run("config", "set", "bar.style", "islands")
        self.assertEqual(self.last(), ["config", "set", "bar.style", " islands"])

    def test_config_set_keeps_a_json_list_intact(self):
        self.qs.run("config", "set", "bar.left", '["a","b"]')
        self.assertEqual(self.last(), ["config", "set", "bar.left", ' ["a","b"]'])

    def test_config_set_needs_a_value(self):
        r = self.qs.run("config", "set", "bar.style")
        self.assertNotEqual(r.returncode, 0)

    def test_bar_add_builds_valid_json_even_with_quotes(self):
        self.qs.run("bar", "add", "side", "left", 'a"b', "workspaces")
        entry = json.loads(self.last()[3])
        self.assertEqual(entry, {"id": "side", "position": "left", "center": ['a"b', "workspaces"]})

    def test_bar_add_without_widgets_has_an_empty_list(self):
        self.qs.run("bar", "add", "empty", "top")
        self.assertEqual(json.loads(self.last()[3])["center"], [])

    def test_bar_instance_name_can_not_hold_a_dot(self):
        r = self.qs.run("bar", "instance", "x#a.b", "{}")
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(self.qs.calls, [])

    def test_bar_monitor_path_and_value(self):
        self.qs.run("bar", "monitor", "eDP-1", "height", "34")
        self.assertEqual(self.last(), ["config", "map", "bar.monitors", "eDP-1.height", " 34"])

    def test_script_makes_a_script_instance(self):
        self.qs.run("script", "temp", 'echo "hi"', "10", "thermostat", "{}°")
        call = self.last()
        self.assertEqual(call[:3], ["config", "map", "bar.instances"])
        self.assertEqual(call[3], "script#temp")
        self.assertEqual(json.loads(call[4]), {"command": 'echo "hi"', "interval": 10.0, "icon": "thermostat", "template": "{}°"})

    def test_theme_seed_checks_the_color(self):
        self.assertNotEqual(self.qs.run("theme", "seed", "red").returncode, 0)
        self.assertEqual(self.qs.calls, [])
        self.qs.run("theme", "seed", "#336699")
        self.assertEqual(self.last(), ["config", "set", "appearance.seedColor", '"#336699"'])
        self.qs.run("theme", "seed", "wallpaper")
        self.assertEqual(self.last(), ["config", "set", "appearance.seedColor", '""'])

    def test_widgets_new_makes_a_file_from_the_template(self):
        r = self.qs.run("widgets", "new", "clockwork")
        self.assertEqual(r.returncode, 0, r.stderr)
        path = self.qs.home / ".config" / "hi-shell" / "widgets" / "clockwork.qml"
        text = path.read_text()
        self.assertIn("clockwork", text)
        self.assertNotIn("__NAME__", text)

    def test_widgets_new_refuses_bad_and_existing_names(self):
        for bad in ("1abc", "a-b", "a/b", "a b", ""):
            self.assertNotEqual(self.qs.run("widgets", "new", bad).returncode, 0, repr(bad))
        self.qs.run("widgets", "new", "once")
        self.assertNotEqual(self.qs.run("widgets", "new", "once").returncode, 0)

    def test_widgets_edit_rejects_a_path(self):
        self.assertNotEqual(self.qs.run("widgets", "edit", "../x").returncode, 0)

    def test_wallpaper_for_one_screen(self):
        self.qs.run("wallpaper", "screen", "eDP-1", "/tmp/a b.png")
        self.assertEqual(self.last(), ["config", "map", "wallpapers.perScreen", "eDP-1", ' "/tmp/a b.png"'])
        self.qs.run("wallpaper", "screen", "eDP-1", "none")
        self.assertEqual(self.last()[-1], " null")
        self.assertNotEqual(self.qs.run("wallpaper", "screen", "eDP-1").returncode, 0)

    def test_dock_and_desktop_screens(self):
        self.qs.run("dock", "screens", "all")
        self.assertEqual(self.last(), ["config", "set", "dock.monitors", ' ["*"]'])
        self.qs.run("dock", "screens", "eDP-1", "HDMI-A-1")
        self.assertEqual(self.last(), ["config", "set", "dock.monitors", ' ["eDP-1", "HDMI-A-1"]'])
        self.qs.run("dock", "own", "eDP-1", "iconSize", "56")
        self.assertEqual(self.last(), ["config", "map", "dock.perScreen", "eDP-1.iconSize", " 56"])
        self.qs.run("desktop", "screens", "HDMI-A-1")
        self.assertEqual(self.last(), ["config", "set", "desktop.monitors", ' ["HDMI-A-1"]'])
        self.qs.run("desktop", "own", "eDP-1", "off")
        self.assertEqual(self.last(), ["config", "map", "desktop.layouts", "eDP-1", " null"])
        self.assertNotEqual(self.qs.run("dock", "screens").returncode, 0)

    def test_rules_commands_call_the_rules_target(self):
        self.qs.run("rules", "add", "night-dark")
        self.assertEqual(self.last(), ["rules", "addTemplate", "night-dark"])
        self.qs.run("rules", "off", "x")
        self.assertEqual(self.last(), ["rules", "enable", "x", "false"])
        self.qs.run("rules", "on", "x")
        self.assertEqual(self.last(), ["rules", "enable", "x", "true"])
        self.qs.run("rules", "rm", "x")
        self.assertEqual(self.last(), ["rules", "remove", "x"])
        self.assertNotEqual(self.qs.run("rules", "add").returncode, 0)
        self.assertNotEqual(self.qs.run("rules", "edit", "a b").returncode, 0)

    def test_preset_save_and_load_call_the_presets_target(self):
        self.qs.run("preset", "save", "mine")
        self.assertEqual(self.last(), ["presets", "save", "mine"])
        self.qs.run("preset", "save", "--profile", "work")
        self.assertEqual(self.last(), ["presets", "saveProfile", "work"])
        self.qs.run("preset", "load", "work")
        call = self.last()
        self.assertEqual(call[:2], ["presets", "loadWith"])
        self.assertTrue(call[2].endswith("/hi-shell/presets/work.tar.gz"))
        self.assertEqual((call[3].strip(), call[4]), ("", "false"))
        self.qs.run("preset", "load", "work", "--only", "bar,dock", "--trust")
        call = self.last()
        self.assertEqual((call[3].strip(), call[4]), ("bar,dock", "true"))
        self.assertNotEqual(self.qs.run("preset", "load").returncode, 0)
        self.assertNotEqual(self.qs.run("preset", "load", "x", "--only").returncode, 0)

    def test_preset_diff_runs_on_the_files_without_the_shell(self):
        import json
        import subprocess
        import sys
        from helpers import ROOT
        cfgdir = self.qs.home / ".config" / "hi-shell"
        cfgdir.mkdir(parents=True)
        (cfgdir / "config.json").write_text(json.dumps({"bar": {"height": 40}}))
        src = self.qs.dir / "src.json"
        src.write_text(json.dumps({"bar": {"height": 30}}))
        out = self.qs.dir / "p.tar.gz"
        subprocess.run([sys.executable, str(ROOT / "services" / "presets.py"), "export", str(out), "--config", str(src)], check=True, capture_output=True)
        r = self.qs.run("preset", "diff", str(out))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("bar.height: 40 -> 30", r.stdout)
        self.assertEqual(self.qs.calls, [])

    def test_unknown_command_fails_and_help_lists_the_commands(self):
        self.assertEqual(self.qs.run("nope").returncode, 1)
        out = self.qs.run("help").stdout
        for word in ("hi start", "hi config", "hi bar", "hi widgets"):
            self.assertIn(word.split()[1], out)

    def test_panel_shortcuts_call_the_right_targets(self):
        for args, expected in [(("launcher",), ["launcher", "toggle"]), (("settings", "bar"), ["settings", "open", "bar"]),
                               (("lock",), ["lock", "lock"]), (("play",), ["mpris", "playPause"])]:
            self.qs.run(*args)
            self.assertEqual(self.last(), expected, args)

    def test_new_shortcuts_call_the_right_targets(self):
        cases = [
            (("shot",), ["region", "screenshot"]), (("shot", "full"), ["region", "fullscreen"]),
            (("ocr",), ["region", "ocr"]), (("record",), ["region", "record"]),
            (("session",), ["session", "toggleScreen"]), (("session", "suspend"), ["session", "suspend"]),
            (("power", "shutdown"), ["session", "poweroff"]), (("boot", "arch.conf"), ["boot", "reboot", "arch.conf"]),
            (("brightness", "up"), ["brightness", "increment"]), (("brightness", "40%"), ["brightness", "set", "40"]),
            (("display", "mirror"), ["display", "set", "mirror"]), (("powersave", "on"), ["powersaving", "on"]),
            (("notif", "clear"), ["notifications", "clear"]), (("notif", "dnd"), ["notifications", "toggleDnd"]),
            (("notif", "dismiss", "7"), ["notifications", "dismiss", "7"]),
            (("todo", "add", "buy", "milk"), ["todo", "add", "buy milk"]), (("todo", "done", "2"), ["todo", "toggle", "2"]),
            (("focus", "task", "write", "docs"), ["focus", "addTask", "write docs"]), (("focus", "start"), ["focus", "start"]),
            (("screentime", "limit", "zen", "60"), ["screentime", "limit", "zen", "60"]),
        ]
        for args, expected in cases:
            r = self.qs.run(*args)
            self.assertEqual(r.returncode, 0, (args, r.stderr))
            self.assertEqual(self.last(), expected, args)

    def test_new_commands_check_their_arguments_before_calling_the_shell(self):
        for args in (("brightness", "101"), ("brightness", "lots"), ("todo", "done", "0"), ("todo", "done", "x"),
                     ("todo", "add"), ("notif", "dismiss", "a"), ("screentime", "limit", "zen"),
                     ("shot", "nope"), ("session", "nope"), ("display", "nope"), ("sounds", "nope"), ("channel", "beta")):
            self.assertNotEqual(self.qs.run(*args).returncode, 0, args)
        self.assertEqual(self.qs.calls, [])

    def test_channel_without_a_running_shell_writes_the_config_and_keeps_the_rest(self):
        cfgdir = self.qs.home / ".config" / "hi-shell"
        cfgdir.mkdir(parents=True)
        (cfgdir / "config.json").write_text(json.dumps({"bar": {"height": 40}}))
        (self.qs.dir / "qs").write_text("#!/bin/sh\nexit 1\n")  # not running
        r = self.qs.run("channel", "release")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(json.loads((cfgdir / "config.json").read_text()), {"bar": {"height": 40}, "update": {"channel": "release"}})
        self.assertEqual(self.qs.run("channel").stdout.strip(), "release")

    def test_complete_lists_commands_subcommands_and_option_names(self):
        top = self.qs.run("__complete").stdout.split("\n")
        for word in ("start", "shot", "todo", "config", "completions"):
            self.assertIn(word, top)
        self.assertIn("ocr", self.qs.run("__complete", "shot").stdout.split("\n"))
        names = self.qs.run("__complete", "config", "set").stdout.split("\n")
        self.assertIn("bar.height", names)
        self.assertIn("bar", names)
        self.assertEqual(self.qs.run("__complete", "config", "set", "bar.height").stdout, "")
        self.assertEqual(self.qs.calls, [])

    def test_every_command_in_the_completions_is_known_to_the_cli(self):
        for word in self.qs.run("__complete").stdout.split():
            if word in ("start", "stop", "restart", "update", "install", "uninstall", "help", "log", "doctor", "edit"):
                continue  # these run things for real
            out = self.qs.run(word)
            self.assertNotIn("Unknown command", out.stderr, word)

    def test_completions_prints_each_script(self):
        for shell in ("bash", "zsh", "fish"):
            r = self.qs.run("completions", shell)
            self.assertEqual(r.returncode, 0)
            self.assertIn("__complete", r.stdout)
        self.assertNotEqual(self.qs.run("completions", "tcsh").returncode, 0)

    def test_help_shows_the_whole_header_and_not_the_code(self):
        out = self.qs.run("help").stdout
        self.assertIn("hi shot", out)
        self.assertIn("hi qr", out)
        self.assertNotIn("set -u", out)
        self.assertNotIn("install.sh links", out)


if __name__ == "__main__":
    unittest.main()
