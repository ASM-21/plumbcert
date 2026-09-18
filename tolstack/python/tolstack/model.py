"""Worst-case and RSS 1D tolerance stack-up, mirroring TolStack/Basic.lean.

All lengths are integers in micrometres. The integer choice is not cosmetic: it
is what lets the Lean side state theorems about the exact arithmetic this module
performs, with no floating point in the loop. The only float in the file is the
RSS spread, which is reported for information and never used for a pass/fail
decision (see `rss_fits_within`, which compares squares).
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Iterable, Iterator, Literal, Sequence

Sign = Literal["+", "-"]


@dataclass(frozen=True)
class Dim:
    """A toleranced linear dimension: nominal size with lower/upper deviations."""

    nominal: int
    low_dev: int
    up_dev: int
    label: str = ""

    @property
    def lo(self) -> int:
        return self.nominal + self.low_dev

    @property
    def hi(self) -> int:
        return self.nominal + self.up_dev

    @property
    def width(self) -> int:
        return self.up_dev - self.low_dev

    @property
    def wf(self) -> bool:
        """Band is not inverted. Mirrors `Dim.Wf`."""
        return self.low_dev <= self.up_dev

    def realizes(self, x: int) -> bool:
        return self.lo <= x <= self.hi


@dataclass(frozen=True)
class Term:
    """One signed entry in a stack chain."""

    sign: Sign
    dim: Dim

    def apply(self, x: int) -> int:
        return x if self.sign == "+" else -x

    @property
    def lo(self) -> int:
        return self.dim.lo if self.sign == "+" else -self.dim.hi

    @property
    def hi(self) -> int:
        return self.dim.hi if self.sign == "+" else -self.dim.lo

    @property
    def arg_lo(self) -> int:
        """Manufactured value attaining this term's least contribution."""
        return self.dim.lo if self.sign == "+" else self.dim.hi

    @property
    def arg_hi(self) -> int:
        return self.dim.hi if self.sign == "+" else self.dim.lo


class Stack:
    """A chain of signed toleranced dimensions closing on a gap."""

    def __init__(self, terms: Sequence[Term], name: str = "") -> None:
        self.terms = list(terms)
        self.name = name

    def __iter__(self) -> Iterator[Term]:
        return iter(self.terms)

    def __len__(self) -> int:
        return len(self.terms)

    # --- the quantities the Lean theorems are about -------------------------

    @property
    def wc_lo(self) -> int:
        return sum(t.lo for t in self.terms)

    @property
    def wc_hi(self) -> int:
        return sum(t.hi for t in self.terms)

    @property
    def nominal(self) -> int:
        return sum(t.apply(t.dim.nominal) for t in self.terms)

    @property
    def wc_width(self) -> int:
        return sum(t.dim.width for t in self.terms)

    @property
    def rss_sq(self) -> int:
        """Sum of squared band widths. The RSS spread is its square root."""
        return sum(t.dim.width * t.dim.width for t in self.terms)

    @property
    def rss_width(self) -> float:
        return math.sqrt(self.rss_sq)

    @property
    def wf(self) -> bool:
        return all(t.dim.wf for t in self.terms)

    @property
    def centered(self) -> bool:
        return all(t.dim.low_dev <= 0 <= t.dim.up_dev for t in self.terms)

    # --- checks -------------------------------------------------------------

    def eval(self, xs: Sequence[int]) -> int:
        if len(xs) != len(self.terms):
            raise ValueError(f"expected {len(self.terms)} values, got {len(xs)}")
        return sum(t.apply(x) for t, x in zip(self.terms, xs))

    def realizes(self, xs: Sequence[int]) -> bool:
        return len(xs) == len(self.terms) and all(
            t.dim.realizes(x) for t, x in zip(self.terms, xs)
        )

    def fits_within(self, lo: int, hi: int) -> bool:
        """Worst-case acceptance. Sound and complete (see Lean)."""
        return lo <= self.wc_lo and self.wc_hi <= hi

    def no_interference(self) -> bool:
        return 0 <= self.wc_lo

    def rss_fits_within(self, lo: int, hi: int) -> bool:
        """RSS acceptance, squared to stay in exact integers.

        Passing this is *not* a guarantee; `rss_check_unsound` in
        TolStack/Analysis.lean exhibits a counterexample.
        """
        w = hi - lo
        return self.rss_sq <= w * w

    def slack_lo(self, lo: int) -> int:
        return self.wc_lo - lo

    def slack_hi(self, hi: int) -> int:
        return hi - self.wc_hi

    def budget_remaining(self, lo: int, hi: int) -> int:
        return (hi - lo) - self.wc_width

    # --- witnesses ----------------------------------------------------------

    @property
    def arg_lo(self) -> list[int]:
        """The build attaining the worst-case low limit."""
        return [t.arg_lo for t in self.terms]

    @property
    def arg_hi(self) -> list[int]:
        return [t.arg_hi for t in self.terms]


def mm(x: int) -> str:
    """Micrometres to millimetres, three decimals. Mirrors `Examples.mm`."""
    neg = x < 0
    n = abs(x)
    whole, frac = divmod(n, 1000)
    return f"{'-' if neg else ''}{whole}.{frac:03d}"


def report(s: Stack, lo: int, hi: int) -> str:
    """Byte-for-byte the same report `TolStack.Examples.report` produces."""
    rows = "\n".join(
        f"  {t.sign} {t.dim.label}: {mm(t.dim.nominal)} [{mm(t.dim.lo)}, {mm(t.dim.hi)}]"
        for t in s
    )
    verdict = "PASS" if s.fits_within(lo, hi) else "FAIL"
    rss_verdict = "pass" if s.rss_fits_within(lo, hi) else "fail"
    return (
        "Stack-up report (all values in mm)\n"
        + rows
        + "\n"
        + f"  nominal        : {mm(s.nominal)}\n"
        + f"  worst-case     : [{mm(s.wc_lo)}, {mm(s.wc_hi)}]  (spread {mm(s.wc_width)})\n"
        + f"  design window  : [{mm(lo)}, {mm(hi)}]\n"
        + f"  worst-case test: {verdict}\n"
        + f"  RSS test       : {rss_verdict}   (statistical estimate only, not a bound)"
    )


def sample(s: Stack, rng, *, distribution: str = "uniform") -> list[int]:
    """One simulated build. `uniform` is the honest worst case for RSS; `normal`
    is the assumption RSS actually relies on (bands at 3 sigma, clipped)."""
    out = []
    for t in s:
        if distribution == "uniform":
            out.append(rng.randint(t.dim.lo, t.dim.hi))
        else:
            mu = (t.dim.lo + t.dim.hi) / 2
            sigma = t.dim.width / 6 or 1e-9
            x = int(round(rng.gauss(mu, sigma)))
            out.append(min(max(x, t.dim.lo), t.dim.hi))
    return out
