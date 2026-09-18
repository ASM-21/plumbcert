"""Tests for the Python dimensional checker.

Parity tests pin Python's output to what the Lean kernel produced. Property
tests are randomized versions of the Lean theorems, which is how drift between
the two models gets caught in cases the fixed library does not reach.
"""

from __future__ import annotations

import random
import subprocess
import unittest
from pathlib import Path

from dimcert import units as u
from dimcert.dimension import BASES, ONE, Dimension, Rescale, separator
from dimcert.expr import (
    BinOp, Const, Equation, Expr, Pow, Sqrt, Sym, add, div, infer, mul, scale, sub,
)
from dimcert.formulas import LIBRARY, library_report
from dimcert.io import formulas_to_lean, load_formulas, parse_file

ROOT = Path(__file__).resolve().parents[2]
GOLDEN = Path(__file__).parent / "golden" / "library_report.txt"
EXAMPLE = ROOT / "examples" / "interconnection.json"


def random_dimension(rng: random.Random, *, square: bool = False) -> Dimension:
    step = 2 if square else 1
    return Dimension(*(step * rng.randint(-3, 3) for _ in BASES))


def random_rescale(rng: random.Random) -> Rescale:
    return Rescale(*(rng.randint(-3, 3) for _ in BASES))


def random_expr(rng: random.Random, depth: int = 3) -> Expr:
    """A random expression that always infers, so the soundness property has
    something to say about it."""
    if depth <= 0 or rng.random() < 0.25:
        return rng.choice([Sym(f"x{rng.randint(0, 9)}", random_dimension(rng)), Const()])
    kind = rng.choice(["mul", "div", "pow", "sqrt", "add", "sub"])
    if kind == "pow":
        return Pow(random_expr(rng, depth - 1), rng.randint(-3, 3))
    if kind == "sqrt":
        return Sqrt(Pow(random_expr(rng, depth - 1), 2))
    if kind in ("add", "sub"):
        side = random_expr(rng, depth - 1)
        return BinOp(kind, side, side)
    return BinOp(kind, random_expr(rng, depth - 1), random_expr(rng, depth - 1))


class TestParityWithLean(unittest.TestCase):
    def test_library_report_matches_lean(self) -> None:
        self.assertEqual(library_report(), GOLDEN.read_text())

    def test_expected_verdicts(self) -> None:
        for q in LIBRARY:
            if q.name.startswith("WRONG:"):
                self.assertFalse(q.checks, q.name)
            else:
                self.assertTrue(q.checks, q.name)

    def test_watts_plus_vars_is_the_known_blind_spot(self) -> None:
        # theorem apparentPowerSum_checks: dimensionally fine, physically wrong
        bad = next(q for q in LIBRARY if q.name.startswith("WRONG PHYSICS"))
        self.assertTrue(bad.checks)

    def test_units_identities(self) -> None:
        # the identities proved by decide in DimCert/Units.lean
        self.assertEqual(u.volt, u.watt / u.ampere)
        self.assertEqual(u.ohm, u.volt / u.ampere)
        self.assertEqual(u.watt, u.volt * u.ampere)
        self.assertEqual(u.farad, u.coulomb / u.volt)
        self.assertEqual((u.henry / u.farad).sqrt(), u.ohm)
        self.assertEqual(u.volt**2 / u.voltAmpere, u.ohm)
        self.assertEqual(u.watt, u.var)


class TestDimensionAlgebra(unittest.TestCase):
    def test_group_laws(self) -> None:
        rng = random.Random(3)
        for _ in range(2000):
            a, b, c = (random_dimension(rng) for _ in range(3))
            self.assertEqual((a * b) * c, a * (b * c))
            self.assertEqual(a * b, b * a)
            self.assertEqual(a * ONE, a)
            self.assertEqual(a * a.inv(), ONE)
            self.assertEqual(a / a, ONE)
            self.assertEqual(a**0, ONE)
            self.assertEqual(a**1, a)

    def test_pow_add(self) -> None:
        rng = random.Random(31)
        for _ in range(1000):
            a = random_dimension(rng)
            m, n = rng.randint(-4, 4), rng.randint(-4, 4)
            self.assertEqual(a ** (m + n), (a**m) * (a**n))

    def test_sqrt_is_a_square_root(self) -> None:
        # theorem sqrt?_sq
        rng = random.Random(17)
        for _ in range(1000):
            d = random_dimension(rng, square=True)
            root = d.sqrt()
            self.assertIsNotNone(root)
            self.assertEqual(root * root, d)

    def test_sqrt_refuses_odd_exponents(self) -> None:
        self.assertIsNone(u.volt.sqrt())
        self.assertIsNone(u.metre.sqrt())

    def test_decade_shift_is_a_homomorphism(self) -> None:
        # theorems decadeShift_mul / _div / _pow / _one
        rng = random.Random(23)
        for _ in range(2000):
            a, b = random_dimension(rng), random_dimension(rng)
            r = random_rescale(rng)
            n = rng.randint(-3, 3)
            self.assertEqual((a * b).decade_shift(r), a.decade_shift(r) + b.decade_shift(r))
            self.assertEqual((a / b).decade_shift(r), a.decade_shift(r) - b.decade_shift(r))
            self.assertEqual((a**n).decade_shift(r), n * a.decade_shift(r))
            self.assertEqual(ONE.decade_shift(r), 0)


class TestCheckerSoundness(unittest.TestCase):
    def test_scale_is_determined_by_dimension(self) -> None:
        # theorem Expr.scale_eq_of_infer, the headline result
        rng = random.Random(1861)
        checked = 0
        for _ in range(4000):
            e = random_expr(rng)
            d = infer(e)
            if d is None:
                continue
            checked += 1
            r = random_rescale(rng)
            self.assertEqual(scale(e, r), -d.decade_shift(r))
        self.assertGreater(checked, 3000)

    def test_dimensionless_is_unit_invariant(self) -> None:
        # theorem scale_eq_zero_of_dimensionless
        rng = random.Random(99)
        for _ in range(2000):
            e = random_expr(rng)
            if infer(e) != ONE:
                continue
            self.assertEqual(scale(e, random_rescale(rng)), 0)

    def test_consistent_equations_scale_together(self) -> None:
        # theorem Equation.scale_agree
        rng = random.Random(55)
        for _ in range(2000):
            e = random_expr(rng)
            if infer(e) is None:
                continue
            q = Equation("x", e, e)
            self.assertTrue(q.checks)
            r = random_rescale(rng)
            self.assertEqual(scale(q.lhs, r), scale(q.rhs, r))

    def test_every_mismatch_is_detectable(self) -> None:
        # theorem Equation.separator_detects
        rng = random.Random(404)
        for _ in range(4000):
            a, b = random_dimension(rng), random_dimension(rng)
            if a == b:
                continue
            r = separator(a, b)
            self.assertNotEqual(a.decade_shift(r), b.decade_shift(r))

    def test_library_failures_come_with_a_witness(self) -> None:
        for q in LIBRARY:
            if q.checks:
                continue
            r = q.counterexample_rescale()
            lhs, rhs = infer(q.lhs), infer(q.rhs)
            if lhs is None or rhs is None:
                self.assertIsNone(r)  # no dimension at all, nothing to separate
            else:
                self.assertIsNotNone(r)
                self.assertNotEqual(scale(q.lhs, r), scale(q.rhs, r))


class TestIO(unittest.TestCase):
    def test_example_file(self) -> None:
        eqs = load_formulas(EXAMPLE)
        self.assertEqual(len(eqs), 7)
        self.assertEqual(sum(1 for q in eqs if not q.checks), 1)

    def test_rejects_undeclared_symbol(self) -> None:
        with self.assertRaises(ValueError):
            parse_file({"symbols": {}, "formulas": [{"name": "x", "lhs": "V", "rhs": "1"}]})

    def test_rejects_unknown_unit(self) -> None:
        with self.assertRaises(ValueError):
            parse_file({"symbols": {"V": "furlong"}, "formulas": []})

    def test_rejects_unknown_operator(self) -> None:
        with self.assertRaises(ValueError):
            parse_file(
                {"symbols": {"V": "volt"}, "formulas": [{"name": "x", "lhs": ["log", "V"], "rhs": "V"}]}
            )

    def test_codegen_records_both_verdicts(self) -> None:
        src = formulas_to_lean(load_formulas(EXAMPLE))
        self.assertIn("checks = true", src)
        self.assertIn("checks = false", src)
        self.assertNotIn("sorry", src)


class TestGeneratedLeanCompiles(unittest.TestCase):
    def test_generated_module_typechecks(self) -> None:
        if subprocess.run(["which", "lake"], capture_output=True).returncode != 0:
            self.skipTest("lake not on PATH")
        if not (ROOT / ".lake" / "build").exists():
            self.skipTest("DimCert not built; run lake build first")
        out = Path("/tmp/dimcert_gen_test.lean")
        out.write_text(formulas_to_lean(load_formulas(EXAMPLE)))
        r = subprocess.run(
            ["lake", "env", "lean", str(out)], cwd=ROOT, capture_output=True, text=True
        )
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
