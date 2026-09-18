"""Tests for the carbon-aware scheduler.

The strongest test here is `test_certified_beats_brute_force`: on small
instances it enumerates *every* schedule of the right length and confirms the
certified one is minimal. That is the same claim the Lean theorem makes, checked
the dumb way, which is a good way to notice if the two ever disagree.
"""

from __future__ import annotations

import itertools
import json
import random
import subprocess
import unittest
from pathlib import Path

from carbonsched.codegen import render_module
from carbonsched.model import (
    Schedule, cost, count, earliest, fixed_hours, schedule, spread, sub, window,
)

ROOT = Path(__file__).resolve().parents[2]
SCENARIOS = ROOT / "examples" / "scenarios.json"
GENERATED = ROOT / "CarbonSched" / "Examples.lean"


def load_specs() -> list[dict]:
    return json.loads(SCENARIOS.read_text())["scenarios"]


def brute_force_min(profile, feasible, slots) -> int:
    allowed = [t for t, f in enumerate(feasible) if f]
    best = None
    for combo in itertools.combinations(allowed, slots):
        c = sum(profile[t] for t in combo)
        best = c if best is None else min(best, c)
    return best


class TestOptimality(unittest.TestCase):
    def test_certified_beats_brute_force(self) -> None:
        """Exhaustive check against every alternative schedule."""
        rng = random.Random(4242)
        for _ in range(300):
            n = rng.randint(3, 11)
            profile = [rng.randint(0, 600) for _ in range(n)]
            release = rng.randint(0, n - 1)
            deadline = rng.randint(release + 1, n)
            feasible = window(n, release, deadline)
            allowed = sum(feasible)
            slots = rng.randint(1, allowed)
            s = schedule(profile, feasible, slots)
            self.assertTrue(s.certified())
            self.assertEqual(s.cost, brute_force_min(profile, feasible, slots))

    def test_threshold_certificate_is_valid(self) -> None:
        """The emitted threshold satisfies both halves of the Lean check."""
        rng = random.Random(7)
        for _ in range(2000):
            n = rng.randint(1, 14)
            profile = [rng.randint(-50, 600) for _ in range(n)]
            feasible = [rng.random() < 0.7 for _ in range(n)]
            allowed = sum(feasible)
            if allowed == 0:
                continue
            slots = rng.randint(0, allowed)
            s = schedule(profile, feasible, slots)
            self.assertTrue(s.certified())
            for b, f, c in zip(s.mask, s.feasible, s.profile):
                if b:
                    self.assertLessEqual(c, s.theta)
                elif f:
                    self.assertGreaterEqual(c, s.theta)

    def test_schedule_respects_the_window(self) -> None:
        rng = random.Random(19)
        for _ in range(500):
            n = rng.randint(2, 20)
            profile = [rng.randint(0, 600) for _ in range(n)]
            release = rng.randint(0, n - 1)
            deadline = rng.randint(release + 1, n)
            feasible = window(n, release, deadline)
            slots = rng.randint(1, sum(feasible))
            s = schedule(profile, feasible, slots)
            self.assertTrue(sub(s.mask, s.feasible))
            self.assertEqual(count(s.mask), slots)
            for t, b in enumerate(s.mask):
                if b:
                    self.assertTrue(release <= t < deadline)

    def test_infeasible_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            schedule([10, 20, 30], window(3, 0, 2), 3)
        with self.assertRaises(ValueError):
            schedule([10, 20], [True, True, True], 1)


class TestBounds(unittest.TestCase):
    def test_online_ratio_holds(self) -> None:
        """lo * cost(any) <= hi * cost(optimal), the cleared-denominator form."""
        rng = random.Random(31)
        for _ in range(1000):
            n = rng.randint(2, 10)
            profile = [rng.randint(1, 600) for _ in range(n)]
            feasible = [True] * n
            slots = rng.randint(1, n)
            s = schedule(profile, feasible, slots)
            lo, hi = spread(profile, feasible)
            for _ in range(5):
                picks = rng.sample(range(n), slots)
                rival = [t in picks for t in range(n)]
                self.assertLessEqual(lo * cost(rival, profile), hi * s.cost)

    def test_ratio_is_tight_on_the_witness(self) -> None:
        """The two-slot adversarial instance from CarbonSched/Bounds.lean."""
        lo, hi = 100, 550
        profile = [hi, lo]
        online, offline = [True, False], [False, True]
        self.assertEqual(cost(online, profile), hi)
        self.assertEqual(cost(offline, profile), lo)
        self.assertEqual(lo * cost(online, profile), hi * cost(offline, profile))

    def test_savings_are_never_negative(self) -> None:
        for spec in load_specs():
            profile = [int(x) for x in spec["profile"]]
            n = len(profile)
            w = spec.get("window", {})
            feasible = window(n, int(w.get("release", 0)), int(w.get("deadline", n)))
            slots = int(spec["slots"])
            s = schedule(profile, feasible, slots, spec["name"])
            for b in spec.get("baselines", []):
                if b["kind"] == "earliest":
                    base = earliest(feasible, slots)
                else:
                    base = fixed_hours(n, b["hours"])
                self.assertEqual(count(base), slots, spec["name"])
                self.assertGreaterEqual(cost(base, profile), s.cost)

    def test_flat_profile_saves_almost_nothing(self) -> None:
        """A sanity floor: no carbon signal, no meaningful saving."""
        spec = next(s for s in load_specs() if s["name"] == "flat profile")
        profile = [int(x) for x in spec["profile"]]
        feasible = window(len(profile))
        s = schedule(profile, feasible, int(spec["slots"]))
        base = earliest(feasible, int(spec["slots"]))
        b = cost(base, profile)
        self.assertLess(100.0 * (b - s.cost) / b, 1.0)


class TestCodegen(unittest.TestCase):
    def _items(self):
        items = []
        for spec in load_specs():
            profile = [int(x) for x in spec["profile"]]
            n = len(profile)
            w = spec.get("window", {})
            feasible = window(n, int(w.get("release", 0)), int(w.get("deadline", n)))
            slots = int(spec["slots"])
            s = schedule(profile, feasible, slots, spec["name"])
            baselines = {}
            for b in spec.get("baselines", []):
                if b["kind"] == "earliest":
                    baselines[b.get("name", "run now")] = earliest(feasible, slots)
                else:
                    baselines[b.get("name", "fixed hours")] = fixed_hours(n, b["hours"])
            items.append((s, spec, baselines))
        return items

    def test_generated_file_is_current(self) -> None:
        self.assertEqual(render_module(self._items()), GENERATED.read_text())

    def test_generated_file_has_no_sorry(self) -> None:
        self.assertNotIn("sorry", GENERATED.read_text())

    def test_generated_lean_typechecks(self) -> None:
        if subprocess.run(["which", "lake"], capture_output=True).returncode != 0:
            self.skipTest("lake not on PATH")
        if not (ROOT / ".lake" / "build").exists():
            self.skipTest("CarbonSched not built; run lake build first")
        r = subprocess.run(
            ["lake", "env", "lean", str(GENERATED)], cwd=ROOT, capture_output=True, text=True
        )
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
