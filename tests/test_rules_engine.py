import json
import unittest

from helpers import ROOT, node_eval

ENGINE = ROOT / "common" / "RulesEngine.js"


def ev(cond, facts):
    return node_eval(ENGINE, f"evaluate({json.dumps(cond)}, {json.dumps(facts)})")


def val(expr):
    return node_eval(ENGINE, expr)


BAT = {"battery": {"available": True, "percent": 25, "charging": False, "full": False, "onBattery": True}}


class EvaluateTest(unittest.TestCase):
    def test_battery_states(self):
        self.assertTrue(ev({"battery": "discharging"}, BAT))
        self.assertFalse(ev({"battery": "charging"}, BAT))
        self.assertFalse(ev({"battery": "plugged"}, BAT))
        self.assertTrue(ev({"battery": {"below": 30}}, BAT))
        self.assertFalse(ev({"battery": {"below": 25}}, BAT))
        self.assertTrue(ev({"battery": {"below": 30, "above": 20}}, BAT))

    def test_a_desktop_without_a_battery_never_matches_battery_levels(self):
        f = {"battery": {"available": False, "percent": 0, "onBattery": False}}
        self.assertFalse(ev({"battery": "discharging"}, f))
        self.assertFalse(ev({"battery": {"below": 50}}, f))
        self.assertTrue(ev({"battery": "plugged"}, f))

    def test_time_ranges_wrap_past_midnight(self):
        night = {"time": ["22:00", "07:00"]}
        for minutes, expected in ((23 * 60, True), (3 * 60, True), (7 * 60, False), (12 * 60, False), (22 * 60, True)):
            self.assertEqual(ev(night, {"time": minutes}), expected, minutes)
        self.assertTrue(ev({"time": ["09:00", "17:00"]}, {"time": 10 * 60}))
        self.assertFalse(ev({"time": ["09:00", "17:00"]}, {"time": 18 * 60}))

    def test_combinators(self):
        f = dict(BAT, fullscreen=True, dark=False)
        self.assertTrue(ev({"all": [{"battery": "discharging"}, {"fullscreen": True}]}, f))
        self.assertFalse(ev({"all": [{"battery": "discharging"}, {"dark": True}]}, f))
        self.assertTrue(ev({"any": [{"dark": True}, {"fullscreen": True}]}, f))
        self.assertTrue(ev({"not": {"dark": True}}, f))
        self.assertFalse(ev({"all": []}, f))
        self.assertFalse(ev({"any": []}, f))

    def test_screens_and_apps(self):
        f = {"screens": ["eDP-1", "HDMI-A-1"], "app": "Firefox", "apps": ["kitty", "steam_app_730"], "workspace": 3, "weekday": 2}
        self.assertTrue(ev({"screen": "HDMI-A-1"}, f))
        self.assertFalse(ev({"screen": "DP-2"}, f))
        self.assertTrue(ev({"screenCount": {"atLeast": 2}}, f))
        self.assertFalse(ev({"screenCount": 3}, f))
        self.assertTrue(ev({"app": "fire"}, f))
        self.assertFalse(ev({"app": "kitty"}, f))
        self.assertTrue(ev({"appOpen": "STEAM_APP"}, f))
        self.assertTrue(ev({"workspace": 3}, f))
        self.assertTrue(ev({"weekday": [1, 2]}, f))
        self.assertFalse(ev({"weekday": [0, 6]}, f))

    def test_command_uses_the_polled_results(self):
        self.assertTrue(ev({"command": "true"}, {"commands": {"true": True}}))
        self.assertFalse(ev({"command": "true"}, {"commands": {"true": False}}))
        self.assertFalse(ev({"command": "true"}, {}))

    def test_unknown_or_malformed_conditions_are_false(self):
        for c in ({"nope": 1}, None, "x", {}, 3):
            self.assertFalse(ev(c, {}), c)


class ValidateTest(unittest.TestCase):
    GOOD = {"id": "r1", "when": {"battery": "discharging"}, "then": [{"set": "bar.height", "value": 30}], "else": [{"run": "true"}]}

    def rule_error(self, rule):
        return val(f"validateRule({json.dumps(rule)})")

    def test_a_good_rule_passes(self):
        self.assertEqual(self.rule_error(self.GOOD), "")

    def test_bad_rules_say_why(self):
        cases = [
            (dict(self.GOOD, id="bad id!"), "id"),
            (dict(self.GOOD, when={"battery": "full", "dark": True}), "exactly one key"),
            (dict(self.GOOD, when={"nope": 1}), "unknown condition"),
            (dict(self.GOOD, when={"time": ["25:00", "07:00"]}), "time"),
            (dict(self.GOOD, when={"weekday": [7]}), "weekday"),
            (dict(self.GOOD, when={"all": []}), "list of conditions"),
            (dict(self.GOOD, then=[{"set": "bar.height"}]), "needs a value"),
            (dict(self.GOOD, then=[{"set": "../x", "value": 1}]), "option path"),
            (dict(self.GOOD, then=[{"foo": 1}]), "an action has"),
            (dict(self.GOOD, then="x"), "list of actions"),
            ([], "object"),
        ]
        for rule, word in cases:
            self.assertIn(word, self.rule_error(rule), rule)

    def test_deep_nesting_is_refused(self):
        cond = {"dark": True}
        for _ in range(12):
            cond = {"not": cond}
        self.assertIn("deep", self.rule_error(dict(self.GOOD, when=cond)))

    def test_every_template_is_a_valid_rule(self):
        names = val("Object.keys(templates)")
        self.assertGreaterEqual(len(names), 5)
        for name in names:
            error = val(f"validateRule(Object.assign({{ id: {name!r} }}, templates[{name!r}]))")
            self.assertEqual(error, "", name)

    def test_commands_are_collected_from_nested_conditions(self):
        cond = {"all": [{"command": "a"}, {"not": {"command": "b"}}, {"any": [{"command": "a"}, {"dark": True}]}]}
        self.assertEqual(val(f"commands({json.dumps(cond)})"), ["a", "b"])

    def test_describe_reads_a_condition(self):
        text = val('describe({all: [{battery: "discharging"}, {battery: {below: 30}}]})')
        self.assertEqual(text, "battery discharging and battery below 30%")


if __name__ == "__main__":
    unittest.main()
