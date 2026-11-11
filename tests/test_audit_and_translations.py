import json
import re
import unittest
from pathlib import Path

from helpers import ROOT


def parse_options():
    ns = {"__file__": str(ROOT / "tools" / "audit_config.py")}
    exec((ROOT / "tools" / "audit_config.py").read_text().replace("\nmain()\n", "\n"), ns)
    return ns["parse_options"]()


class AuditTest(unittest.TestCase):
    def test_options_are_parsed_with_their_defaults(self):
        opts = {p: (t, d) for p, t, d in parse_options()}
        self.assertGreater(len(opts), 150)
        self.assertEqual(opts["bar.height"], ("int", "40"))
        self.assertEqual(opts["appearance.fonts.main"][0], "string")
        self.assertEqual(opts["bar.left"][0], "list<string>")
        self.assertIn("bar.monitors", opts)
        self.assertIn("launcher.sources", opts)

    def test_paths_are_unique(self):
        paths = [p for p, _, _ in parse_options()]
        self.assertEqual(len(paths), len(set(paths)))


class TranslationsTest(unittest.TestCase):
    def test_ru_json_is_valid_and_has_no_duplicate_keys(self):
        seen = []

        def hook(pairs):
            seen.extend(k for k, _ in pairs)
            return dict(pairs)

        json.loads((ROOT / "translations" / "ru.json").read_text(), object_pairs_hook=hook)
        dupes = sorted({k for k in seen if seen.count(k) > 1})
        self.assertEqual(dupes, [])

    def test_the_settings_pages_we_added_are_translated(self):
        ru = json.loads((ROOT / "translations" / "ru.json").read_text())
        files = ["modules/settings/BarPage.qml", "modules/settings/InterfacePage.qml", "modules/BarEditor.qml", "modules/settings/OrderedChips.qml",
                 "services/UserWidgets.qml", "modules/settings/DesktopPage.qml", "modules/settings/HomePage.qml", "modules/Settings.qml", "modules/settings/RulesPage.qml", "services/Presets.qml"]
        missing = []
        for f in files:
            text = (ROOT / f).read_text()
            for m in re.finditer(r'Translation\.tr\("((?:[^"\\]|\\.)*)"\)', text):
                if m.group(1) not in ru:
                    missing.append((f, m.group(1)))
        self.assertEqual(missing, [])


if __name__ == "__main__":
    unittest.main()
