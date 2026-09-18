"""Tests for the certificate synthesizer.

The synthesizer is not trusted by Lean, so these tests are not what makes the
results correct: `LyapCert/Examples.lean` is re-checked by the kernel either
way. What they buy is that the solver keeps producing certificates that pass,
and that the Python model of the algebra agrees with the Lean model, which is
what stops the two from drifting apart.
"""

from __future__ import annotations

import json
import random
import subprocess
import unittest
from fractions import Fraction
from pathlib import Path

from lyapcert.codegen import render_module, trajectory
from lyapcert.exact import (
    IDENTITY, Certificate, apply_int, check_certificate, compose_quad, eval_quad,
    is_pd, is_psd, mat, matmul, quad_of_sos, scale, solve_discrete_lyapunov,
    sos_rational, sub, synthesize, synthesize_any, synthesize_nonexpansive, transpose,
)

ROOT = Path(__file__).resolve().parents[2]
SYSTEMS = ROOT / "examples" / "systems.json"
GENERATED = ROOT / "LyapCert" / "Examples.lean"

AGC = [["4/5", "-1/5"], ["1/10", "9/10"]]


def load_specs() -> list[dict]:
    return json.loads(SYSTEMS.read_text())["systems"]


def random_stable(rng: random.Random):
    """A random 2x2 rational matrix with both eigenvalues strictly inside the
    unit circle, built from a characteristic polynomial in the stability
    triangle so the test never depends on luck."""
    while True:
        det = Fraction(rng.randint(-80, 80), 100)
        tr = Fraction(rng.randint(-160, 160), 100)
        # Jury conditions for a 2x2 discrete system
        if abs(det) < 1 and abs(tr) < 1 + det:
            break
    # companion form has this characteristic polynomial
    return [[0, 1], [-det, tr]]


class TestSolver(unittest.TestCase):
    def test_lyapunov_equation_is_solved_exactly(self) -> None:
        rng = random.Random(11)
        for _ in range(200):
            A = mat(random_stable(rng))
            P = solve_discrete_lyapunov(A)
            self.assertIsNotNone(P)
            residual = sub(matmul(matmul(transpose(A), P), A), P)
            self.assertEqual(residual, scale(Fraction(-1), IDENTITY))
            self.assertTrue(is_pd(P))

    def test_sos_decomposition_reproduces_the_form(self) -> None:
        rng = random.Random(5)
        checked = 0
        for _ in range(500):
            m11 = Fraction(rng.randint(0, 20))
            m12 = Fraction(rng.randint(-20, 20), rng.randint(1, 4))
            m22 = Fraction(rng.randint(0, 20))
            M = ((m11, m12), (m12, m22))
            if not is_psd(M):
                continue
            checked += 1
            terms = sos_rational(M)
            for x, y in [(1, 0), (0, 1), (3, -2), (-5, 7)]:
                lhs = m11 * x * x + 2 * m12 * x * y + m22 * y * y
                rhs = sum(c * (a * x + b * y) ** 2 for c, a, b in terms)
                self.assertEqual(lhs, rhs)
        self.assertGreater(checked, 100)

    def test_rejects_unstable_systems(self) -> None:
        for A in ([[Fraction(3, 2), 0], [0, Fraction(1, 2)]], [[2, 0], [0, 0]], [[1, 1], [0, 1]]):
            with self.assertRaises(ValueError):
                synthesize_any(A, "unstable")

    def test_marginal_route_handles_the_lossless_tank(self) -> None:
        cert = synthesize_nonexpansive([[0, -1], [1, 0]], "rotation")
        self.assertEqual(cert.num, cert.den)
        self.assertEqual(cert.S_sos, [])
        self.assertTrue(check_certificate(cert))


class TestCertificates(unittest.TestCase):
    def test_example_systems_all_certify(self) -> None:
        for spec in load_specs():
            cert = synthesize_any(spec["A"], spec["name"])
            self.assertTrue(check_certificate(cert), spec["name"])

    def test_decay_holds_at_sampled_states(self) -> None:
        """The Lean theorem covers every state; this checks the Python model
        agrees at a few thousand of them."""
        rng = random.Random(7)
        for spec in load_specs():
            cert = synthesize_any(spec["A"], spec["name"])
            Q = quad_of_sos(cert.P_sos)
            for _ in range(500):
                v = (rng.randint(-500, 500), rng.randint(-500, 500))
                Vv = eval_quad(Q, v)
                self.assertGreaterEqual(Vv, 0)
                VBv = eval_quad(Q, apply_int(cert.B, v))
                self.assertLessEqual(cert.den * VBv, cert.num * Vv)

    def test_envelope_holds_along_trajectories(self) -> None:
        rng = random.Random(13)
        for spec in load_specs():
            cert = synthesize_any(spec["A"], spec["name"])
            Q = quad_of_sos(cert.P_sos)
            for _ in range(20):
                v0 = (rng.randint(-50, 50), rng.randint(-50, 50))
                v, V0 = v0, eval_quad(Q, v0)
                for k in range(1, 9):
                    v = apply_int(cert.B, v)
                    self.assertLessEqual(cert.den**k * eval_quad(Q, v), cert.num**k * V0)

    def test_random_stable_systems_certify(self) -> None:
        rng = random.Random(1999)
        for _ in range(60):
            A = random_stable(rng)
            cert = synthesize_any(A, "random")
            self.assertTrue(check_certificate(cert))
            self.assertLess(cert.true_rate, 1)

    def test_rate_is_above_the_theoretical_floor(self) -> None:
        """V can decay no faster than the square of the spectral radius, so the
        certified rate must sit above |lambda|^2."""
        cert = synthesize(AGC, "agc")
        self.assertGreaterEqual(cert.true_rate, Fraction(74, 100))
        self.assertLess(cert.true_rate, 1)

    def test_compose_matches_matrix_pullback(self) -> None:
        """compose_quad is the formula Lean uses; check it against B^T P B."""
        rng = random.Random(3)
        for _ in range(500):
            B = ((rng.randint(-9, 9), rng.randint(-9, 9)), (rng.randint(-9, 9), rng.randint(-9, 9)))
            Q = (rng.randint(-9, 9), rng.randint(-9, 9), rng.randint(-9, 9))
            composed = compose_quad(Q, B)
            for x, y in [(1, 0), (0, 1), (2, 3), (-4, 5)]:
                self.assertEqual(eval_quad(composed, (x, y)), eval_quad(Q, apply_int(B, (x, y))))

    def test_deadbeat_reaches_zero(self) -> None:
        cert = synthesize_any([[0, 1], [0, 0]], "deadbeat")
        traj = trajectory(cert, (12, 5), 3)
        self.assertEqual(traj[2][1], 0)


class TestCodegen(unittest.TestCase):
    def test_generated_file_is_current(self) -> None:
        items = [(synthesize_any(s["A"], s["name"]), s) for s in load_specs()]
        self.assertEqual(render_module(items), GENERATED.read_text())

    def test_generated_file_has_no_sorry(self) -> None:
        self.assertNotIn("sorry", GENERATED.read_text())

    def test_generated_lean_typechecks(self) -> None:
        if subprocess.run(["which", "lake"], capture_output=True).returncode != 0:
            self.skipTest("lake not on PATH")
        if not (ROOT / ".lake" / "build").exists():
            self.skipTest("LyapCert not built; run lake build first")
        r = subprocess.run(
            ["lake", "env", "lean", str(GENERATED)], cwd=ROOT, capture_output=True, text=True
        )
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
