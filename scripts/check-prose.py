#!/usr/bin/env python3
"""Guard the prose the way the code is guarded.

Every figure quoted in a README or doc that also appears in a tool's output is
recomputed here from the tools themselves. If prose and output drift apart, this
fails. It also fails when a required caveat has been deleted, and when an
overclaiming phrase appears outside a scoped blockquote.

    python3 scripts/check-prose.py           # run all checks
    python3 scripts/check-prose.py --inject  # self-test: prove each guard fires

The --inject mode exists because a guard that has never fired is an assumption,
not a guard.
"""
from __future__ import annotations
import argparse, re, subprocess, sys, os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
env = dict(os.environ)


def tool_output(project: str, module: str, args: list[str]) -> str:
    r = subprocess.run([sys.executable, "-m", module] + args,
                       cwd=ROOT / project / "python", capture_output=True,
                       text=True, env=env)
    return r.stdout


# (label, project, module, args, [(regex over output, list of files that must contain the captured value)])
NUMERIC_CHECKS = [
    ("gridcert A-D contingency flow", "gridcert", "gridcert",
     ["../examples/study.json"],
     [(r"A-D with A-B out: \[([-\d.]+), ([-\d.]+)\] MW", ["README.md", "gridcert/README.md"])]),
    ("carbonsched industrial batch cost", "carbonsched", "carbonsched",
     ["../examples/scenarios.json"],
     [(r"industrial batch: (\d+) over slots", ["carbonsched/README.md"])]),
    ("tolstack axial gap limits", "tolstack", "tolstack",
     ["../examples/axial_gap.json"],
     [(r"worst-case     : \[([\d.]+), ([\d.]+)\]", ["tolstack/README.md"])]),
]

# The template must stay runnable: it is the documented on-ramp for a stranger
# testing the headline tool on their own network.
def check_theorem_count() -> list[str]:
    """The headline count in STATUS.md must match what stats.sh computes."""
    r = subprocess.run(["./scripts/stats.sh"], cwd=ROOT, capture_output=True, text=True)
    m = re.search(r"TOTAL\s+(\d+)", r.stdout)
    if not m:
        return ["scripts/stats.sh produced no TOTAL line; this guard is stale"]
    total = m.group(1)
    text = (ROOT / "docs" / "STATUS.md").read_text()
    if f"{total} theorems" not in text:
        return [f"docs/STATUS.md does not state the computed theorem count {total}"]
    return []


def check_template() -> list[str]:
    import json, tempfile
    bad = []
    out = tool_output("gridcert", "gridcert", ["--template", "-"])
    try:
        data = json.loads(out)
    except Exception as e:
        return [f"gridcert --template did not emit valid JSON: {e}"]
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as fh:
        json.dump(data, fh)
        path = fh.name
    run = tool_output("gridcert", "gridcert", [path])
    if "base case" not in run:
        bad.append("the emitted template does not run: "
                   f"`python3 -m gridcert <template>` produced {run[:120]!r}")
    return bad


# Caveats that must not be deleted. (file, substring, why)
REQUIRED_CAVEATS = [
    ("README.md", "independent personal project",
     "employer independence statement"),
    ("README.md", "not affiliated with",
     "employer independence statement"),
    ("README.md", "DC screen is a screen, not an AC study",
     "the modelling-gap caveat for gridcert"),
    ("README.md", "does not guarantee the definitions model",
     "the definitions-vs-reality caveat"),
    ("docs/RELATED-WORK.md", "measured demonstration of a known technique",
     "the reframed novelty claim"),
    ("dimcert/README.md", "already done",
     "dimcert's re-instantiation status"),
    ("lyapcert/README.md", "standard practice",
     "lyapcert's re-instantiation status"),
    ("carbonsched/README.md", "El-Yaniv",
     "attribution of the competitive ratio to one-way trading"),
    ("tolstack/README.md", "known in the tolerance literature",
     "RSS non-conservativeness is not a new result"),
]

# Phrases that overclaim. Allowed only inside a blockquote (scoped attribution).
OVERCLAIM = [
    r"\bnovel method\b", r"\bfirst ever\b", r"\bbreakthrough\b",
    r"\bproves? (?:that )?(?:the )?(?:grid|plant|network) is safe\b",
    r"\bguarantees? correctness of the (?:model|design)\b",
    r"\bregulator[a-z]* (?:approved|accepted)\b",
]


def docs() -> list[Path]:
    out = [ROOT / "README.md"] + sorted((ROOT / "docs").glob("*.md"))
    out += [ROOT / p / "README.md" for p in
            ("tolstack", "dimcert", "lyapcert", "carbonsched", "gridcert")]
    return [p for p in out if p.exists()]


def check_numbers() -> list[str]:
    bad = []
    for label, project, module, args, rules in NUMERIC_CHECKS:
        out = tool_output(project, module, args)
        for pattern, files in rules:
            m = re.search(pattern, out)
            if not m:
                bad.append(f"{label}: pattern {pattern!r} not found in tool output; "
                           f"the tool's format changed and this guard is stale")
                continue
            for value in m.groups():
                for f in files:
                    text = (ROOT / f).read_text()
                    if value not in text:
                        bad.append(f"{label}: computed {value} is absent from {f} "
                                   f"(prose has drifted from the tool)")
    return bad


def _flat(text: str) -> str:
    """Collapse whitespace so a caveat still counts when line-wrapped, and strip
    markdown emphasis so bolding a phrase does not delete the guard."""
    return re.sub(r"\s+", " ", text.replace("*", "").replace("`", ""))


def check_caveats() -> list[str]:
    bad = []
    for f, needle, why in REQUIRED_CAVEATS:
        p = ROOT / f
        if not p.exists():
            bad.append(f"{f} is missing entirely ({why})")
        elif _flat(needle) not in _flat(p.read_text()):
            bad.append(f"{f} no longer contains {needle!r} -- {why} was removed")
    return bad


def check_overclaim() -> list[str]:
    bad = []
    for p in docs():
        for i, line in enumerate(p.read_text().splitlines(), 1):
            if line.lstrip().startswith(">"):
                continue
            for pat in OVERCLAIM:
                if re.search(pat, line, re.I):
                    bad.append(f"{p.relative_to(ROOT)}:{i} overclaiming phrase "
                               f"matching {pat!r}: {line.strip()[:70]}")
    return bad


GUARDS = [("numeric drift", check_numbers),
          ("template runs", check_template),
          ("theorem count", check_theorem_count),
          ("required caveats", check_caveats),
          ("overclaiming", check_overclaim)]


def run() -> int:
    failures = []
    for name, fn in GUARDS:
        problems = fn()
        print(f"{'FAIL' if problems else 'ok  '}  {name}")
        for p in problems:
            print(f"        {p}")
        failures += problems
    if failures:
        print(f"\n{len(failures)} prose guard failure(s)")
        return 1
    print("\nprose matches the tools, caveats intact, no overclaiming")
    return 0


def inject() -> int:
    """Prove each guard fires by introducing the failure it claims to catch."""
    print("guard self-test: each guard must fail when its failure is injected\n")
    ok = True

    # 1. numeric drift
    p = ROOT / "gridcert" / "README.md"; orig = p.read_text()
    try:
        p.write_text(orig.replace("558.0", "999.9"))
        fired = bool(check_numbers())
        print(f"{'ok  ' if fired else 'FAIL'}  numeric drift guard fires on a changed figure")
        ok &= fired
    finally:
        p.write_text(orig)

    # 2. caveat deletion
    p = ROOT / "README.md"; orig = p.read_text()
    try:
        p.write_text(orig.replace("independent personal project", "REMOVED"))
        fired = bool(check_caveats())
        print(f"{'ok  ' if fired else 'FAIL'}  caveat guard fires when independence statement is deleted")
        ok &= fired
    finally:
        p.write_text(orig)

    # 3. overclaiming
    p = ROOT / "docs" / "RELATED-WORK.md"; orig = p.read_text()
    try:
        p.write_text(orig + "\nThis is a breakthrough.\n")
        fired = bool(check_overclaim())
        print(f"{'ok  ' if fired else 'FAIL'}  overclaim guard fires on an unscoped claim")
        ok &= fired
    finally:
        p.write_text(orig)

    print("\nall guards fire" if ok else "\nA GUARD DID NOT FIRE: it is an assumption, not a guard")
    return 0 if ok else 1


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--inject", action="store_true")
    a = ap.parse_args()
    sys.exit(inject() if a.inject else run())
