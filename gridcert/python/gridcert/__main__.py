"""CLI: run an interconnection screening study and emit its Lean proof obligation.

    python -m gridcert examples/study.json
    python -m gridcert examples/study.json --lean ../GridCert/Examples.lean

Exit code is 1 if any screen fails, so a study that triggers upgrades fails CI.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .codegen import render_module
from .network import Line, Network
from .study import base_screen, contingency_screen


def load(path: str | Path) -> tuple[Network, list, list]:
    d = json.loads(Path(path).read_text())
    nd = d["network"]
    idx = {b: i for i, b in enumerate(nd["buses"])}
    net = Network(
        buses=nd["buses"], slack=idx[nd["slack"]],
        lines=[Line(idx[l["src"]], idx[l["dst"]], int(l["susc"]), l["name"], int(l["rating"]))
               for l in nd["lines"]],
    )
    box = [tuple(int(x) for x in d["request"]["injections"][b]) for b in nd["buses"]]
    screens = []
    for s in d["screens"]:
        screens.append(
            contingency_screen(net, s["monitored"], s["outaged"], box)
            if "outaged" in s else base_screen(net, s["monitored"], box)
        )
    return net, box, screens


TEMPLATE = """{
  "_readme": [
    "A study file for gridcert. Replace everything below with your own network.",
    "",
    "susc is the branch series susceptance, 1/x, and MUST be an integer. If your",
    "reactances do not give whole numbers, scale every susceptance in the network",
    "by a common factor: the screen verdict is unchanged by a uniform scaling,",
    "since it multiplies every flow and every limit alike. Record the factor you",
    "used. (A MATPOWER importer that does this automatically is the top open",
    "issue: see docs/GOOD-FIRST-ISSUES.md.)",
    "",
    "rating is the branch thermal limit in MW.",
    "",
    "injections gives, per bus, the range of net injection in MW that the study",
    "must cover: generation positive, load negative. This is the whole point of",
    "the tool. Make it the real operating envelope, not a snapshot, because the",
    "proof covers every dispatch inside this box and says nothing about any",
    "dispatch outside it.",
    "",
    "screens lists what to monitor. Omit outaged for a base-case screen."
  ],
  "network": {
    "buses": ["A", "B", "C"],
    "slack": "A",
    "lines": [
      { "name": "A-B", "src": "A", "dst": "B", "susc": 20, "rating": 200 },
      { "name": "B-C", "src": "B", "dst": "C", "susc": 25, "rating": 200 },
      { "name": "A-C", "src": "A", "dst": "C", "susc": 10, "rating": 150 }
    ]
  },
  "request": {
    "name": "describe your interconnection request here",
    "injections": {
      "A": [-500, 500],
      "B": [-120, -80],
      "C": [0, 150]
    }
  },
  "screens": [
    { "monitored": "A-C" },
    { "monitored": "A-C", "outaged": "A-B" }
  ]
}
"""


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="gridcert", description=__doc__)
    p.add_argument("study", nargs="?", help="JSON study file")
    p.add_argument("--lean", metavar="PATH", help="write the Lean module")
    p.add_argument("--template", metavar="PATH", nargs="?", const="-",
                   help="write a blank study file to fill in with your own network")
    args = p.parse_args(argv)

    if args.template is not None:
        text = TEMPLATE
        if args.template == "-":
            print(text)
        else:
            Path(args.template).write_text(text)
            print(f"wrote {args.template}\n\nFill in your buses, lines and "
                  f"injection ranges, then run:\n"
                  f"  python3 -m gridcert {args.template}")
        return 0

    net, box, screens = load(args.study)
    failed = 0
    for sc in screens:
        tag = "ok  " if sc.passes else "FAIL"
        if not sc.passes:
            failed += 1
        extra = f", LODF {sc.lodf_num}/{sc.lodf_den}" if sc.outage else ""
        print(f"{tag}  {sc.label}: [{float(sc.min_flow_mw):.1f}, {float(sc.max_flow_mw):.1f}] MW "
              f"vs ±{sc.limit_mw}, margin {float(sc.margin_mw):+.1f} MW{extra}")
        if not sc.passes:
            worst = sc.worst_dispatch()
            named = ", ".join(f"{b}={v:+d}" for b, v in zip(net.buses, worst) if b != net.buses[net.slack])
            print(f"        binding dispatch (MW): {named}")

    if args.lean:
        out = Path(args.lean)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(render_module(net, screens))
        print(f"wrote {out}")
    if failed:
        print(f"\n{failed} of {len(screens)} screens fail: the request needs network upgrades")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
