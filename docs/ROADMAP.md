# Roadmap

**If you want one thing to pick up: the MATPOWER case importer for `gridcert`, item 1 in Tier 1 below.** It is the single change most likely to get this repo used by someone other than its author, and it is mostly parsing. Ready-to-file versions of the Tier 1 items are in [GOOD-FIRST-ISSUES.md](GOOD-FIRST-ISSUES.md).

Effort is in focused days for someone who has the context. Each item states what "done" means, so it can be closed rather than argued about.

**Changed by the literature search.** Item 11 (the mathlib bridge) is now higher
value than its tier suggests, because the fit with Doll and Shames' Lean control
library turned out to be exact rather than speculative, and a draft email is in
[LAUNCH.md](LAUNCH.md). Conversely, investing further in `dimcert` has low value:
that ground is already covered, including in Lean 4. See
[RELATED-WORK.md](RELATED-WORK.md).

**Ordering principle: make what exists usable before making the repo bigger.** A sixth tool nobody can run is worth less than `gridcert` with a case importer. Every Tier 1 item beats every Tier 2 item until someone other than the author has run this.

---

## Tier 1 — makes what exists usable (1 to 3 days each)

These are the highest-value items in the document. Every one of them removes a
reason someone bounces off the repo.

**1. A MATPOWER / PSS/E case importer for gridcert.**
Right now the study network is hand-written JSON. Reading `.m` case files and
PSS/E `.raw` would let anyone point gridcert at IEEE 14-bus, 30-bus, 118-bus, or
their own model. This is the single change most likely to get the repo used, and
it is mostly parsing. Watch for: the integer-susceptance requirement, which means
picking a rational scale per case rather than assuming `1/x` is a whole number.

**2. Scale testing on IEEE 118-bus.**
Everything is `decide` on integer arithmetic, and `decide` has a cliff. Find out
where. If 118-bus rows blow up kernel reduction, the fix is `Nat.decEq`-friendly
representations or moving the heavy checks to `native_decide` behind an opt-in
flag, which is a trust-tier decision worth making deliberately and documenting.

**3. Real carbon intensity data for carbonsched.**
The profiles are illustrative and the README says so. Wire in a fetcher for a
real marginal emissions source (WattTime, Electricity Maps, or PJM's own
published data), cache a few real days, and regenerate. The savings numbers then
mean something. Keep the flat-profile scenario.

**4. A worked FE-exam-style tutorial.**
`docs/tutorial.md`: take one tolerance stack and one dimensional check from a
textbook problem, show the hand method, then the certified method. This is the
on-ramp, and it is the piece that connects to work you already do.

**5. Per-project READMEs get a 30-second "what you'd actually run" block.**
They currently open with theory. Lead with the command and the output.

---

## Tier 2 — real capability, real work (1 to 3 weeks each)

**6. Multi-load scheduling with slot capacity (carbonsched).**
The honest hard problem from Stage 3. Several deferrable loads competing for
per-slot capacity is a min-cost bipartite matching, and a threshold no longer
certifies it. You need an LP dual certificate and a sum-over-injection lemma
(`Σ_j v_{σ(j)} ≤ Σ_t v_t` for injective σ), which is the piece core Lean does not
give you. Doable without mathlib but it is the first place a `Finset` would earn
its keep. This is what a real DR program needs.

**7. N-dimensional quadratic certificates (lyapcert).**
`Quad` and `Sq` are hardcoded to two states. The envelope theorems are already
dimension-free, so this is generalizing the certificate checker to lists and
redoing three algebraic lemmas, not redoing the Lyapunov argument. Unlocks
realistic plant models.

**8. Close the `q^(2k)` gap in lyapcert.**
The one paper step in the whole repo. A contracting matrix cannot have integer
entries, so systems are certified through the scaled form `B = qA` and reading
back divides by `q^(2k)`. Degree-two homogeneity is mechanized; the division is
not. Fixing it means rationals, which means `Rat` from core or mathlib. Small,
and it removes the only asterisk.

**9. 2D tolerance stacks and geometric controls (tolstack).**
The 1D case is done properly. 2D vector loops with position tolerances is the
next honest step. Full ASME Y14.5 with MMC bonus tolerance and datum reference
frames is a research programme, not a sprint, and should be described that way.

**10. Non-decimal unit conversions (dimcert).**
`Rescale` covers SI prefix changes. Inches, Btu and non-decimal per-unit bases
are scaling by an arbitrary positive rational. The same proof structure works;
it needs rational arithmetic.

---

## Tier 3 — the mathlib bridge (1 to 2 months)

**11. Port lyapcert to `ℝ` and connect to LeanDynamicalSystems.**
Doll and Shames, arXiv:2607.19727 (Melbourne, July 2026), state stability
through neighborhood filters so one theorem covers points and sets, continuous
and discrete. Their `IsLyapunov V Φ` is exactly "continuous, non-negative,
non-increasing along Φ" — which is exactly what `Cert.V_nonneg` and `Cert.decay`
supply, discharged by computation. Swap `Int` for `ℝ`, keep every proof, hand the
results to `IsLyapunov.isStableOn_nhdsSet`. This is the clean collaboration and
probably an email to the authors before it is a month of work.

**12. AC power flow residual bounds (gridcert).**
The genuine mathlib case, and the one I deliberately did not attempt. Needs
interval arithmetic over the reals and a Newton-Kantorovich existence and
uniqueness ball around a candidate solution. Do not start this before item 11
has taught you how the mathlib dependency actually behaves in CI.

---

## Writing and dissemination

**13. A short paper.** The methodology is the contribution, not any one tool:
certificate-checking makes formal verification tractable for engineering without
a real-analysis library, demonstrated across five unrelated domains. Target
venues: Software Verification in Lean (SVIL, ran April 2026 in Paris, so aim at
the 2027 edition), NFM, or an arXiv preprint in cs.LO cross-listed to eess.SY.
Confirm dates before committing; they may have moved.

**14. The negative results deserve their own writeup.** The RSS-is-not-a-bound
counterexample, the watts-plus-vars blind spot, and the tight forecast-free
competitive ratio are each a short, quotable, genuinely useful piece for a
practicing-engineer audience in a way the proofs are not.

---

## Deliberately not on this list

- **Rewriting the Python solvers in Lean.** The whole design is that search is
  untrusted. Moving it inside would cost the thing that makes the repo tractable.
- **A GUI.** The interface is JSON in, theorem out, and that is correct for CI.
- **Chasing generality before a second user.** Every item in Tier 1 beats every
  item in Tier 2 until someone other than you has run this.
