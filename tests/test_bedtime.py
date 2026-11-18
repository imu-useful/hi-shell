import json
import unittest

from helpers import ROOT, node_eval

BEDTIME = ROOT / "common" / "Bedtime.js"


def night(stamp, bedtime="22:00", wake="06:00"):
    return node_eval(BEDTIME, f"nightOf(new Date({stamp!r}), {bedtime!r}, {wake!r})")


def due(stamp, opts, state):
    o = {"enabled": True, "time": "22:00", "wake": "06:00", **opts}
    return node_eval(BEDTIME, f"due(new Date({stamp!r}), {json.dumps(o)}, {json.dumps(state)})")


class BedtimeTest(unittest.TestCase):
    def test_times_are_parsed(self):
        self.assertEqual(node_eval(BEDTIME, "minutesOf('22:30')"), 22 * 60 + 30)
        self.assertEqual(node_eval(BEDTIME, "minutesOf('7:05')"), 7 * 60 + 5)
        for bad in ("24:00", "22:60", "abc", "", "22"):
            self.assertEqual(node_eval(BEDTIME, f"minutesOf({bad!r})"), -1, bad)

    def test_a_night_across_midnight_belongs_to_its_evening(self):
        self.assertEqual(night("2026-11-18T22:00"), "2026-11-18")
        self.assertEqual(night("2026-11-18T23:59"), "2026-11-18")
        self.assertEqual(night("2026-11-19T01:30"), "2026-11-18")
        self.assertEqual(night("2026-12-01T03:00"), "2026-11-30")
        self.assertEqual(night("2026-11-19T06:00"), "")
        self.assertEqual(night("2026-11-18T21:59"), "")
        self.assertEqual(night("2026-11-18T12:00"), "")

    def test_a_night_after_midnight(self):
        self.assertEqual(night("2026-11-19T01:00", "01:00", "06:00"), "2026-11-19")
        self.assertEqual(night("2026-11-18T23:00", "01:00", "06:00"), "")

    def test_bad_times_never_remind(self):
        self.assertEqual(night("2026-11-18T23:00", "nope", "06:00"), "")
        self.assertEqual(night("2026-11-18T23:00", "22:00", "22:00"), "")

    def test_due_respects_switch_skip_and_snooze(self):
        self.assertTrue(due("2026-11-18T22:10", {}, {}))
        self.assertFalse(due("2026-11-18T22:10", {"enabled": False}, {}))
        self.assertFalse(due("2026-11-19T01:00", {}, {"skippedNight": "2026-11-18"}))
        self.assertTrue(due("2026-11-19T22:10", {}, {"skippedNight": "2026-11-18"}))
        later = node_eval(BEDTIME, "new Date('2026-11-18T22:20').getTime()")
        self.assertFalse(due("2026-11-18T22:10", {}, {"snoozedUntil": later}))
        self.assertTrue(due("2026-11-18T22:25", {}, {"snoozedUntil": later}))


if __name__ == "__main__":
    unittest.main()
