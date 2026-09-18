"""Carbon-aware scheduling of a deferrable load, mirroring CarbonSched/Basic.lean.

Schedules are lists of booleans over slots, the same representation the Lean
development uses, so the two models can be compared directly rather than
approximately. All arithmetic is integer.

The scheduler's job is not only to pick slots but to emit the threshold that
proves it picked the right ones. Lean does not trust the search; it re-checks
the threshold.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Sequence

Mask = list[bool]
Profile = list[int]


def cost(mask: Sequence[bool], profile: Sequence[int]) -> int:
    return sum(c for b, c in zip(mask, profile) if b)


def count(mask: Sequence[bool]) -> int:
    return sum(1 for b in mask if b)


def sub(mask: Sequence[bool], feasible: Sequence[bool]) -> bool:
    """Every occupied slot is an allowed slot, and the lengths agree."""
    return len(mask) == len(feasible) and all(f for b, f in zip(mask, feasible) if b)


def window(n: int, release: int = 0, deadline: int | None = None) -> Mask:
    """Slots [release, deadline) are allowed."""
    deadline = n if deadline is None else deadline
    return [release <= t < deadline for t in range(n)]


def earliest(feasible: Sequence[bool], slots: int) -> Mask:
    """Run as early as possible: the uncontrolled baseline."""
    out, left = [], slots
    for f in feasible:
        take = f and left > 0
        out.append(take)
        if take:
            left -= 1
    return out


def fixed_hours(n: int, hours: Sequence[int]) -> Mask:
    """A fixed-schedule baseline, e.g. 'always runs overnight'."""
    hs = set(hours)
    return [t in hs for t in range(n)]


@dataclass
class Schedule:
    """A schedule plus the threshold that certifies it."""

    name: str
    profile: Profile
    feasible: Mask
    mask: Mask
    theta: int

    @property
    def cost(self) -> int:
        return cost(self.mask, self.profile)

    @property
    def slots(self) -> int:
        return count(self.mask)

    def certified(self) -> bool:
        """Re-check the certificate the way Lean will."""
        if not sub(self.mask, self.feasible):
            return False
        if len(self.profile) != len(self.mask):
            return False
        for b, f, c in zip(self.mask, self.feasible, self.profile):
            if b and c > self.theta:
                return False
            if f and not b and c < self.theta:
                return False
        return True


def schedule(profile: Sequence[int], feasible: Sequence[bool], slots: int,
             name: str = "load") -> Schedule:
    """Pick the cheapest allowed slots, and emit the threshold that proves it.

    Ties are broken toward earlier slots, which matters only for which optimal
    schedule you get, not for the cost.
    """
    if len(profile) != len(feasible):
        raise ValueError("profile and feasibility mask have different lengths")
    allowed = [t for t, f in enumerate(feasible) if f]
    if slots > len(allowed):
        raise ValueError(f"need {slots} slots but only {len(allowed)} are allowed")
    ranked = sorted(allowed, key=lambda t: (profile[t], t))
    chosen = set(ranked[:slots])
    mask = [t in chosen for t in range(len(profile))]

    # The threshold sits between the most expensive chosen slot and the
    # cheapest rejected one. Any value in that gap certifies; take the low end.
    taken = [profile[t] for t in ranked[:slots]]
    left = [profile[t] for t in ranked[slots:]]
    if taken and left:
        theta = max(max(taken), min(left)) if max(taken) > min(left) else max(taken)
    elif taken:
        theta = max(taken)
    elif left:
        theta = min(left)
    else:
        theta = 0
    return Schedule(name=name, profile=list(profile), feasible=list(feasible),
                    mask=mask, theta=theta)


def savings(sched: Schedule, baseline: Mask) -> tuple[int, int, float]:
    """(baseline cost, certified cost, percent reduction)."""
    b = cost(baseline, sched.profile)
    c = sched.cost
    pct = 0.0 if b == 0 else 100.0 * (b - c) / b
    return b, c, pct


def spread(profile: Sequence[int], feasible: Sequence[bool]) -> tuple[int, int]:
    """(lo, hi) over the allowed slots: the online worst-case ratio is hi/lo."""
    vals = [c for c, f in zip(profile, feasible) if f]
    if not vals:
        raise ValueError("no allowed slots")
    return min(vals), max(vals)
