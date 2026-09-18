"""CLI: check a JSON formula file, or emit its Lean proof obligation.

    python -m dimcert examples/interconnection.json
    python -m dimcert examples/interconnection.json --lean out/Generated.lean
    python -m dimcert --library

Exit code is 1 if any formula fails, so this drops into CI over a formula sheet.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .formulas import library_report
from .io import formulas_to_lean, load_formulas


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="dimcert", description=__doc__)
    p.add_argument("formulas", nargs="?", help="JSON formula file")
    p.add_argument("--lean", metavar="PATH", help="write a Lean module for these formulas")
    p.add_argument("--library", action="store_true", help="print the built-in checked library")
    args = p.parse_args(argv)

    if args.library:
        print(library_report())
        return 0
    if not args.formulas:
        p.error("give a JSON formula file or --library")

    eqs = load_formulas(args.formulas)
    if args.lean:
        out = Path(args.lean)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(formulas_to_lean(eqs))
        print(f"wrote {out}")

    failed = 0
    for q in eqs:
        print(q.report())
        if not q.checks:
            failed += 1
            r = q.counterexample_rescale()
            if r is not None:
                moved = [f"{b} by 1 decade" for b in r.__dataclass_fields__ if getattr(r, b)]
                print(f"        detectable by rescaling {', '.join(moved)}")
    if failed:
        print(f"\n{failed} of {len(eqs)} formulas failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
