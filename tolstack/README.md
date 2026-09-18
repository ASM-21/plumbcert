# TolStack

A machine-checked 1D worst-case tolerance stack-up verifier: Lean 4 for the
proofs, Python for the working tool, one JSON file as the source of truth for
both.

This is Stage 1(A) of the Lean-for-mechanical-engineering research brief. It is
the greenfield-but-elementary project, chosen to validate the whole workflow end
to end before anything harder gets attempted.

## Try it

```bash
cd python && python3 -m tolstack ../examples/axial_gap.json
```
```
worst-case     : [0.320, 0.590]  (spread 0.270)
design window  : [0.250, 0.600]
worst-case test: PASS
RSS test       : pass   (statistical estimate only, not a bound)
```
Exit code is 1 when the stack fails, so a drawing change that breaks an assembly fails CI. Add `--lean out/MyStack.lean` to get a kernel-checked certificate for your own stack.

## What is actually proved

Every claim below is a Lean theorem with no `sorry` and no axioms beyond the
three standard ones (`propext`, `Classical.choice`, `Quot.sound`). The build
fails if that ever stops being true: `TolStack/Audit.lean` pins each result's
axiom footprint with `#guard_msgs`.

| Claim | Theorem |
| --- | --- |
| Every assembly built from in-tolerance parts lands inside the computed interval | `Stack.eval_mem_worstCase` |
| Both endpoints of that interval are actually reachable, so it is exact rather than conservative | `Stack.wcLo_attained`, `Stack.wcHi_attained` |
| The checker never passes a stack that can go out of spec | `Stack.fitsWithin_sound` |
| The checker never rejects a stack that cannot, and hands back the offending build when it does reject | `Stack.fitsWithin_complete` |
| A passing clearance check means the gap never closes to interference | `Stack.noInterference_sound` |
| The worst-case spread is exactly the sum of the component bands, for any mix of directions | `Stack.wcHi_sub_wcLo` |
| RSS is never more conservative than worst-case | `Stack.rssSq_le_wcWidth_sq` |
| **RSS is not a bound.** Concrete counterexample: a stack that passes RSS and still has a legal build outside the window | `Stack.rss_check_unsound` |
| Tightening any tolerance can never turn a passing stack into a failing one | `Stack.refines_fitsWithin` |
| A stack can only pass if the summed component bands fit the window, independent of where nominal sits | `Stack.fitsWithin_budget` |
| A chain of bilateral tolerances contains its own nominal | `Stack.nominal_mem_worstCase` |
| The worked example's limits are 0.320 to 0.590 mm and it passes a 0.250 to 0.600 mm window | `Examples.axialGap_bounds`, `Examples.axialGap_in_window` |

55 theorems, 43 definitions, no dependencies. Not even mathlib.

## Prior art: first formalization, long-known result

No formalization of worst-case tolerance stack-up, GD&T or ASME Y14.5 in a proof
assistant was found, so the Lean development here appears to be first of its
kind.

The engineering content is not new. That RSS is not a conservative bound is
**known in the tolerance literature** and has been for decades: it is stated in
Fischer's *Mechanical Tolerance Stackup and Analysis*, Drake's *Dimensioning and
Tolerancing Handbook*, and Creveling's *Tolerance Design*, and it is the routine
reason worst-case and statistical methods are quoted side by side. The
contribution here is a machine-checked counterexample, not the insight. See
[../docs/RELATED-WORK.md](../docs/RELATED-WORK.md).

## What is not proved

The honest boundary, since this is the part that decides whether the exercise
was worth anything:

- **Definition fidelity.** Lean guarantees the theorems follow from the
  definitions in `TolStack/Basic.lean`. It does not guarantee those definitions
  model your drawing. A stack chain that omits a contributor is still provably
  correct about the chain it was given.
- **1D only.** No datum reference frames, no MMC/LMC bonus tolerance, no
  geometric controls, no angular contributions. ASME Y14.5 proper is a much
  larger effort and is deliberately out of scope.
- **The RSS test is spread-only.** It compares RSS spread to window width and
  ignores where nominal sits, matching common practice. Its unsoundness is
  proved, not hand-waved, so nothing here should be read as endorsing it.
- **No process-capability modeling.** No Cp/Cpk, no drift, no correlated
  variation between features.

## Design decisions worth knowing

**Integers, not reals.** Every length is an `Int` in micrometres. This is the
choice that makes the whole thing tractable without mathlib: all the arithmetic
is linear over `Int`, so `omega` discharges it, and the theorems are about the
exact arithmetic the checker performs rather than about an idealized real-number
model the implementation only approximates. There is no floating point anywhere
in the decision path.

**Zero dependencies.** The brief suggested leaning on LeanCert for interval
bounds. Exact integer arithmetic removes the need, and the result builds in
about ten seconds against plain Lean 4.22.0 with nothing pinned but the
toolchain. Given that mathlib version churn breaking downstream libraries was
called out as a maintenance risk, and that several libraries named in the brief
could not be verified as accessible, no-dependencies looked like the better
trade for a project this size.

**RSS handled by squaring.** Comparing `Σ wᵢ²` against `W²` is exactly
equivalent to comparing `sqrt(Σ wᵢ²)` against `W` for non-negative `W`, and it
stays in `Int`. No irrational arithmetic, no rounding, no `native_decide`.

## Layout

```
TolStack/Basic.lean      model, worst-case interval, sound + complete checker
TolStack/Analysis.lean   spread, RSS, RSS-is-not-a-bound counterexample
TolStack/Design.lean     slack, tolerance budget, refinement monotonicity
TolStack/Examples.lean   worked axial stack, report renderer
TolStack/Audit.lean      axiom footprint gate (CI)
python/tolstack/         same model as a working tool, plus JSON -> Lean codegen
python/tests/            parity tests against the proved numbers, property tests
examples/axial_gap.json  the worked example
scripts/verify.sh        everything above, in one command
```

## Use

```bash
lake build                                        # proofs + axiom audit
cd python && python3 -m tolstack ../examples/axial_gap.json
./scripts/verify.sh                               # full gate
```

Exit code is 1 when the worst-case check fails, so a drawing change that breaks
an assembly fails CI.

To get a kernel-checked certificate for your own stack:

```bash
python3 -m tolstack my_stack.json --lean TolStack/Generated/MyStack.lean
lake env lean TolStack/Generated/MyStack.lean
```

The generated module states your stack's limits and verdict and closes them by
`decide`, so the numbers the Python tool prints and the numbers the Lean kernel
signs off on are generated from the same JSON and cannot drift.

## Worked example

Bearing and spacer retained by a snap ring in a counterbored housing. The
closing dimension is the axial gap left for the ring.

```
gap = bore depth - bearing width - spacer length - ring thickness
```

Nominal 0.400 mm, worst-case 0.320 to 0.590 mm, spread 0.270 mm, passes a 0.250
to 0.600 mm window. Tighten the window to 0.350 to 0.550 and the tool reports
the exact offending build (bore at low limit, everything inside at high limit)
and notes the stack is infeasible by 0.070 mm no matter where the nominal is
placed. That last verdict is `fitsWithin_budget`, and it is the difference
between "move the nominal" and "you need tighter parts".

## Next

The brief's Stage 1(B) is the dimensional-consistency checker, which reuses this
same shape: a decidable predicate, a soundness theorem, a Python companion.
Stage 2 (Lyapunov envelope) is the first one that needs mathlib and an external
library, and should not start until that library is confirmed to exist and
build.
