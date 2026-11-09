import json
import subprocess
import sys
import unittest

from helpers import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import config_meta as cm  # noqa: E402


class ConfigMetaTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.options = cm.parse_options()
        cls.where = cm.locate(cls.options)

    def test_every_option_has_a_description(self):
        self.assertEqual([o.path for o in self.options if not o.description], [])

    def test_every_option_can_be_reached(self):
        """In a settings page, or listed in tools/config_meta.json as changed elsewhere or file-only."""
        self.assertEqual([p for p, w in self.where.items() if not w], [])

    def test_the_meta_file_names_no_missing_option(self):
        self.assertEqual(cm.stale_meta(self.options), [])

    def test_generated_files_are_up_to_date(self):
        self.assertEqual(cm.DOC.read_text(), cm.build_doc(self.options), "run: python3 tools/config_meta.py docs")
        self.assertEqual(cm.INDEX.read_text(), cm.build_index(self.options), "run: python3 tools/config_meta.py docs")

    def test_the_check_command_passes(self):
        r = subprocess.run([sys.executable, str(ROOT / "tools" / "config_meta.py"), "check"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout)

    def test_the_option_index_matches_the_options_with_a_page(self):
        index = json.loads(cm.INDEX.read_text().split("const options = ")[1].rstrip().rstrip(";"))
        with_page = {p for p, w in self.where.items() if w.startswith("page:")}
        self.assertEqual({e["path"] for e in index}, with_page)
        by_path = {e["path"]: e for e in index}
        self.assertEqual(by_path["bar.height"]["page"], "bar")
        self.assertTrue(by_path["dock.spacing"]["advanced"])

    def test_the_schema_rules_show_in_the_reference(self):
        doc = cm.DOC.read_text()
        self.assertIn("`top` \\| `bottom` \\| `left` \\| `right`", doc)  # bar.position
        self.assertIn("0 … 1", doc)

    def test_advanced_options_are_hidden_behind_the_switch_in_the_pages(self):
        advanced = [k for k, v in cm.load_meta().items() if v.get("advanced") and not k.endswith(".*") and self.where.get(k, "").startswith("page:")]
        self.assertGreater(len(advanced), 10)
        sources = "\n".join(p.read_text() for p in (ROOT / "modules" / "settings").glob("*Page.qml"))
        self.assertGreaterEqual(sources.count("settingsAdvanced"), len(advanced))

    def test_search_finds_an_option_by_name_or_description(self):
        r = subprocess.run([sys.executable, str(ROOT / "tools" / "config_meta.py"), "search", "gap", "icons"], capture_output=True, text=True)
        self.assertIn("dock.spacing", r.stdout)
        none = subprocess.run([sys.executable, str(ROOT / "tools" / "config_meta.py"), "search", "zzzzqq"], capture_output=True, text=True)
        self.assertIn("No option matches", none.stdout)


if __name__ == "__main__":
    unittest.main()
