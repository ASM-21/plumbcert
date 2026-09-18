"""CLI: synthesize certificates from a JSON system file and emit Lean.

    python -m lyapcert examples/systems.json
    python -m lyapcert examples/systems.json --lean ../LyapCert/Examples.lean

Exit code is 1 if any system has no certificate.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .codegen import render_module, trajectory
from .exact import check_certificate, synthesize_any


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="lyapcert", description=__doc__)
    p.add_argument("systems", help="JSON system definitions")
    p.add_argument("--lean", metavar="PATH", help="write the Lean module")
    p.add_argument("--trace", action="store_true", help="print a short trajectory per system")
    args = p.parse_args(argv)

    data = json.loads(Path(args.systems).read_text())
    items, failed = [], 0
    for spec in data["systems"]:
        name = spec["name"]
        try:
            cert = synthesize_any(spec["A"], name)
        except ValueError as e:
            print(f"FAIL  {name}: {e}")
            failed += 1
            continue
        ok = check_certificate(cert)
        if not ok:
            print(f"FAIL  {name}: synthesized certificate failed its own check")
            failed += 1
            continue
        items.append((cert, spec))
        rate = float(cert.true_rate)
        print(
            f"ok    {name}: V decays by <= {cert.num}/{cert.den * cert.q * cert.q} per step "
            f"({rate:.4f}), state norm by <= {rate ** 0.5:.4f}"
        )
        print(f"        integer dynamics B = {cert.B}" + (f", scale q = {cert.q}" if cert.q != 1 else ""))
        print(f"        V = " + " + ".join(f"{c}({a}x + {b}y)²" for c, a, b in cert.P_sos))
        if args.trace:
            for k, V, v in trajectory(cert, (1, 1), 4):
                print(f"        k={k}  state={v}  V={V}")

    if args.lean and items:
        out = Path(args.lean)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(render_module(items))
        print(f"wrote {out}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
