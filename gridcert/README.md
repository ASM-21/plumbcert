# GridCert

Machine-checked N-1 thermal screening for interconnection studies, on the DC
power flow model. Exact rational sensitivities in Python; Lean re-derives every
sensitivity row from the network equations and proves the screen verdict.

This is Stage 4 of the Lean-for-mechanical-engineering brief.

## Try it

```bash
cd python && python3 -m gridcert ../examples/study.json
```
```
ok    A-E base case:    [-227.8, 260.2] MW vs ±400, margin +139.8 MW
FAIL  A-D with A-B out: [160.5, 558.0] MW vs ±400, margin -158.0 MW
        binding dispatch (MW): B=-330, C=-300, D=-400, E=+0
```
Exit code is 1 if any screen fails, so a request that triggers upgrades fails CI. Each failure ships with the dispatch that causes it, proved to lie inside the studied box.

## The thing this fixes

A screening study is a claim of the form "no dispatch the system could be in
overloads this branch". In practice that claim rests on a PTDF matrix produced
by a program nobody reads, applied to a handful of sampled dispatches.

Both halves are addressed here.

**The dispatch is a box, not a snapshot.** One interval per bus, covering load
forecast error, unit commitment freedom and the study generator's output range
at once. `screen_sound` quantifies over every dispatch in that box, so nothing
is sampled and nothing is missed.

**The sensitivity row is derived, not asserted.** For each bus the study hands
Lean an angle vector; `RowCertified` demands it be an exact zero-residual
solution of the network equations for a unit injection at that bus, and that the
monitored branch's flow under it equal the row entry. Every entry is pinned.
Perturbing any single entry by one unit makes the build fail, which I checked.

## What is actually proved

No `sorry`, no axioms beyond the standard three. `GridCert/Audit.lean` pins each
result's axiom footprint with `#guard_msgs`.

| Claim | Theorem |
| --- | --- |
| **Screening is sound.** A passing screen means *every* dispatch in the box keeps the branch inside its rating | `screen_sound` |
| **Screening is complete.** A failing screen comes with the dispatch that causes the overload, proved to be inside the box | `screen_complete_hi`, `screen_complete_lo` |
| The reported flow limits are attained by real dispatches, so the screen is exact rather than conservative | `dot_argUpper`, `dot_argLower`, `argUpper_mem`, `argLower_mem` |
| The box bounds are sound for every dispatch in the box | `dot_le_upper`, `lower_le_dot` |
| **Branch flow and nodal injection are linear in the angles.** This is what licenses assembling a dispatch's flows from per-bus unit solutions, which is what a PTDF row is | `flow_addA`, `flow_smulA`, `injAt_addA`, `injAt_smulA` |
| **A certified row means what it says**, column by column: zero residual at every bus, and the branch flow equals the row entry | `rowCertified_column`, `solves_injAt` |
| Post-contingency superposition, for the LODF-built route | `dot_combine`, `dot_postContingency`, `dot_scaleRow` |
| A pass is exactly a non-negative margin | `screen_iff_margin_nonneg` |
| Three branches certified safe over the whole box; two certified overloaded with their binding dispatches | `Examples.*Safe`, `Examples.*Violates` |

44 theorems, 52 definitions, no dependencies. Not even mathlib.

## Why this one did not need mathlib either

I said at the end of Stage 3 that this stage would be where interval arithmetic
over the reals forced the issue. It did not, and the reason is worth stating: the
DC model is linear, and all of it can be carried in exact integers.

Susceptances are integers by construction. Reactances in the study system are
rounded so that `1/x` is a whole number, the largest change being under one
percent. Angles are rationals, cleared to integers by a per-row scale factor `K`,
so a row entry is `K` times the true sensitivity and a rating of 400 MW is the
integer `400K`. Nothing is approximated at any point, and no floating point
appears in the certificate path.

The place mathlib would genuinely be needed is AC power flow, where the
equations are transcendental and a Newton-Kantorovich existence ball is the
right tool. That is a different project.

## Prior art: the strongest claim in this repo

Power flow, PTDF, LODF and N-1 screening are large engineering literatures with
essentially no interactive-theorem-prover treatment. Certified *solvability* work
exists but is analysis rather than machine-checked (Yu, Nguyen and Turitsyn,
*IEEE PES GM* 2015; Bolognani and Zampieri, *IEEE Trans. Power Systems* 31(1),
2016). N-1 screening in practice is pointwise, sampled or MILP-based.

Kernel-checked screening over a *box* of operating points rather than sampled
points appears to be genuinely first. That is the claim most worth attacking, and
[../docs/RELATED-WORK.md](../docs/RELATED-WORK.md) records what the search did
not settle.

## What is not proved

- **DC is not AC.** The whole development is about the linearized model: no
  reactive power, no voltage magnitudes, no losses, flat voltage profile,
  small-angle approximation. Everything here is exactly true of the DC model and
  approximately true of the grid, and the size of that gap is not addressed. A
  certified DC screen is a screen, not a study.
- **Thermal only.** No voltage or stability limits, no short-circuit duty, no
  dynamic ratings.
- **N-1, not N-1-1.** Single branch outages. Nothing about generator
  contingencies or common-mode failures.
- **The box is an input.** If the real operating envelope is wider than the box,
  a pass proves nothing about the dispatches you left out. This is where a
  screening study is most likely to be wrong, and no amount of formalization
  helps.
- **Ratings and topology are inputs**, as is the assumption that the model
  matches the as-built network.
- **The LODF route is proved but not exercised in the examples.**
  `dot_postContingency` is available for building a post-contingency row from an
  LODF. The generated study does something stronger instead: it certifies the
  monitored branch's own row in the network with the outaged branch removed, so
  the verdict does not depend on the LODF being right at all. The LODF is still
  computed, reported, and cross-checked against that row in Python, because it is
  the number a planner expects to see.

## Layout

```
GridCert/Box.lean       box bounds on a linear form: sound, complete, attained
GridCert/Flow.lean      network model, superposition, row certification, screening
GridCert/Examples.lean  generated: the study, checked by decide
GridCert/Audit.lean     axiom footprint gate
python/gridcert/network.py  exact rational DC power flow, PTDF, LODF
python/gridcert/study.py    screens, boxes, margins
python/gridcert/codegen.py  study to Lean
examples/study.json     the network and the interconnection request
scripts/verify.sh       everything above, in one command
```

## Use

```bash
lake build                                      # proofs + audit
cd python && python3 -m gridcert ../examples/study.json
python3 -m gridcert ../examples/study.json --lean ../GridCert/Examples.lean
./scripts/verify.sh                             # full gate
```

Exit code is 1 if any screen fails, so a request that triggers upgrades fails CI.

## The study

Five-bus system with the topology of the PJM 5-bus training case, slack at bus A.
The request is a 300 MW resource at bus E, studied against a box in which loads
carry forecast error and the existing units are free within their ranges.

| Screen | Flow range (MW) | Rating | Margin |
| --- | --- | --- | --- |
| A-E base case | -227.8 to 260.2 | 400 | +139.8 |
| A-E with D-E out | -300.0 to 0.0 | 400 | +100.0 |
| A-D base case | 21.9 to 307.6 | 400 | +92.4 |
| A-D with A-B out | 160.5 to 558.0 | 400 | **-158.0** |
| D-E base case | -294.1 to -38.3 | 240 | **-54.1** |

Two constraints bind, so the request needs upgrades. The A-D overload under the
A-B contingency is the interesting one: the LODF is 1045/1929, about 0.54, so
more than half the lost A-B flow lands on A-D. The D-E overload is a base-case
violation the request causes directly.

Outaging D-E leaves bus E fed only by A-E, which is why that LODF is exactly 1:
the whole flow transfers. That is a fact about the topology, and the certificate
reproduces it without being told.
