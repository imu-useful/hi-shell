import unittest

from helpers import ROOT, node_eval

SHARE = ROOT / "common" / "Share.js"


def share(part, total):
    return node_eval(SHARE, f"percent({part}, {total})")


class ShareTest(unittest.TestCase):
    def test_a_part_of_the_total_is_a_rounded_percent(self):
        self.assertEqual(share(30, 60), "50%")
        self.assertEqual(share(1, 3), "33%")
        self.assertEqual(share(2, 3), "67%")
        self.assertEqual(share(60, 60), "100%")

    def test_a_tiny_part_is_under_one_percent(self):
        self.assertEqual(share(1, 1000), "<1%")
        self.assertEqual(share(4, 1000), "<1%")
        self.assertEqual(share(5, 1000), "1%")

    def test_nothing_is_no_percent(self):
        self.assertEqual(share(0, 100), "")
        self.assertEqual(share(10, 0), "")
        self.assertEqual(share(-5, 100), "")

    def test_never_over_a_hundred(self):
        self.assertEqual(share(120, 100), "100%")


if __name__ == "__main__":
    unittest.main()
