import json
import sys
import unittest

from helpers import ROOT

sys.path.insert(0, str(ROOT / "services"))
import rule_maker  # noqa: E402

KNOWN = {"bar.height": "The bar's height", "dock.enable": "Show the dock"}


def answers(*replies):
    """An `ask` that hands out the replies in order and keeps the prompts it got."""
    prompts = []

    def ask(prompt):
        prompts.append(prompt)
        return replies[len(prompts) - 1]

    return ask, prompts


class RuleMakerTest(unittest.TestCase):
    def test_the_prompt_has_the_format_the_options_the_facts_and_the_request(self):
        p = rule_maker.prompt_for("hide the dock in games", KNOWN, '{"screens": ["DP-1"]}')
        self.assertIn("screenCount", p)
        self.assertIn("dock.enable: Show the dock", p)
        self.assertIn("DP-1", p)
        self.assertIn("hide the dock in games", p)

    def test_the_real_option_index_and_rules_doc_are_read(self):
        self.assertIn("bar.height", rule_maker.options())
        self.assertIn('"notify"', rule_maker.rule_format())

    def test_a_rule_in_chatter_comes_out_clean_and_without_an_id(self):
        ask, _ = answers('Sure!\n```json\n{"id": "x", "name": " Low bar ", "when": {"dark": true}, "then": [{"set": "bar.height", "value": 30}], "junk": 1}\n```')
        rule = rule_maker.make("a low bar in dark mode", ask, KNOWN)
        self.assertEqual(rule, {"name": "Low bar", "enabled": True, "when": {"dark": True}, "then": [{"set": "bar.height", "value": 30}], "else": []})

    def test_an_unknown_option_is_sent_back_once(self):
        good = {"name": "n", "when": {"dark": True}, "then": [{"set": "dock.enable", "value": False}]}
        ask, prompts = answers(json.dumps(dict(good, then=[{"set": "dock.visible", "value": False}])), json.dumps(good))
        self.assertEqual(rule_maker.make("no dock", ask, KNOWN)["then"], good["then"])
        self.assertIn("there is no option dock.visible", prompts[1])

    def test_it_gives_up_after_two_bad_answers(self):
        ask, _ = answers("no idea", "still no idea")
        with self.assertRaises(RuntimeError):
            rule_maker.make("something", ask, KNOWN)


if __name__ == "__main__":
    unittest.main()
