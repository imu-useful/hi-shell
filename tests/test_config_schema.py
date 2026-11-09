import re
import unittest

from helpers import ROOT, node_eval

SCHEMA = ROOT / "common" / "ConfigSchema.js"


def qml_defaults():
    """dotted option -> default as written in common/ConfigOptions.qml (parsed by tools/audit_config.py)."""
    import importlib.util
    spec = importlib.util.spec_from_file_location("audit_config", ROOT / "tools" / "audit_config.py")
    source = (ROOT / "tools" / "audit_config.py").read_text().replace("\nmain()\n", "\n")
    ns = {"__file__": str(ROOT / "tools" / "audit_config.py")}
    exec(source, ns)
    return {path: default for path, _, default in ns["parse_options"]()}


def norm(v):
    v = str(v).strip().strip('"')
    try:
        return float(v)
    except ValueError:
        return v


class SchemaTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rules = node_eval(SCHEMA, "rules")
        cls.defaults = qml_defaults()

    def test_every_rule_names_an_existing_option(self):
        missing = [p for p in self.rules if p not in self.defaults]
        self.assertEqual(missing, [])

    def test_rule_defaults_match_the_option_defaults(self):
        for path, rule in self.rules.items():
            self.assertEqual(norm(rule["def"]), norm(self.defaults[path]), path)

    def test_the_default_of_every_rule_passes_it(self):
        for path, rule in self.rules.items():
            result = node_eval(SCHEMA, f"problem({path!r}, {rule['def']!r})".replace("True", "true").replace("False", "false"))
            self.assertEqual(result, "", path)

    def test_enum_rejects_unknown_value(self):
        self.assertIn("must be one of", node_eval(SCHEMA, 'problem("bar.position", "lefft")'))
        self.assertEqual(node_eval(SCHEMA, 'problem("bar.position", "left")'), "")

    def test_range_rejects_out_of_range_and_non_numbers(self):
        self.assertIn("between", node_eval(SCHEMA, 'problem("lock.brightness", 7)'))
        self.assertIn("between", node_eval(SCHEMA, 'problem("lock.brightness", -0.1)'))
        self.assertEqual(node_eval(SCHEMA, 'problem("lock.brightness", 0.5)'), "")
        self.assertIn("number", node_eval(SCHEMA, 'problem("lock.brightness", "high")'))

    def test_seed_color_pattern(self):
        for ok in ("", "#ff6a00", "#ABCDEF"):
            self.assertEqual(node_eval(SCHEMA, f"problem('appearance.seedColor', {ok!r})"), "", ok)
        for bad in ("red", "#ff6a0", "ff6a00", "#gggggg", "#ff6a000"):
            self.assertNotEqual(node_eval(SCHEMA, f"problem('appearance.seedColor', {bad!r})"), "", bad)

    def test_language_allows_custom_codes(self):
        self.assertEqual(node_eval(SCHEMA, 'problem("language", "de")'), "")

    def test_option_without_a_rule_is_fine(self):
        self.assertEqual(node_eval(SCHEMA, 'problem("bar.logo", 12)'), "")

    def test_check_lists_only_the_broken_options(self):
        bad = node_eval(SCHEMA, 'check(p => ({"bar.position": "lefft", "bar.height": 40, "lock.brightness": 7})[p])')
        self.assertEqual(sorted(b["path"] for b in bad), ["bar.position", "lock.brightness"])
        self.assertEqual({b["path"]: b["def"] for b in bad}["bar.position"], "top")


if __name__ == "__main__":
    unittest.main()
