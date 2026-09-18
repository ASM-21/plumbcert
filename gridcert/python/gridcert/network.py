"""Exact DC power flow, PTDFs and LODFs in rational arithmetic.

No floating point anywhere in the certificate path. Every sensitivity is a
`Fraction`, and what gets handed to Lean is that fraction cleared to integers
together with the angle vectors that prove it, so Lean can re-derive the row
instead of trusting this module.

Susceptances are integers by construction (see the study system: reactances are
rounded so that 1/x is a whole number), which keeps the certificates small
enough to read.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from fractions import Fraction
from typing import Sequence


@dataclass(frozen=True)
class Line:
    src: int
    dst: int
    susc: int          # 1/x, integer
    name: str = ""
    rating: int = 0    # MW


@dataclass
class Network:
    buses: list[str]
    lines: list[Line]
    slack: int = 0

    @property
    def n(self) -> int:
        return len(self.buses)

    def line_index(self, name: str) -> int:
        for i, l in enumerate(self.lines):
            if l.name == name:
                return i
        raise KeyError(f"no line named {name!r}")

    def b_matrix(self) -> list[list[Fraction]]:
        """Nodal susceptance matrix, exact."""
        n = self.n
        B = [[Fraction(0) for _ in range(n)] for _ in range(n)]
        for l in self.lines:
            b = Fraction(l.susc)
            B[l.src][l.src] += b
            B[l.dst][l.dst] += b
            B[l.src][l.dst] -= b
            B[l.dst][l.src] -= b
        return B

    def inj_at(self, theta: Sequence, bus: int):
        """Net injection at a bus, from the same formula Lean uses."""
        total = 0
        for l in self.lines:
            f = l.susc * (theta[l.src] - theta[l.dst])
            if l.src == bus:
                total += f
            if l.dst == bus:
                total -= f
        return total

    def flow(self, theta: Sequence, line: int):
        l = self.lines[line]
        return l.susc * (theta[l.src] - theta[l.dst])


def solve_exact(A: list[list[Fraction]], rhs: list[Fraction]) -> list[Fraction] | None:
    """Gauss-Jordan over the rationals."""
    n = len(A)
    M = [row[:] + [rhs[i]] for i, row in enumerate(A)]
    for i in range(n):
        piv = next((r for r in range(i, n) if M[r][i] != 0), None)
        if piv is None:
            return None
        M[i], M[piv] = M[piv], M[i]
        inv = Fraction(1) / M[i][i]
        M[i] = [x * inv for x in M[i]]
        for r in range(n):
            if r != i and M[r][i] != 0:
                f = M[r][i]
                M[r] = [x - f * y for x, y in zip(M[r], M[i])]
    return [M[i][n] for i in range(n)]


def unit_angles(net: Network, bus: int) -> list[Fraction]:
    """Angles for a unit injection at `bus` withdrawn at the slack.

    Returns the full angle vector with the slack angle pinned to zero.
    """
    n = net.n
    keep = [i for i in range(n) if i != net.slack]
    B = net.b_matrix()
    Ared = [[B[i][j] for j in keep] for i in keep]
    rhs = [Fraction(1) if i == bus else Fraction(0) for i in keep]
    sol = solve_exact(Ared, rhs)
    if sol is None:
        raise ValueError("reduced susceptance matrix is singular: network is not connected")
    theta = [Fraction(0)] * n
    for idx, i in enumerate(keep):
        theta[i] = sol[idx]
    return theta


def ptdf_row(net: Network, line: int) -> list[Fraction]:
    """Sensitivity of one line's flow to injection at each bus, exact."""
    return [net.flow(unit_angles(net, i), line) if i != net.slack else Fraction(0)
            for i in range(net.n)]


def lodf(net: Network, monitored: int, outaged: int) -> Fraction:
    """Line outage distribution factor: fraction of the outaged line's
    pre-contingency flow that lands on the monitored line."""
    a_m = ptdf_row(net, monitored)
    a_o = ptdf_row(net, outaged)
    k = net.lines[outaged]
    num = a_m[k.src] - a_m[k.dst]
    den = 1 - (a_o[k.src] - a_o[k.dst])
    if den == 0:
        raise ValueError("outaging this line islands the network")
    return num / den


def lcm_denoms(values: Sequence[Fraction]) -> int:
    out = 1
    for v in values:
        out = out * v.denominator // math.gcd(out, v.denominator)
    return out


@dataclass
class RowCertificate:
    """An integer PTDF row plus the angle vectors that prove it."""

    line: int
    line_name: str
    scale: int                       # K: integer row / K is the true PTDF
    row: list[int]                   # K * PTDF
    angles: list[list[int]]          # per bus, K-scaled unit-injection angles
    exact: list[Fraction]


def certify_row(net: Network, line: int) -> RowCertificate:
    """Build the integer row and the angle witnesses Lean will re-check."""
    thetas = [unit_angles(net, i) for i in range(net.n)]
    exact = [net.flow(thetas[i], line) if i != net.slack else Fraction(0)
             for i in range(net.n)]
    flat = [x for th in thetas for x in th] + exact
    K = lcm_denoms(flat)
    angles = [[int(x * K) for x in th] for th in thetas]
    row = [int(x * K) for x in exact]
    # every angle witness must reproduce its unit injection exactly
    for i, th in enumerate(angles):
        if i == net.slack:
            continue
        for j in range(net.n):
            expected = K if j == i else 0
            if j == net.slack:
                expected = -K
            if net.inj_at(th, j) != expected:
                raise AssertionError(f"angle witness for bus {i} fails at bus {j}")
    return RowCertificate(line=line, line_name=net.lines[line].name, scale=K,
                          row=row, angles=angles, exact=exact)


def solve_dispatch(net: Network, p: Sequence[int]) -> list[Fraction]:
    """Exact DC angles for a dispatch, slack pinned to zero.

    The slack entry of `p` is ignored: whatever the other buses inject, the
    slack absorbs. Use `slack_injection` to recover what it absorbed.
    """
    keep = [i for i in range(net.n) if i != net.slack]
    B = net.b_matrix()
    Ared = [[B[i][j] for j in keep] for i in keep]
    rhs = [Fraction(p[i]) for i in keep]
    sol = solve_exact(Ared, rhs)
    if sol is None:
        raise ValueError("reduced susceptance matrix is singular: the network is islanded")
    theta = [Fraction(0)] * net.n
    for idx, i in enumerate(keep):
        theta[i] = sol[idx]
    return theta


def slack_injection(net: Network, p: Sequence[int]) -> int:
    return -sum(p[i] for i in range(net.n) if i != net.slack)


def balanced(net: Network, p: Sequence[int]) -> list[int]:
    """The dispatch with the slack entry set to what it actually absorbs."""
    out = list(p)
    out[net.slack] = slack_injection(net, p)
    return out


def without(net: Network, line: int) -> Network:
    return Network(buses=list(net.buses),
                   lines=[l for i, l in enumerate(net.lines) if i != line],
                   slack=net.slack)
