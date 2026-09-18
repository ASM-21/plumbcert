"""Interconnection screening: build the boxes, run the screen, report margins."""

from __future__ import annotations

from dataclasses import dataclass
from fractions import Fraction

from .network import Network, RowCertificate, certify_row, lodf, without


def dot(row: list[int], p: list[int]) -> int:
    return sum(a * x for a, x in zip(row, p))


def upper(row: list[int], box: list[tuple[int, int]]) -> int:
    return sum(max(a * lo, a * hi) for a, (lo, hi) in zip(row, box))


def lower(row: list[int], box: list[tuple[int, int]]) -> int:
    return sum(min(a * lo, a * hi) for a, (lo, hi) in zip(row, box))


def arg_upper(row: list[int], box: list[tuple[int, int]]) -> list[int]:
    return [lo if a * lo >= a * hi else hi for a, (lo, hi) in zip(row, box)]


def arg_lower(row: list[int], box: list[tuple[int, int]]) -> list[int]:
    return [lo if a * lo <= a * hi else hi for a, (lo, hi) in zip(row, box)]


def scale_row(k: int, row: list[int]) -> list[int]:
    return [k * x for x in row]


def combine(c: int, a1: list[int], a2: list[int]) -> list[int]:
    return [x + c * y for x, y in zip(a1, a2)]


@dataclass
class Screen:
    """One monitored branch under one condition, ready to emit."""

    label: str
    row: list[int]
    scale: int              # row / scale is the true sensitivity in MW/MW
    box: list[tuple[int, int]]
    limit_mw: int
    base: RowCertificate
    outage: RowCertificate | None = None
    lodf_num: int = 0
    lodf_den: int = 1
    network: Network | None = None

    @property
    def limit_scaled(self) -> int:
        return self.scale * self.limit_mw

    @property
    def passes(self) -> bool:
        return (upper(self.row, self.box) <= self.limit_scaled
                and -self.limit_scaled <= lower(self.row, self.box))

    @property
    def max_flow_mw(self) -> Fraction:
        return Fraction(upper(self.row, self.box), self.scale)

    @property
    def min_flow_mw(self) -> Fraction:
        return Fraction(lower(self.row, self.box), self.scale)

    @property
    def margin_mw(self) -> Fraction:
        return min(self.limit_mw - self.max_flow_mw, self.min_flow_mw + self.limit_mw)

    def worst_dispatch(self) -> list[int]:
        """The dispatch that produces the binding extreme."""
        if self.limit_mw - self.max_flow_mw <= self.min_flow_mw + self.limit_mw:
            return arg_upper(self.row, self.box)
        return arg_lower(self.row, self.box)


def base_screen(net: Network, monitored: str, box: list[tuple[int, int]],
                limit_mw: int | None = None) -> Screen:
    li = net.line_index(monitored)
    cert = certify_row(net, li)
    lim = net.lines[li].rating if limit_mw is None else limit_mw
    return Screen(label=f"{monitored} base case", row=cert.row, scale=cert.scale,
                  box=box, limit_mw=lim, base=cert)


def contingency_screen(net: Network, monitored: str, outaged: str,
                       box: list[tuple[int, int]],
                       limit_mw: int | None = None) -> Screen:
    """Post-contingency screen, certified against the outaged network itself.

    The LODF is still computed and reported, because that is the number a
    planner expects to see, and `lodf_consistent` checks it. But the row that
    goes to Lean is the monitored line's own sensitivity row in the network with
    the outaged branch removed, certified there from first principles. That is
    strictly stronger than certifying an LODF-built row: it does not depend on
    the LODF being right.
    """
    mi, oi = net.line_index(monitored), net.line_index(outaged)
    post = without(net, oi)
    mi_post = post.line_index(monitored)
    cm = certify_row(post, mi_post)
    f = lodf(net, mi, oi)
    lim = net.lines[mi].rating if limit_mw is None else limit_mw
    return Screen(label=f"{monitored} with {outaged} out", row=cm.row,
                  scale=cm.scale, box=box, limit_mw=lim,
                  base=cm, outage=certify_row(net, oi),
                  lodf_num=f.numerator, lodf_den=f.denominator, network=post)


def lodf_consistent(net: Network, monitored: str, outaged: str) -> bool:
    """Cross-check: the LODF-built post-contingency row equals the outaged
    network's own row. Verified in Python because it is a fact about how the
    row was constructed, not a fact Lean needs in order to trust the row."""
    from fractions import Fraction
    from .network import ptdf_row
    mi, oi = net.line_index(monitored), net.line_index(outaged)
    base, out = ptdf_row(net, mi), ptdf_row(net, oi)
    f = lodf(net, mi, oi)
    built = [b + f * o for b, o in zip(base, out)]
    post = without(net, oi)
    direct = ptdf_row(post, post.line_index(monitored))
    return all(x == y for x, y in zip(built, direct))
