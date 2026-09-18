"""CLI: schedule a deferrable load and emit its Lean proof obligation.

    python -m carbonsched examples/scenarios.json
    python -m carbonsched examples/scenarios.json --lean ../CarbonSched/Examples.lean

Exit code is 1 if any scenario is infeasible or any certificate fails its own
check before it ever reaches Lean.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .codegen import render_module
from .model import (
    cost, earliest, fixed_hours, schedule, spread, window,
)


def build_baselines(spec: dict, feasible: list[bool], slots: int) -> dict[str, list[bool]]:
    out: dict[str, list[bool]] = {}
    n = len(feasible)
    for b in spec.get("baselines", []):
        if b["kind"] == "earliest":
            out[b.get("name", "run now")] = earliest(feasible, slots)
        elif b["kind"] == "fixed":
            out[b.get("name", "fixed hours")] = fixed_hours(n, b["hours"])
        else:
            raise ValueError(f"unknown baseline kind {b['kind']!r}")
    return out


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="carbonsched", description=__doc__)
    p.add_argument("scenarios", help="JSON scenario file")
    p.add_argument("--lean", metavar="PATH", help="write the Lean module")
    args = p.parse_args(argv)

    data = json.loads(Path(args.scenarios).read_text())
    items, failed = [], 0

    for spec in data["scenarios"]:
        name = spec["name"]
        profile = [int(x) for x in spec["profile"]]
        n = len(profile)
        w = spec.get("window", {})
        feasible = window(n, int(w.get("release", 0)), int(w.get("deadline", n)))
        slots = int(spec["slots"])
        try:
            sched = schedule(profile, feasible, slots, name)
        except ValueError as e:
            print(f"FAIL  {name}: {e}")
            failed += 1
            continue
        if not sched.certified():
            print(f"FAIL  {name}: emitted certificate failed its own check")
            failed += 1
            continue

        baselines = build_baselines(spec, feasible, slots)
        lo, hi = spread(profile, feasible)
        hours = [t for t, b in enumerate(sched.mask) if b]
        print(f"ok    {name}: {sched.cost} over slots {hours} (threshold {sched.theta})")
        print(f"        allowed range [{lo}, {hi}], forecast-free worst case {hi / lo:.2f}x")
        for bname, bmask in baselines.items():
            bc = cost(bmask, profile)
            pct = 0.0 if bc == 0 else 100.0 * (bc - sched.cost) / bc
            print(f"        vs {bname}: {bc} -> {sched.cost}, saves {bc - sched.cost} ({pct:.1f}%)")
        items.append((sched, spec, baselines))

    if args.lean and items:
        out = Path(args.lean)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(render_module(items))
        print(f"wrote {out}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
