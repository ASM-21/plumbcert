"""CLI: report on a stack, or generate its Lean proof obligation.

    python -m tolstack examples/axial_gap.json
    python -m tolstack examples/axial_gap.json --lean out/Generated.lean

Exit code is 1 when the worst-case check fails, so this drops straight into CI
on a drawing change.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .io import load_stack, stack_to_lean
from .model import mm, report


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="tolstack", description=__doc__)
    p.add_argument("stack", help="JSON stack definition")
    p.add_argument("--lean", metavar="PATH", help="write a Lean module for this stack")
    p.add_argument("--quiet", action="store_true", help="verdict only")
    args = p.parse_args(argv)

    s, lo, hi = load_stack(args.stack)
    ok = s.fits_within(lo, hi)

    if args.lean:
        out = Path(args.lean)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(stack_to_lean(s, lo, hi))
        print(f"wrote {out}")

    if args.quiet:
        print("PASS" if ok else "FAIL")
        return 0 if ok else 1

    print(report(s, lo, hi))
    if not ok:
        low_side = s.wc_lo < lo
        build = s.arg_lo if low_side else s.arg_hi
        gap = s.eval(build)
        print()
        print(f"  offending build : {', '.join(mm(x) for x in build)}")
        print(f"  resulting gap   : {mm(gap)}  ({'below' if low_side else 'above'} window)")
        print(f"  slack (lo, hi)  : {mm(s.slack_lo(lo))}, {mm(s.slack_hi(hi))}")
        budget = s.budget_remaining(lo, hi)
        if budget < 0:
            print(f"  infeasible      : component bands exceed the window by {mm(-budget)}")
        else:
            print(f"  budget left     : {mm(budget)} (window is wide enough; shift the nominal)")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
