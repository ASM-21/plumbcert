"""Exact rational Lyapunov certificate synthesis for 2-state discrete systems.

Everything here is `Fraction` arithmetic. There is no floating point in the
certificate path, so what the solver claims and what Lean checks are the same
numbers. Floats appear only as a starting guess for the decay rate, and any
guess is then either verified exactly or rejected.

The pipeline:

1. Solve the discrete Lyapunov equation AᵀPA - P = -I exactly for symmetric P.
2. Find a rational decay rate ρ with AᵀPA ⪯ ρP, verified by an exact 2x2
   positive-semidefiniteness test (both diagonal entries and the determinant
   non-negative).
3. Clear denominators so the dynamics, P and the slack S are all integers, and
   decompose P and S into sums of squares by exact LDLᵀ.
4. Emit the certificate. Lean re-checks the identity from scratch.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from fractions import Fraction
from typing import Sequence

Mat = tuple[tuple[Fraction, Fraction], tuple[Fraction, Fraction]]


def mat(entries: Sequence[Sequence]) -> Mat:
    (a, b), (c, d) = entries
    return ((Fraction(a), Fraction(b)), (Fraction(c), Fraction(d)))


def transpose(M: Mat) -> Mat:
    return ((M[0][0], M[1][0]), (M[0][1], M[1][1]))


def matmul(M: Mat, N: Mat) -> Mat:
    return (
        (M[0][0] * N[0][0] + M[0][1] * N[1][0], M[0][0] * N[0][1] + M[0][1] * N[1][1]),
        (M[1][0] * N[0][0] + M[1][1] * N[1][0], M[1][0] * N[0][1] + M[1][1] * N[1][1]),
    )


def scale(c: Fraction, M: Mat) -> Mat:
    return ((c * M[0][0], c * M[0][1]), (c * M[1][0], c * M[1][1]))


def sub(M: Mat, N: Mat) -> Mat:
    return (
        (M[0][0] - N[0][0], M[0][1] - N[0][1]),
        (M[1][0] - N[1][0], M[1][1] - N[1][1]),
    )


IDENTITY: Mat = ((Fraction(1), Fraction(0)), (Fraction(0), Fraction(1)))


def is_psd(M: Mat) -> bool:
    """Exact PSD test for a symmetric 2x2 matrix."""
    assert M[0][1] == M[1][0], "not symmetric"
    return M[0][0] >= 0 and M[1][1] >= 0 and M[0][0] * M[1][1] - M[0][1] * M[1][0] >= 0


def is_pd(M: Mat) -> bool:
    assert M[0][1] == M[1][0], "not symmetric"
    return M[0][0] > 0 and M[0][0] * M[1][1] - M[0][1] * M[1][0] > 0


def solve_linear(rows: list[list[Fraction]]) -> list[Fraction] | None:
    """Exact Gaussian elimination on an augmented system."""
    n = len(rows)
    for i in range(n):
        pivot = next((r for r in range(i, n) if rows[r][i] != 0), None)
        if pivot is None:
            return None
        rows[i], rows[pivot] = rows[pivot], rows[i]
        inv = Fraction(1) / rows[i][i]
        rows[i] = [x * inv for x in rows[i]]
        for r in range(n):
            if r != i and rows[r][i] != 0:
                f = rows[r][i]
                rows[r] = [x - f * y for x, y in zip(rows[r], rows[i])]
    return [rows[i][n] for i in range(n)]


def solve_discrete_lyapunov(A: Mat) -> Mat | None:
    """Solve AᵀPA - P = -I for symmetric P. Returns None if singular."""
    # unknowns: p11, p12, p22
    At = transpose(A)

    def coeff(idx: int) -> Mat:
        basis = [
            ((Fraction(1), Fraction(0)), (Fraction(0), Fraction(0))),
            ((Fraction(0), Fraction(1)), (Fraction(1), Fraction(0))),
            ((Fraction(0), Fraction(0)), (Fraction(0), Fraction(1))),
        ][idx]
        return sub(matmul(matmul(At, basis), A), basis)

    cols = [coeff(i) for i in range(3)]
    rhs = [Fraction(-1), Fraction(0), Fraction(-1)]  # -I entries (11, 12, 22)
    rows = []
    for pos, r in zip([(0, 0), (0, 1), (1, 1)], rhs):
        rows.append([cols[i][pos[0]][pos[1]] for i in range(3)] + [r])
    sol = solve_linear(rows)
    if sol is None:
        return None
    p11, p12, p22 = sol
    return ((p11, p12), (p12, p22))


def spectral_radius_estimate(A: Mat) -> float:
    """Float estimate only, used to seed the exact rate search."""
    tr = float(A[0][0] + A[1][1])
    det = float(A[0][0] * A[1][1] - A[0][1] * A[1][0])
    disc = tr * tr - 4 * det
    if disc >= 0:
        r = max(abs((tr + math.sqrt(disc)) / 2), abs((tr - math.sqrt(disc)) / 2))
    else:
        r = math.sqrt(abs(det))
    return r


def find_rate(A: Mat, P: Mat, resolution: int = 10_000) -> Fraction | None:
    """Smallest rational ρ = n/resolution with AᵀPA ⪯ ρP, verified exactly."""
    APA = matmul(matmul(transpose(A), P), A)
    start = spectral_radius_estimate(A) ** 2
    n0 = max(0, int(start * resolution) - 2)
    for n in range(n0, resolution + 1):
        rho = Fraction(n, resolution)
        if is_psd(sub(scale(rho, P), APA)):
            return rho
    return None


def denominator_lcm(values: Sequence[Fraction]) -> int:
    out = 1
    for v in values:
        out = out * v.denominator // math.gcd(out, v.denominator)
    return out


def sos_rational(M: Mat) -> list[tuple[Fraction, int, int]]:
    """Write a PSD symmetric 2x2 form as a sum of squares with integer linear parts.

    Returns terms `(c, a, b)` meaning `c * (a x + b y)²`, whose sum equals
    `m11 x² + 2 m12 x y + m22 y²`. This is LDLᵀ with the denominators pushed
    into the (integer) linear forms, which keeps the coefficients small.
    """
    m11, m12, m22 = M[0][0], M[0][1], M[1][1]
    if not is_psd(M):
        raise ValueError("matrix is not positive semidefinite")
    if m11 == 0:
        return [] if m22 == 0 else [(m22, 0, 1)]
    ratio = m12 / m11
    ld, ln = ratio.denominator, ratio.numerator
    terms = [(m11 / (ld * ld), ld, ln)]
    d2 = m22 - m12 * m12 / m11
    if d2 != 0:
        terms.append((d2, 0, 1))
    return terms


@dataclass
class Certificate:
    """Everything Lean needs, all integers."""

    name: str
    q: int  # dynamics scale: the integer matrix is B = q*A
    B: tuple[tuple[int, int], tuple[int, int]]
    P_sos: list[tuple[int, int, int]]  # (coeff, a, b) meaning coeff*(a x + b y)^2
    S_sos: list[tuple[int, int, int]]
    num: int
    den: int
    rho: Fraction  # per-step decay of the true system
    A: Mat

    @property
    def true_rate(self) -> Fraction:
        """Decay factor per step of the true system x ↦ A x."""
        return Fraction(self.num, self.den * self.q * self.q)


def quad_of_sos(terms: Sequence[tuple[int, int, int]]) -> tuple[int, int, int]:
    """(q11, q12, q22) with q12 the full cross coefficient, matching Lean."""
    q11 = sum(c * a * a for c, a, _ in terms)
    q12 = sum(2 * c * a * b for c, a, b in terms)
    q22 = sum(c * b * b for c, _, b in terms)
    return q11, q12, q22


def compose_quad(Q: tuple[int, int, int], B: tuple[tuple[int, int], tuple[int, int]]):
    """Pull Q back along B, with the same formula Lean uses."""
    q11, q12, q22 = Q
    (a, b), (c, d) = B
    return (
        q11 * a * a + q12 * a * c + q22 * c * c,
        2 * q11 * a * b + q12 * (a * d + b * c) + 2 * q22 * c * d,
        q11 * b * b + q12 * b * d + q22 * d * d,
    )


def synthesize(A_entries: Sequence[Sequence], name: str = "system") -> Certificate:
    """Full pipeline. Raises ValueError when no certificate exists."""
    A = mat(A_entries)
    P = solve_discrete_lyapunov(A)
    if P is None or not is_pd(P):
        raise ValueError(
            "no positive definite solution to the Lyapunov equation: system is not stable"
        )
    rho = find_rate(A, P)
    if rho is None:
        raise ValueError("no rational decay rate found with this P")

    q = denominator_lcm([A[0][0], A[0][1], A[1][0], A[1][1]])
    B = ((int(A[0][0] * q), int(A[0][1] * q)), (int(A[1][0] * q), int(A[1][1] * q)))
    Bf = mat(B)

    # Decay on the scaled map: den * V(Bv) <= num * V(v), since V(Bv) = q² V(Av).
    num = rho.numerator * q * q
    den = rho.denominator
    g = math.gcd(num, den)
    num, den = num // g, den // g

    S = sub(scale(Fraction(num), P), scale(Fraction(den), matmul(matmul(transpose(Bf), P), Bf)))
    if not is_psd(S):
        raise ValueError("slack matrix is not PSD; the rate search returned an invalid rate")

    p_terms = sos_rational(P)
    s_terms = sos_rational(S)
    T = denominator_lcm([c for c, _, _ in p_terms] + [c for c, _, _ in s_terms])
    P_sos = [(int(c * T), a, b) for c, a, b in p_terms]
    S_sos = [(int(c * T), a, b) for c, a, b in s_terms]

    P_sos, S_sos = _reduce_common(P_sos, S_sos)
    return Certificate(
        name=name, q=q, B=B, P_sos=P_sos, S_sos=S_sos, num=num, den=den, rho=rho, A=A
    )


def _reduce_common(P_sos, S_sos):
    """Divide both forms by a common factor. The decay identity is homogeneous
    in the Lyapunov function, so this changes nothing that is claimed."""
    coeffs = [c for c, _, _ in P_sos] + [c for c, _, _ in S_sos]
    g = 0
    for c in coeffs:
        g = math.gcd(g, c)
    if g <= 1:
        return P_sos, S_sos
    return ([(c // g, a, b) for c, a, b in P_sos], [(c // g, a, b) for c, a, b in S_sos])


def synthesize_nonexpansive(A_entries: Sequence[Sequence], name: str = "system") -> Certificate:
    """Certificate for a marginally stable system, using V(v) = x² + y².

    The Lyapunov equation route needs strict stability, so a lossless
    oscillator or a pure delay line has no solution there. Those systems still
    have a perfectly good invariant envelope: the identity form works whenever
    BᵀB ⪯ I, which is exactly non-expansion in the Euclidean norm.
    """
    A = mat(A_entries)
    q = denominator_lcm([A[0][0], A[0][1], A[1][0], A[1][1]])
    if q != 1:
        raise ValueError("the non-expansive route needs an integer matrix")
    B = ((int(A[0][0]), int(A[0][1])), (int(A[1][0]), int(A[1][1])))
    Bf = mat(B)
    S = sub(IDENTITY, matmul(transpose(Bf), Bf))
    if not is_psd(S):
        raise ValueError("BᵀB is not inside the unit ball: no non-expansive certificate with V = x²+y²")
    p_terms = sos_rational(IDENTITY)
    s_terms = sos_rational(S)
    T = denominator_lcm([c for c, _, _ in p_terms] + [c for c, _, _ in s_terms])
    P_sos = [(int(c * T), a, b) for c, a, b in p_terms]
    S_sos = [(int(c * T), a, b) for c, a, b in s_terms]
    P_sos, S_sos = _reduce_common(P_sos, S_sos)
    return Certificate(
        name=name, q=1, B=B, P_sos=P_sos, S_sos=S_sos, num=1, den=1, rho=Fraction(1), A=A
    )


def synthesize_any(A_entries: Sequence[Sequence], name: str = "system") -> Certificate:
    """Strict route first, non-expansive route as a fallback."""
    try:
        return synthesize(A_entries, name)
    except ValueError as strict_error:
        try:
            return synthesize_nonexpansive(A_entries, name)
        except ValueError as marginal_error:
            raise ValueError(f"{strict_error}; and {marginal_error}") from None


def check_certificate(cert: Certificate) -> bool:
    """Re-check the identity the way Lean will, independently of synthesis."""
    PQ = quad_of_sos(cert.P_sos)
    SQ = quad_of_sos(cert.S_sos)
    lhs = tuple(cert.num * c for c in PQ)
    rhs = tuple(cert.den * c for c in compose_quad(PQ, cert.B))
    if tuple(l - r for l, r in zip(lhs, rhs)) != SQ:
        return False
    return (
        all(c >= 0 for c, _, _ in cert.P_sos)
        and all(c >= 0 for c, _, _ in cert.S_sos)
        and cert.den > 0
        and cert.num >= 0
    )


def eval_quad(Q: tuple[int, int, int], v: tuple[int, int]) -> int:
    return Q[0] * v[0] * v[0] + Q[1] * v[0] * v[1] + Q[2] * v[1] * v[1]


def apply_int(B: tuple[tuple[int, int], tuple[int, int]], v: tuple[int, int]) -> tuple[int, int]:
    return (B[0][0] * v[0] + B[0][1] * v[1], B[1][0] * v[0] + B[1][1] * v[1])
