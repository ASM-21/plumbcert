# Findings

The claims this repository makes, numbered so each depends only on those above
it. Every claim states what it rests on, how to reproduce it, and what would
falsify it.

**Scope conditions for the whole argument, stated once.** All claims are about
the models defined in this repository, not about physical systems. All inputs are
synthetic or hand-constructed (see [LIMITATIONS.md](LIMITATIONS.md)). All
arithmetic is exact integer arithmetic at a fixed scale. "Verified" means checked
by the Lean 4.22.0 kernel with no `sorry` and no axioms beyond `propext`,
`Classical.choice` and `Quot.sound`, as pinned in each project's `Audit.lean`.

Reproduce everything with `./scripts/verify-all.sh`.

---

## C1. The certificates are checked, not merely present

**Claim.** Each generated module's constants are load-bearing: perturbing one
makes the project's gate fail.

**Rests on.** Nothing above it.

**Reproduce.** `python3 scripts/mutate.py --full`

**Method.** Each literal is replaced by several wrong values in both directions.
A constant counts as pinned if *any* wrong value is caught; it is reported as
free only if every wrong value passes. One-directional mutation was not enough:
raising a constant inside a `= false` assertion often keeps it false, which
reported genuinely checked constants as unpinned.

**Evidence.** Mutation testing perturbs each integer literal in a generated
module and re-runs the full gate. Against the complete gate, every tested
constant in all five projects is killed.

**What it cost.** The first run of this test, against single-file type-checking
rather than the full gate, found a real defect: `tolstack`'s hand-written
tight-window theorem used constants 350 and 550 that could be changed to yield a
*different but still true* statement. That is the failure mode an axiom audit
cannot catch. It is now pinned by `axialGap_tight_window_is_tight`. Recorded
because a guard that has never found anything is an assumption.

**Known slack.** One entry is registered in the script's `EXPECTED_SURVIVORS`
with its reason: the window constants inside `axialGap_tight_window_fails` are
an existential over a window strictly inside the reachable interval, so no
mutation can kill them. The interval itself is pinned exactly by
`axialGap_interval_is_exact`, and that is the claim to rely on.

**What would falsify it.** A surviving mutant not listed in `EXPECTED_SURVIVORS`.

---

## C2. Soundness: a passing check means the property holds for every admissible input

**Claim.** Where a checker accepts, the corresponding engineering property holds
universally over the stated input set, not at sampled points.

**Rests on.** C1 (the constants being checked are the ones stated).

**Reproduce.** `lake build` in any project; see `Audit.lean` for axiom pinning.

**Evidence.** `GridCert.screen_sound` quantifies over every dispatch in the box.
`CarbonSched.optimal` quantifies over every alternative schedule of equal length.
`TolStack.fitsWithin_sound` quantifies over every in-tolerance assembly.
`LyapCert.Cert.sublevel_invariant` quantifies over every state and horizon.
`DimCert.Equation.scale_agree` quantifies over every change of units.

**What would falsify it.** A theorem statement whose rival is bounded by a list
rather than universally quantified, which would make it a sampled claim wearing
universal clothing.

---

## C3. Completeness: a rejection returns the specific counterexample

**Claim.** Where a checker rejects, it produces a witness, proved admissible,
that violates the property.

**Rests on.** C2.

**Reproduce.** `cd gridcert/python && python3 -m gridcert ../examples/study.json`

**Evidence.** `screen_complete_hi`/`_lo`, `fitsWithin_complete`,
`separator_detects`. In the shipped study, two screens fail and each names the
binding dispatch.

**Why it matters.** An engineer told "this fails" and not "here is what fails"
cannot act. Constructive completeness is the difference between a verification
result and a usable tool.

**What would falsify it.** A rejection path that returns no witness, or a witness
not proved to be inside the admissible set.

---

## C4. Two checkers have blind spots, and those are proved too

**Claim.** Dimensional consistency is necessary but not sufficient, and this is
demonstrated inside the library rather than disclaimed in prose.

**Rests on.** C2.

**Reproduce.** `cd dimcert/python && python3 -m dimcert --library`

**Evidence.** `DimCert.Formulas.apparentPowerSum_checks` proves that `S = P + Q`
passes every dimensional check, sitting directly above the correct
`S = √(P² + Q²)`, which also passes. Watts, vars and volt-amperes share a
dimension, so no dimensional checker can separate them.
`TolStack.rss_check_unsound` exhibits a stack that passes RSS and has a legal
build outside the window.

**What would falsify it.** Nothing; these are the honest ceilings of the two
methods, and they are load-bearing for how the tools should be used.

---

## C5. gridcert's sensitivity rows are derived, not asserted

**Claim.** Each PTDF row entry is checked against a zero-residual solution of the
network equations for a unit injection at that bus.

**Rests on.** C1, C2.

**Reproduce.** `lake build` in `gridcert`; see `*RowCertified` theorems.

**Evidence.** `RowCertified` requires, per bus, an angle vector that solves the
network for a unit injection and reproduces the row entry.
`rowCertified_column` extracts that per bus.

**What it cost.** The first version of this check validated the row only against
the *binding* dispatch, and a perturbed entry survived because that bus injected
zero at the binding point. The check was partly vacuous. It now certifies every
column, and all perturbations fail. This is the worked example in
[CONCEPTS.md](CONCEPTS.md) of a certificate that pinned only the part the current
instance exercised.

**What would falsify it.** A surviving row mutation, which `scripts/mutate.py`
tests directly.

---

## C6. The prose matches the tools

**Claim.** Figures quoted in these documents are recomputed from the tools, not
transcribed once and left to rot.

**Rests on.** C1 through C5.

**Reproduce.** `python3 scripts/check-prose.py`, and
`python3 scripts/check-prose.py --inject` to confirm each guard fires.

**Evidence.** The guard recomputes quoted figures from tool output, fails when a
required caveat is deleted, and fails on overclaiming phrases outside a scoped
quotation. Each of the three is verified by injecting its own failure.

**What would falsify it.** A guard that does not fire under `--inject`.

---

## C7. The method is not new, and the novelty is domain transfer

**Claim.** The certificate-checking design is established practice; what is
plausibly new here is its application to tolerance stack-up, box-wise N-1
screening, and carbon-aware scheduling optimality.

**Rests on.** An adversarial literature search conducted after the results
existed.

**Reproduce.** Read [RELATED-WORK.md](RELATED-WORK.md) and check its citations.

**Evidence.** The methodology is certifying algorithms (McConnell et al. 2011),
program checking (Blum and Kannan 1995) and proof-carrying code (Necula 1997).
The SOS instance is Harrison 2007, Monniaux and Corbineau 2011, Roux et al. 2016.
Dimensional analysis is Kennedy 1997 and is already formalized in Lean 4 (Bobbin
et al. 2025; Allen 2025). `dimcert` and `lyapcert` are therefore
re-instantiations and are labelled as such.

**What would falsify the residual claim.** A prior proof-assistant formalization
of tolerance stack-up, of box-wise contingency screening, or of scheduling
competitive ratios. [RELATED-WORK.md](RELATED-WORK.md) names exactly which
searches were not exhaustive.

---

## Provenance

Each claim above is reproducible from a clean clone at the tagged release. The
environment is recorded by `scripts/provenance.sh`, which emits the commit, the
dirty flag, the Lean and Python versions, and a digest of each example input as
actually parsed rather than as it sits on disk.
