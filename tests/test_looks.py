import json
import unittest

from helpers import ROOT, node_eval

LOOKS = ROOT / "common" / "Looks.js"
SCHEMA = ROOT / "common" / "ConfigSchema.js"


def val(expr):
    return node_eval(LOOKS, expr)


class LooksTest(unittest.TestCase):
    def test_every_builtin_look_holds_only_known_options(self):
        keys = set(val("keys"))
        for name, look in val("builtin").items():
            self.assertLessEqual(set(look["set"]), keys, name)

    def test_builtin_values_pass_the_config_rules(self):
        rules = node_eval(SCHEMA, "rules")
        for name, look in val("builtin").items():
            for key, value in look["set"].items():
                rule = rules.get("appearance." + key)
                if not rule:
                    continue
                if "enum" in rule:
                    self.assertIn(value, rule["enum"], f"{name}.{key}")
                else:
                    self.assertTrue(rule["min"] <= value <= rule["max"], f"{name}.{key}")

    def test_names_are_checked(self):
        for good in ("Night", "my look 2", "a.b-c_d"):
            self.assertTrue(val(f"validName({json.dumps(good)})"), good)
        for bad in ("", " x", "x ", "a/b", "x" * 41, "a\nb"):
            self.assertFalse(val(f"validName({json.dumps(bad)})"), repr(bad))

    def test_pick_drops_what_a_look_may_not_hold(self):
        out = val('pick({ cornerScale: 2, scheme: "vibrant", looks: {} })')
        self.assertEqual(out, {"cornerScale": 2})

    def test_own_looks_are_added_and_win_over_built_in_ones(self):
        out = val('all({ "Calm": { cornerScale: 0 }, "Mine": { density: "compact", scheme: "x" }, "bad/name": {} })')
        self.assertEqual(out["Calm"]["set"], {"cornerScale": 0})
        self.assertFalse(out["Calm"]["builtin"])
        self.assertEqual(out["Mine"]["set"], {"density": "compact"})
        self.assertNotIn("bad/name", out)
        self.assertTrue(out["Soft"]["builtin"])
