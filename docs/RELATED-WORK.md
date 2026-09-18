# Related work, and what the search changed

This file exists because the literature search happened *after* the code worked,
not before. That ordering was deliberate: the point was to find out whether the
results were already known, not to find a frame for them in advance.

It cost the project its headline claim. That is recorded here rather than
quietly fixed.

## What the framing was, and what it is now

**Before.** The repo led with "proof-carrying engineering" as though the
methodology were the contribution: untrusted search emits a certificate, the
kernel re-derives the claim.

**After.** That methodology is the **certifying algorithms** paradigm, and it is
decades old. The honest claim is that this work is *a measured demonstration of
a known technique across engineering domains that had not previously received
proof-assistant treatment*. The contribution is domain transfer and the
artifacts themselves, not the method.

The ancestors, which are now cited rather than reinvented:

- Blum and Kannan, "Designing programs that check their work," *JACM* 42(1),
  1995 — program checking.
- Necula, "Proof-Carrying Code," *POPL*, 1997 — a producer ships a proof its
  consumer checks cheaply. The direct namesake.
- McConnell, Mehlhorn, Näher and Schweitzer, "Certifying algorithms,"
  *Computer Science Review* 5(2):119–161, 2011 — the survey that names the
  paradigm and states its purpose as reducing the consumer's task "from the
  level of proving to the level of checking." This is precisely the design
  used here.
- Rizkallah, Alkassar, Böhme, Mehlhorn and others — formally verified
  certificate *checkers* in Isabelle/HOL and Coq.

The name "proof-carrying engineering" also turns out not to be free in spirit: a
2026 Lean 4 paper on q-ary covering codes (arXiv:2606.09600) already uses the
phrase "proof-carrying certificates ... in Lean 4." The coinage is therefore
dropped as a claim and used, if at all, only as descriptive shorthand.

## Per-tool assessment

Graded honestly. "First formalization" is a much weaker claim than "new result,"
and in every case below the underlying engineering fact was already known in its
own field.

### tolstack — first formalization, known result

No formalization of worst-case tolerance stack-up, GD&T or ASME Y14.5 in any
proof assistant was found (Lean, Coq, Isabelle, PVS, ACL2). The Lean development
appears to be first of its kind.

But **RSS being non-conservative is standard engineering knowledge**, not a
discovery. It is stated in the tolerance literature (Fischer, *Mechanical
Tolerance Stackup and Analysis*; Drake, *Dimensioning and Tolerancing
Handbook*; Creveling, *Tolerance Design*) and even in patent prose. The repo
previously presented `rss_check_unsound` with an emphasis that implied novelty.
It is now presented as **known in the tolerance literature, here machine-checked
with an explicit counterexample**.

### dimcert — re-instantiation, not novel

This is the area where the search was most deflating, and the tool has been
demoted accordingly.

- Kennedy, "Relational Parametricity and Units of Measure," *POPL* 1997, and
  his Cambridge thesis (TR-391, 1996), already prove the theorem this tool's
  headline result restates: program behaviour is invariant under change of
  units. Shipped in F# 2.0 (2010). His WMM 2008 work mechanised the Abelian
  group structure of units in Coq.
- Foster and Wolff, "A Sound Type System for Physical Quantities, Units, and
  Measurements," *Archive of Formal Proofs* (`Physical_Quantities`, 2020),
  integrate ISQ and SI into Isabelle/HOL with verified conversions.
- Bobbin, Jones, Velkey and Josephson, "Formalizing Dimensional Analysis Using
  the Lean Theorem Prover," arXiv:2509.13142 (2025), prove dimensions form an
  Abelian group **in Lean 4** and implement Buckingham Pi via matrix rank.
- Allen, `lambda-s` (Lean 4, 2025), claims a machine-checked Buckingham Pi
  theorem with parametricity results.
- Owre, Saha and Shankar, "Automatic Dimensional Analysis of Cyber-Physical
  Systems," *FM* 2012 — a dimensional-analysis checking tool.

**Verdict: already done, including in Lean 4.** `dimcert` claims only a
dependency-free integer encoding that fits the rest of this toolchain. The
scale-invariance theorem and anything Pi-adjacent are explicitly *not* claimed
as new.

### lyapcert — re-instantiation, not novel

The float-search-then-exact-rational-recheck loop for sums of squares is this
community's standard practice and has been since:

- Harrison, "Verifying Nonlinear Real Formulas via Sums of Squares," *TPHOLs*
  2007 (HOL Light).
- Monniaux and Corbineau, "On the Generation of Positivstellensatz Witnesses in
  Degenerate Cases," *ITP* 2011.
- Roux, Voronin and Sankaranarayanan, "Validating Numerical Semidefinite
  Programming Solvers for Polynomial Invariants," *SAS* 2016 / *FMSD* 53(2),
  2018 — which addresses exactly the "floating-point SDP output is untrustworthy
  and needs exact re-checking" problem.
- Magron et al., formal proofs for nonlinear optimisation, and NLCertify.
- Doll and Shames, "Foundations of Machine-Checked Control Theory in Lean,"
  arXiv:2607.19727 (2026) — Lyapunov stability in Lean, the nearest competitor,
  taking the opposite mathlib-heavy approach.

**Verdict: the core idea is standard.** What remains is the Lean 4, mathlib-free,
scaled-integer instantiation, and the observation that `Cert.V_nonneg` and
`Cert.decay` discharge by computation exactly the hypotheses Doll and Shames'
`IsLyapunov` requires. That complementarity is the interesting part and is worth
an email to those authors.

### carbonsched — first formalization, known result

The competitive-ratio result is not new. It descends from El-Yaniv, Fiat, Karp
and Turpin, "Optimal Search and One-Way Trading Online Algorithms,"
*Algorithmica* 30(1):101–139, 2001, whose threat-based strategy is optimal with
a ratio governed by the max/min price ratio. Lechowicz et al., "The Online Pause
and Resume Problem," *ACM POMACS* 7(3), 2023, apply precisely this to
carbon-aware load shifting and prove their competitive ratios are the best
achievable by any deterministic online algorithm. Google's carbon-intelligent
computing (Radovanovic et al., *IEEE Trans. Power Systems* 38(2), 2023) is the
practical ancestor.

**Verdict: the bound is a restatement of one-way-trading theory; the machine
checking of it appears to be new.** The repo now says so. Note also that the
ratio proved here is the simple spread `hi/lo` for the *offline-optimal
comparison over a fixed window*, which is not the same object as the classic
`ln θ + 1` one-way-trading ratio; the README no longer implies otherwise.

### gridcert — the strongest claim

Power flow, PTDF, LODF and N-1 screening are vast engineering literatures with
essentially no interactive-theorem-prover treatment. Certified *solvability*
work exists but is analysis rather than machine-checked: Yu, Nguyen and
Turitsyn, "Simple certificate of solvability of power flow equations for
distribution systems," *IEEE PES GM* 2015; Bolognani and Zampieri, *IEEE Trans.
Power Systems* 31(1), 2016. N-1 screening in practice is pointwise, sampled, or
MILP-based.

**Verdict: kernel-checked N-1 screening over a box of operating points rather
than sampled points appears to be genuinely first.** This is where the
investment should go, and the README now leads with it.

### Lean mechanics — established community practice

The kernel-`decide` versus `native_decide` trust distinction, the kernel
reduction performance cliff, and axiom pinning as a CI gate are all documented
community knowledge, including in several 2026 Lean artifacts (PBLean
arXiv:2602.08692; LRAT-Catcher arXiv:2607.00815; "Faults in Our Formal
Benchmarking" arXiv:2606.29493, which notes `native_decide` "expands the trusted
computing base beyond the kernel" and that codegen bugs "have produced proofs of
False").

**Verdict: no contribution.** The `Audit.lean` discipline is good practice, not
an idea. The "compilation is not verification" point is not original and is now
attributed.

### Regulatory record — no precedent, so it is advocacy

FERC Order No. 2023 (2023) and Order 2023-A (2024) reform interconnection queue
processing. NERC TPL-001 embeds the N-1 criterion. IEEE 1547 governs DER
interconnection. ASME Y14.5 governs GD&T. **None reference formal verification
or certificate-based validation of study software, and no regulator is known to
accept machine-checked proofs for engineering studies.**

Documented concern about interconnection exists but is about throughput, not
software correctness: LBNL's *Queued Up* (2024 edition) reports that only 19% of
projects seeking connection from 2000–2018 had been built by end of 2023.

**Therefore the auditability argument in this repo is labelled as a proposal,
not as a response to a regulatory requirement.** Nothing here implies current
acceptance by any regulator.

## What the search did not settle

- PVS and ACL2 were not exhaustively searched for tolerance or power-systems
  formalizations. If a prior tolerance formalization exists there, `tolstack`
  drops from "first artifact" to "rediscovery."
- Allen's Buckingham Pi claim is self-hosted and its venue unconfirmed; it was
  not read at source.
- Doll and Shames (arXiv:2607.19727) was not read in full. If it already does
  SOS-certificate Lyapunov *checking*, `lyapcert`'s residual novelty disappears
  entirely.
- No published certified contingency-screening tool from an RTO/ISO or the
  ARPA-E Grid Optimization Competition was found, but those proceedings were not
  searched exhaustively. If one exists, `gridcert`'s claim weakens.

Corrections on any of these are welcome and will be recorded here.
