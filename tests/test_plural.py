import unittest

from helpers import ROOT, node_eval

PLURAL = ROOT / "common" / "Plural.js"
PAGES = ROOT / "modules" / "settings" / "Pages.js"


class PluralTest(unittest.TestCase):
    def test_russian_and_ukrainian_have_three_forms(self):
        for code in ("ru", "uk"):
            got = node_eval(PLURAL, f"[1, 2, 5, 11, 12, 14, 21, 22, 25, 101, 111].map(n => index('{code}', n))")
            self.assertEqual(got, [0, 1, 2, 2, 2, 2, 0, 1, 2, 0, 2], code)

    def test_german_english_and_spanish_have_one_and_other(self):
        for code in ("de", "en", "es", "pt"):
            self.assertEqual(node_eval(PLURAL, f"[0, 1, 2, 21].map(n => index('{code}', n))"), [1, 0, 1, 1], code)

    def test_chinese_and_japanese_have_a_single_form(self):
        for code in ("zh", "ja"):
            self.assertEqual(node_eval(PLURAL, f"[0, 1, 5].map(n => index('{code}', n))"), [0, 0, 0], code)

    def test_pick_never_goes_past_the_forms_given(self):
        self.assertEqual(node_eval(PLURAL, "pick(['a', 'b'], 'ru', 5)"), "b")
        self.assertEqual(node_eval(PLURAL, "pick(['a'], 'de', 7)"), "a")
        self.assertEqual(node_eval(PLURAL, "pick(['a', 'b', 'c'], 'ru', 5)"), "c")


class SearchFoldingTest(unittest.TestCase):
    def test_umlauts_and_eszett_match_their_plain_spelling(self):
        self.assertTrue(node_eval(PAGES, "matches('Größe der Leiste', words('grosse'))"))
        self.assertTrue(node_eval(PAGES, "matches('Benachrichtigungen schließen', words('schliessen'))"))


if __name__ == "__main__":
    unittest.main()
