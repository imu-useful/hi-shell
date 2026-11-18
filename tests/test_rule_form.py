import json
import subprocess
import unittest

from helpers import ROOT, node_eval

FORM = ROOT / "common" / "RuleForm.js"
ENGINE = ROOT / "common" / "RulesEngine.js"


def form(expr):
    return node_eval(FORM, expr)


def round_trip(rule):
    return form(f"fromForm(toForm({json.dumps(rule)}))")


TEMPLATES = node_eval(ENGINE, "templates")


class RuleFormTest(unittest.TestCase):
    def test_every_template_fits_the_form_and_comes_back_the_same(self):
        for tid, t in TEMPLATES.items():
            rule = dict(t, id=tid, enabled=True)
            self.assertIsNotNone(form(f"toForm({json.dumps(rule)})"), tid)
            back = round_trip(rule)
            for key in ("id", "name", "when", "then"):
                self.assertEqual(back[key], rule[key], (tid, key))
            self.assertEqual(back.get("else", []), rule.get("else", []), tid)

    def test_conditions_of_every_kind_round_trip(self):
        conds = [{"battery": "charging"}, {"battery": {"above": 80}}, {"fullscreen": False}, {"screen": "DP-2"},
                 {"screenCount": 3}, {"screenCount": {"atMost": 1}}, {"time": ["09:00", "17:00"]}, {"weekday": [1, 2]},
                 {"app": "code"}, {"appOpen": "obs"}, {"workspace": 4}, {"dark": True}, {"playing": False},
                 {"command": "true"}, {"not": {"app": "steam"}}]
        rule = {"id": "r", "name": "x", "enabled": False, "when": {"any": conds}, "then": [{"notify": "hi"}], "else": []}
        back = round_trip(rule)
        self.assertEqual(back["when"], rule["when"])
        self.assertEqual(back["enabled"], False)

    def test_actions_round_trip(self):
        then = [{"set": "bar.height", "value": 30}, {"set": "sounds.enabled", "value": False, "keep": True},
                {"ipc": "theme setMode dark"}, {"run": "notify-send hi"}, {"notify": "Hi"},
                {"profile": "desk", "only": "bar,dock"}, {"profile": "undo"}]
        rule = {"id": "r", "name": "", "enabled": True, "when": {"dark": True}, "then": then, "else": [{"run": "true"}]}
        back = round_trip(rule)
        self.assertEqual(back["then"], then)
        self.assertEqual(back["else"], [{"run": "true"}])

    def test_nested_groups_dont_fit_the_form(self):
        nested = {"id": "r", "when": {"all": [{"any": [{"dark": True}, {"playing": True}]}, {"fullscreen": True}]}, "then": []}
        self.assertIsNone(form(f"toForm({json.dumps(nested)})"))
        self.assertIsNone(form("toForm({id: 'r', when: {battery: {below: 10, atLeast: 2}}, then: []})"))
        self.assertIsNone(form("toForm({id: 'r', when: {dark: true}, then: [{wat: 1}]})"))

    def test_one_condition_is_not_wrapped_and_many_are(self):
        f = form("Object.assign(blank('r'), {conds: [newCond('dark')]})")
        self.assertEqual(form(f"fromForm({json.dumps(f)}).when"), {"dark": True})
        f["conds"].append(form("newCond('fullscreen')"))
        f["match"] = "any"
        self.assertEqual(form(f"fromForm({json.dumps(f)}).when"), {"any": [{"dark": True}, {"fullscreen": True}]})

    def test_every_new_condition_and_action_is_valid(self):
        source = ENGINE.read_text().replace(".pragma library", "") + "\n" + FORM.read_text().replace(".pragma library", "")
        script = source + """;process.stdout.write(JSON.stringify([
            condTypes.map(t => validateCondition(fromCond(newCond(t.id)), 0)).filter(e => e),
            actionTypes.map(t => validateAction(fromAction(newAction(t.id)))).filter(e => e)]));"""
        out = subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(out.stdout), [[], []])

    def test_ids_from_names(self):
        self.assertEqual(form("idFor('Dark mode at night!', [])"), "dark-mode-at-night")
        self.assertEqual(form("idFor('Dark mode at night', ['dark-mode-at-night'])"), "dark-mode-at-night-2")
        self.assertEqual(form("idFor('Тёмная тема', [])"), "rule")
        self.assertEqual(form("idFor('', ['rule'])"), "rule-2")

    def test_typed_values(self):
        self.assertEqual(form("[parseValue('30', 1), parseValue('true', false), parseValue('[\"*\"]', []), parseValue('snappy', 'x'), parseValue('{', {})]"),
                         [30, True, ["*"], "snappy", None])

    def test_describe_in_another_language(self):
        tr = "s => ({'%1 is open': '%1 открыт', ' and ': ' и ', 'dark mode': 'тёмная тема'})[s] ?? s"
        self.assertEqual(form(f"describe({{all: [{{appOpen: 'obs'}}, {{dark: true}}]}}, {tr})"), "obs открыт и тёмная тема")
        self.assertEqual(form("describe({time: ['22:00', '07:00']})"), "22:00–07:00")


if __name__ == "__main__":
    unittest.main()
