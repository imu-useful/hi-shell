import json
import re
import unittest

from helpers import ROOT, node_eval

PAGES = ROOT / "modules" / "settings" / "Pages.js"
INDEX = ROOT / "modules" / "settings" / "OptionIndex.js"
SETTINGS = ROOT / "modules" / "Settings.qml"


def index_options() -> list[dict]:
    text = INDEX.read_text()
    return json.loads(text[text.index("["):text.rindex("]") + 1])


class SettingsPagesTest(unittest.TestCase):
    def test_every_page_is_in_a_known_group_or_above_them(self):
        groups = set(node_eval(PAGES, "groups.map(g => g.id)"))
        bad = node_eval(PAGES, "pages.filter(p => p.group !== '' && !groups.some(g => g.id === p.group)).map(p => p.id)")
        self.assertTrue(groups)
        self.assertEqual(bad, [])

    def test_page_ids_are_unique(self):
        ids = node_eval(PAGES, "pages.map(p => p.id)")
        self.assertEqual(len(ids), len(set(ids)))

    def test_old_page_ids_still_open_a_page(self):
        self.assertEqual(node_eval(PAGES, "[find('quick').id, find('interface').id, find('bar').id]"), ["home", "style", "bar"])
        self.assertIsNone(node_eval(PAGES, "find('nope')"))

    def test_every_page_has_a_component_in_settings(self):
        ids = node_eval(PAGES, "pages.map(p => p.id)")
        text = SETTINGS.read_text()
        missing = [i for i in ids if not re.search(r"\b%s: %s\b" % (i, i), text)]
        self.assertEqual(missing, [])

    def test_every_option_in_the_index_is_on_a_page(self):
        ids = set(node_eval(PAGES, "pages.map(p => p.id)"))
        self.assertEqual(sorted({o["page"] for o in index_options()} - ids), [])

    def test_an_option_opens_the_tab_it_is_on(self):
        got = node_eval(PAGES, "[tabFor('bar', 'bar.island.music'), tabFor('bar', 'bar.clock.timeFormat'), "
                               "tabFor('bar', 'bar.instances'), tabFor('bar', 'bar.position'), tabFor('dock', 'dock.enabled')]")
        self.assertEqual(got, ["island", "widgets", "widgets", "layout", ""])

    def test_search_matches_group_names(self):
        self.assertIn("contentfilter", node_eval(PAGES, "search('habits').map(p => p.id)"))

    def test_search_ignores_russian_endings_and_yo(self):
        ru = json.dumps(str(ROOT / "translations" / "ru.json"))
        tr = f"(s => JSON.parse(require('fs').readFileSync({ru}, 'utf8'))[s] ?? s)"
        self.assertIn("wallpaper", node_eval(PAGES, f"search('обоев', {tr}).map(p => p.id)"))
        self.assertIn("sounds", node_eval(PAGES, f"search('громкости звука', {tr}).map(p => p.id)"))
        self.assertIn("home", node_eval(PAGES, f"search('темная', {tr}).map(p => p.id)"))
        self.assertTrue(node_eval(PAGES, "matches('Экран блокировки', words('экрана блокировку'))"))
        self.assertFalse(node_eval(PAGES, "matches('Экран блокировки', words('док'))"))

    def test_options_and_page_keywords_are_translated_to_russian(self):
        ru = json.loads((ROOT / "translations" / "ru.json").read_text())
        missing = [o["text"] for o in index_options() if o["text"] not in ru]
        missing += [k for k in node_eval(PAGES, "pages.map(p => p.keywords)") if k not in ru]
        self.assertEqual(missing, [])


if __name__ == "__main__":
    unittest.main()
