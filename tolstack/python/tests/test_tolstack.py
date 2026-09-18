"""Tests for the Python stack-up checker.

Two kinds of test here. The parity tests pin the Python numbers to values the
Lean kernel has proved (`TolStack.Examples`), so a change to this module that
breaks agreement with the formalization fails immediately. The property tests
are randomized checks of the same statements the Lean theorems make, which is
how you notice if the two models have drifted apart in a case the fixed example
does not reach.
"""

from __future__ import annotations

import json
import random
import subprocess
import unittest
from pathlib import Path

from tolstack.io import load_stack, parse_stack, stack_to_lean
from tolstack.model import Dim, Stack, Term, mm, report, sample

ROOT = Path(__file__).resolve().parents[2]
EXAMPLE = ROOT / "examples" / "axial_gap.json"
GOLDEN = Path(__file__).parent / "golden" / "axial_gap_report.txt"


def load_example() -> tuple[Stack, int, int]:
    return load_stack(EXAMPLE)


def random_stack(rng: random.Random, n: int | None = None) -> Stack:
    n = n or rng.randint(1, 6)
    terms = []
    for i in range(n):
        nominal = rng.randint(0, 60000)
        low = -rng.randint(0, 200)
        up = rng.randint(0, 200)
        terms.append(
            Term(rng.choice("+-"), Dim(nominal=nominal, low_dev=low, up_dev=up, label=f"d{i}"))
        )
    return Stack(terms, name="random")



def tighten(t: Term, rng: random.Random) -> Term:
    """A term with the same nominal and direction but a band no wider."""
    low = t.dim.low_dev + rng.randint(0, -t.dim.low_dev) if t.dim.low_dev < 0 else t.dim.low_dev
    up = t.dim.up_dev - rng.randint(0, t.dim.up_dev) if t.dim.up_dev > 0 else t.dim.up_dev
    if low > up:
        low = up = (low + up) // 2
    return Term(t.sign, Dim(nominal=t.dim.nominal, low_dev=low, up_dev=up, label=t.dim.label))


class TestParityWithLean(unittest.TestCase):
    """Values proved in TolStack/Examples.lean by kernel computation."""

    def setUp(self) -> None:
        self.stack, self.lo, self.hi = load_example()

    def test_limits(self) -> None:
        # theorem axialGap_bounds : wcLo = 320 ∧ wcHi = 590
        self.assertEqual(self.stack.wc_lo, 320)
        self.assertEqual(self.stack.wc_hi, 590)

    def test_nominal(self) -> None:
        # theorem axialGap_nominal : nominal = 400
        self.assertEqual(self.stack.nominal, 400)

    def test_spread(self) -> None:
        # theorem wcHi_sub_wcLo : wcHi - wcLo = wcWidth
        self.assertEqual(self.stack.wc_hi - self.stack.wc_lo, self.stack.wc_width)
        self.assertEqual(self.stack.wc_width, 270)

    def test_worst_build(self) -> None:
        # theorem axialGap_worst_build : argLo = [37000, 15030, 20050, 1600]
        self.assertEqual(self.stack.arg_lo, [37000, 15030, 20050, 1600])
        self.assertEqual(self.stack.eval(self.stack.arg_lo), 320)

    def test_verdicts(self) -> None:
        self.assertTrue(self.stack.fits_within(250, 600))
        self.assertFalse(self.stack.fits_within(350, 550))
        self.assertTrue(self.stack.no_interference())

    def test_report_matches_lean_output(self) -> None:
        self.assertEqual(report(self.stack, self.lo, self.hi), GOLDEN.read_text())


class TestSoundnessProperties(unittest.TestCase):
    """Randomized analogues of the Lean soundness/completeness theorems."""

    def test_every_build_inside_worst_case(self) -> None:
        # theorem eval_mem_worstCase
        rng = random.Random(20260728)
        for _ in range(200):
            s = random_stack(rng)
            for _ in range(50):
                xs = sample(s, rng)
                self.assertTrue(s.realizes(xs))
                self.assertLessEqual(s.wc_lo, s.eval(xs))
                self.assertLessEqual(s.eval(xs), s.wc_hi)

    def test_extremes_are_attained(self) -> None:
        # theorems wcLo_attained / wcHi_attained: the interval is tight
        rng = random.Random(7)
        for _ in range(500):
            s = random_stack(rng)
            self.assertTrue(s.realizes(s.arg_lo))
            self.assertTrue(s.realizes(s.arg_hi))
            self.assertEqual(s.eval(s.arg_lo), s.wc_lo)
            self.assertEqual(s.eval(s.arg_hi), s.wc_hi)

    def test_check_is_complete(self) -> None:
        # theorem fitsWithin_complete: a rejection always comes with a witness
        rng = random.Random(11)
        for _ in range(500):
            s = random_stack(rng)
            lo = s.nominal - rng.randint(0, 300)
            hi = s.nominal + rng.randint(0, 300)
            if not s.fits_within(lo, hi):
                witness = s.arg_lo if s.wc_lo < lo else s.arg_hi
                value = s.eval(witness)
                self.assertTrue(s.realizes(witness))
                self.assertFalse(lo <= value <= hi)

    def test_tightening_preserves_a_pass(self) -> None:
        # theorem refines_fitsWithin
        rng = random.Random(1993)
        for _ in range(500):
            s = random_stack(rng)
            lo, hi = s.wc_lo, s.wc_hi
            self.assertTrue(s.fits_within(lo, hi))
            tightened = Stack([tighten(t, rng) for t in s])
            self.assertTrue(tightened.wf)
            self.assertTrue(tightened.fits_within(lo, hi))


class TestRSS(unittest.TestCase):
    def test_rss_never_wider_than_worst_case(self) -> None:
        # theorem rssSq_le_wcWidth_sq
        rng = random.Random(4)
        for _ in range(1000):
            s = random_stack(rng)
            self.assertLessEqual(s.rss_sq, s.wc_width * s.wc_width)

    def test_rss_is_not_a_bound(self) -> None:
        # theorem rss_check_unsound: four 1.000 ±0.100 parts against ±0.200
        part = Dim(nominal=1000, low_dev=-100, up_dev=100, label="part")
        s = Stack([Term("+", part) for _ in range(4)], name="four parts")
        self.assertTrue(s.rss_fits_within(3800, 4200))
        self.assertFalse(s.fits_within(3800, 4200))
        build = s.arg_hi
        self.assertTrue(s.realizes(build))
        self.assertEqual(s.eval(build), 4400)

    def test_worst_case_pass_implies_rss_pass(self) -> None:
        # theorem fitsWithin_imp_rssFitsWithin
        rng = random.Random(5)
        for _ in range(1000):
            s = random_stack(rng)
            lo = s.wc_lo - rng.randint(0, 50)
            hi = s.wc_hi + rng.randint(0, 50)
            if s.fits_within(lo, hi):
                self.assertTrue(s.rss_fits_within(lo, hi))


class TestIO(unittest.TestCase):
    def test_rejects_inverted_band(self) -> None:
        data = json.loads(EXAMPLE.read_text())
        data["terms"][0]["upDev"] = -10
        with self.assertRaises(ValueError):
            parse_stack(data)

    def test_rejects_unknown_units(self) -> None:
        data = json.loads(EXAMPLE.read_text())
        data["units"] = "mm"
        with self.assertRaises(ValueError):
            parse_stack(data)

    def test_codegen_carries_the_computed_numbers(self) -> None:
        s, lo, hi = load_example()
        src = stack_to_lean(s, lo, hi)
        self.assertIn("axialGap.wcLo = 320 ∧ axialGap.wcHi = 590", src)
        self.assertIn("fitsWithin_sound", src)
        self.assertNotIn("sorry", src)


class TestGeneratedLeanCompiles(unittest.TestCase):
    """End-to-end: JSON -> Lean -> kernel check. Skipped when Lean is absent."""

    def test_generated_module_typechecks(self) -> None:
        if subprocess.run(["which", "lake"], capture_output=True).returncode != 0:
            self.skipTest("lake not on PATH")
        if not (ROOT / ".lake" / "build").exists():
            self.skipTest("TolStack not built; run lake build first")
        s, lo, hi = load_example()
        out = Path("/tmp/tolstack_gen_test.lean")
        out.write_text(stack_to_lean(s, lo, hi))
        r = subprocess.run(
            ["lake", "env", "lean", str(out)], cwd=ROOT, capture_output=True, text=True
        )
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertNotIn("sorry", r.stdout)


class TestFormatting(unittest.TestCase):
    def test_mm(self) -> None:
        self.assertEqual(mm(0), "0.000")
        self.assertEqual(mm(5), "0.005")
        self.assertEqual(mm(50), "0.050")
        self.assertEqual(mm(1600), "1.600")
        self.assertEqual(mm(-320), "-0.320")
        self.assertEqual(mm(37050), "37.050")


if __name__ == "__main__":
    unittest.main(verbosity=2)
