"""Tests for the DC screening study.

The Lean side re-derives every sensitivity row from the network equations, so
these tests are not what makes the results correct. What they buy is that the
Python model agrees with the Lean model, that the solver keeps producing rows
Lean accepts, and that the LODF the report shows a planner is consistent with
the row the certificate actually uses.
"""

from __future__ import annotations

import itertools
import random
import subprocess
import unittest
from fractions import Fraction
from pathlib import Path

from gridcert.codegen import render_module
from gridcert.network import (
    Line, Network, balanced, certify_row, lodf, ptdf_row, slack_injection,
    solve_dispatch, unit_angles, without,
)
from gridcert.study import (
    arg_lower, arg_upper, base_screen, contingency_screen, dot, lodf_consistent,
    lower, upper,
)
from gridcert.__main__ import load

ROOT = Path(__file__).resolve().parents[2]
STUDY = ROOT / "examples" / "study.json"
GENERATED = ROOT / "GridCert" / "Examples.lean"


def net_box_screens():
    return load(STUDY)


class TestNetwork(unittest.TestCase):
    def test_angle_witnesses_have_zero_residual(self) -> None:
        net, _, _ = net_box_screens()
        for i in range(net.n):
            if i == net.slack:
                continue
            th = unit_angles(net, i)
            for j in range(net.n):
                expected = Fraction(1) if j == i else Fraction(0)
                if j == net.slack:
                    expected = Fraction(-1)
                self.assertEqual(net.inj_at(th, j), expected, f"bus {i} residual at {j}")

    def test_ptdf_columns_sum_to_zero_across_lines_at_a_cut(self) -> None:
        """Injecting at a bus and withdrawing at the slack must conserve power."""
        net, _, _ = net_box_screens()
        for i in range(net.n):
            if i == net.slack:
                continue
            th = unit_angles(net, i)
            self.assertEqual(sum(net.inj_at(th, j) for j in range(net.n)), 0)

    def test_slack_ptdf_is_zero(self) -> None:
        net, _, _ = net_box_screens()
        for li in range(len(net.lines)):
            self.assertEqual(ptdf_row(net, li)[net.slack], 0)

    def test_superposition(self) -> None:
        """flow(sum of dispatches) = sum of flows, the property Lean proves."""
        net, _, _ = net_box_screens()
        rng = random.Random(11)
        for _ in range(200):
            p1 = [rng.randint(-300, 300) for _ in range(net.n)]
            p2 = [rng.randint(-300, 300) for _ in range(net.n)]
            ps = [a + b for a, b in zip(p1, p2)]
            t1, t2, ts = (solve_dispatch(net, p) for p in (p1, p2, ps))
            for li in range(len(net.lines)):
                self.assertEqual(net.flow(ts, li), net.flow(t1, li) + net.flow(t2, li))

    def test_ptdf_row_predicts_solved_flow(self) -> None:
        """The row is the real sensitivity, checked against a full solve."""
        net, _, _ = net_box_screens()
        rng = random.Random(3)
        for li in range(len(net.lines)):
            row = ptdf_row(net, li)
            for _ in range(50):
                p = [rng.randint(-400, 400) for _ in range(net.n)]
                p[net.slack] = slack_injection(net, p)
                th = solve_dispatch(net, p)
                self.assertEqual(net.flow(th, li), sum(a * x for a, x in zip(row, p)))

    def test_certify_row_is_integral_and_exact(self) -> None:
        net, _, _ = net_box_screens()
        for li in range(len(net.lines)):
            c = certify_row(net, li)
            for i, x in enumerate(c.exact):
                self.assertEqual(Fraction(c.row[i], c.scale), x)


class TestLODF(unittest.TestCase):
    def test_lodf_matches_the_outaged_network(self) -> None:
        net, _, _ = net_box_screens()
        for m, o in itertools.permutations([l.name for l in net.lines], 2):
            post = without(net, net.line_index(o))
            try:
                post.b_matrix()
                solve_dispatch(post, [0] * net.n)
            except ValueError:
                continue
            self.assertTrue(lodf_consistent(net, m, o), f"{m} with {o} out")

    def test_radial_outage_gives_unit_lodf(self) -> None:
        """Outaging D-E leaves E fed only by A-E, so the whole flow transfers."""
        net, _, _ = net_box_screens()
        self.assertEqual(lodf(net, net.line_index("A-E"), net.line_index("D-E")), 1)


class TestScreening(unittest.TestCase):
    def test_bounds_are_attained(self) -> None:
        rng = random.Random(7)
        for _ in range(2000):
            n = rng.randint(1, 6)
            row = [rng.randint(-500, 500) for _ in range(n)]
            box = []
            for _ in range(n):
                a = rng.randint(-400, 400)
                b = rng.randint(-400, 400)
                box.append((min(a, b), max(a, b)))
            self.assertEqual(dot(row, arg_upper(row, box)), upper(row, box))
            self.assertEqual(dot(row, arg_lower(row, box)), lower(row, box))

    def test_bounds_are_sound(self) -> None:
        rng = random.Random(13)
        for _ in range(1000):
            n = rng.randint(1, 5)
            row = [rng.randint(-500, 500) for _ in range(n)]
            box = []
            for _ in range(n):
                a, b = rng.randint(-400, 400), rng.randint(-400, 400)
                box.append((min(a, b), max(a, b)))
            for _ in range(20):
                p = [rng.randint(lo, hi) for lo, hi in box]
                self.assertLessEqual(dot(row, p), upper(row, box))
                self.assertGreaterEqual(dot(row, p), lower(row, box))

    def test_study_verdicts(self) -> None:
        _, _, screens = net_box_screens()
        got = {s.label: s.passes for s in screens}
        self.assertTrue(got["A-E base case"])
        self.assertTrue(got["A-E with D-E out"])
        self.assertTrue(got["A-D base case"])
        self.assertFalse(got["A-D with A-B out"])
        self.assertFalse(got["D-E base case"])

    def test_failing_screens_have_a_real_witness(self) -> None:
        net, box, screens = net_box_screens()
        for sc in screens:
            if sc.passes:
                continue
            w = sc.worst_dispatch()
            for x, (lo, hi) in zip(w, sc.box):
                self.assertTrue(lo <= x <= hi)
            self.assertGreater(abs(dot(sc.row, w)), sc.limit_scaled)

    def test_screen_row_predicts_the_physical_flow(self) -> None:
        """The certified row against a full solve of the relevant network."""
        net, box, screens = net_box_screens()
        rng = random.Random(5)
        for sc in screens:
            phys = sc.network if sc.network is not None else net
            li = sc.base.line
            for _ in range(30):
                p = [rng.randint(-400, 400) for _ in range(net.n)]
                p = balanced(phys, p)
                th = solve_dispatch(phys, p)
                self.assertEqual(
                    Fraction(dot(sc.row, p), sc.scale), phys.flow(th, li)
                )


class TestCodegen(unittest.TestCase):
    def test_generated_file_is_current(self) -> None:
        net, _, screens = net_box_screens()
        self.assertEqual(render_module(net, screens), GENERATED.read_text())

    def test_generated_file_has_no_sorry(self) -> None:
        self.assertNotIn("sorry", GENERATED.read_text())

    def test_generated_lean_typechecks(self) -> None:
        if subprocess.run(["which", "lake"], capture_output=True).returncode != 0:
            self.skipTest("lake not on PATH")
        if not (ROOT / ".lake" / "build").exists():
            self.skipTest("GridCert not built; run lake build first")
        r = subprocess.run(["lake", "env", "lean", str(GENERATED)], cwd=ROOT,
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
