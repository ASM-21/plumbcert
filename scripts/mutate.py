#!/usr/bin/env python3
"""Mutation testing for certificates.

The claim this repo makes is that the numbers in its generated modules are
actually checked. A `sorry` audit cannot establish that: a proof can be complete
and still assert something weaker than intended, because a mutated constant may
yield a different statement that happens to remain true.

So mutate and see what survives. Each run perturbs one integer literal in a
generated module and re-runs that project's full gate. A mutant that survives
names a constant the gate does not pin. Those are either a real gap or a
documented slack constant, and this script's job is to make the distinction
explicit rather than assumed.

Literals inside comments and string labels are skipped: they are prose, guarded
by the regeneration diff in each project's verify.sh, not by a theorem.

    python3 scripts/mutate.py            # sample, fast, what CI runs
    python3 scripts/mutate.py --full     # every code literal, slow

Exit code is 1 if any unexpected mutant survives.
"""
from __future__ import annotations
import argparse, os, random, re, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TARGETS = [
    ("tolstack", "TolStack/Examples.lean"),
    ("dimcert", "DimCert/Formulas.lean"),
    ("lyapcert", "LyapCert/Examples.lean"),
    ("carbonsched", "CarbonSched/Examples.lean"),
    ("gridcert", "GridCert/Examples.lean"),
]

# Constants known not to be pinned by any theorem, with the reason. A slack
# constant is one with genuine margin: perturbing it leaves a true statement
# because the claim was never tight there. Anything not on this list that
# survives is a finding.
EXPECTED_SURVIVORS: dict[str, str] = {
    # Design-window bounds in tolstack/TolStack/Examples.lean. These are the
    # customer's requirement, not a derived quantity: the stack reaches
    # [320, 590] and the window is [250, 600], so both ends have real margin and
    # widening either leaves a true (weaker) statement. The reachable interval
    # itself IS pinned exactly, by `axialGap_interval_is_exact`, so the
    # engineering content is checked even though the requirement has slack.
    # tolstack/TolStack/Examples.lean:68, `axialGap_tight_window_fails`. An
    # existential is inherently a weak statement: the stack reaches [320, 590],
    # so SOME in-tolerance build falls outside any window narrower than that, in
    # either direction. These two constants therefore have real slack and no
    # mutation can kill them.
    #
    # The engineering content is pinned elsewhere and IS mutation-tested:
    # `axialGap_interval_is_exact` fixes the reachable interval at exactly
    # [320, 590] by showing that narrowing either end by one micrometre fails.
    # That is the claim a reader should rely on.
    "tolstack:68": "existential over a window strictly inside [320, 590]; "
                   "tightness is carried by axialGap_interval_is_exact",
}


def masked_spans(src: str) -> list[tuple[int, int]]:
    out = [(m.start(), m.end()) for m in re.finditer(r"/-.*?-/", src, re.S)]
    out += [(m.start(), m.end()) for m in re.finditer(r"--[^\n]*", src)]
    out += [(m.start(), m.end()) for m in re.finditer(r'"[^"\n]*"', src)]
    return out


def code_literals(src: str):
    spans = masked_spans(src)
    for m in re.finditer(r"(?<![A-Za-z0-9_.])-?\d+(?![0-9.])", src):
        if not any(a <= m.start() < b for a, b in spans):
            yield m.start(), m.end(), m.group(0)


def gate(project: str, env) -> bool:
    r = subprocess.run(["./scripts/verify.sh"], cwd=ROOT / project,
                       capture_output=True, text=True, env=env)
    return r.returncode == 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--full", action="store_true", help="test every literal")
    ap.add_argument("--sample", type=int, default=10, help="literals per project")
    ap.add_argument("--project", help="restrict to one project")
    args = ap.parse_args()

    env = dict(os.environ)
    targets = [t for t in TARGETS if not args.project or t[0] == args.project]

    total = survived = 0
    findings: list[str] = []

    for project, rel in targets:
        path = ROOT / project / rel
        original = path.read_text()
        spots = list(code_literals(original))
        chosen = spots if args.full or len(spots) <= args.sample else \
            random.Random(0).sample(spots, args.sample)

        alive = []
        try:
            for start, end, token in chosen:
                # Several directions. A constant is pinned if ANY wrong value is
                # caught; it is genuinely free only if every wrong value passes.
                # One-directional mutation is not enough: raising a constant
                # inside a `= false` assertion often keeps it false, which would
                # report a checked constant as unpinned.
                v = int(token)
                candidates = [v * 3 + 7919, v - 7919, v + 1, v - 1, -v - 1]
                killed = False
                for cand in candidates:
                    if cand == v:
                        continue
                    path.write_text(original[:start] + str(cand) + original[end:])
                    if not gate(project, env):
                        killed = True
                        break
                if not killed:
                    line = original[:start].count("\n") + 1
                    alive.append((line, token))
        finally:
            path.write_text(original)

        total += len(chosen)
        unexpected = [(l, t) for l, t in alive
                      if f"{project}:{l}" not in EXPECTED_SURVIVORS]
        survived += len(unexpected)
        status = "all killed" if not alive else f"{len(alive)} survived"
        print(f"{project:12s} {len(chosen):3d}/{len(spots):3d} literals  {status}")
        for line, token in unexpected:
            msg = f"{project} {rel}:{line} literal {token} is not pinned by any theorem"
            findings.append(msg)
            print(f"      NOT PINNED  line {line}: {token}")

    print(f"\n{total} mutants, {survived} unexpectedly survived")
    if findings:
        print("\nEach finding is a constant the gate does not check. Either pin it "
              "with a theorem, or add it to EXPECTED_SURVIVORS with the reason it "
              "has slack.")
        return 1
    print("every tested constant is load-bearing")
    return 0


if __name__ == "__main__":
    sys.exit(main())
