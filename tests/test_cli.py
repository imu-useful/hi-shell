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


if __name__ == "__main__":
    unittest.main()
