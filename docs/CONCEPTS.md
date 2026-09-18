# Certificate checking for engineering claims

*The method behind [plumbcert](../README.md), written so it can be lifted into
domains this repo does not cover.*

> **Attribution first.** None of this method is new, and this document does not
> claim it. What follows is the **certifying algorithms** paradigm (McConnell,
> Mehlhorn, Näher and Schweitzer, *Computer Science Review* 5(2), 2011), which
> descends from program checking (Blum and Kannan, *JACM* 42(1), 1995) and
> proof-carrying code (Necula, *POPL* 1997). Applying it inside a proof
> assistant to certificates from untrusted numerical search is likewise
> established practice, notably in the sums-of-squares community (Harrison,
> *TPHOLs* 2007; Monniaux and Corbineau, *ITP* 2011; Roux, Voronin and
> Sankaranarayanan, *SAS* 2016). This document is a practitioner's write-up of
> how to apply that established method to engineering artifacts, not a proposal
> of a new one. See [RELATED-WORK.md](RELATED-WORK.md).

## The problem

Formal verification has a reputation in engineering as something you do for
avionics software with a budget and a team. The obstacle is usually assumed to
be effort. It is more often **reachability**: the theorem you want is about
continuous quantities, so proving it needs real analysis, so you need a large
mathematics library, so you inherit its build times, its version churn, and a
learning curve that has nothing to do with your domain.

Meanwhile the actual engineering artifacts are small. A tolerance chain is a
dozen numbers. A PTDF row is one number per bus. A Lyapunov function for a
two-state plant is three coefficients. The *objects* are tractable; it is the
*mathematics used to reason about them* that is not.

## The move

Separate finding from checking, and put the boundary where the object is small.

```
   Python (untrusted)                    Lean (trusted)
   ─────────────────────                 ──────────────────────
   floating point, heuristics,           integer arithmetic,
   linear algebra, search       ──────►  decide, omega, grind
                             certificate
   "here is the answer, and              "this certificate does
    here is why you can                   in fact establish the
    check it cheaply"                     engineering claim"
```

The search side may be arbitrarily sophisticated and is never trusted. A bug
there produces a certificate the kernel rejects. It cannot produce a false
theorem, because the kernel does not read the search; it reads the certificate
and re-derives the claim.

This is the shape of **proof-carrying code** (Necula, 1997), where a compiler
ships a proof its consumer checks cheaply, and of **certifying algorithms**
generally, whose stated purpose is to reduce the consumer's task "from the level
of proving to the level of checking" (McConnell et al., 2011). The only thing
varied here is the domain: the consumer is an engineer's CI pipeline and the
claim is about a physical artifact rather than a program.

## Why it removes the dependency

Once the boundary is drawn there, the checking side stops needing analysis.

Every project in this repo carries physical quantities as **integers at a fixed
scale**: micrometres for lengths, integer susceptances for a network, kg CO₂ per
MWh for intensity, exponent vectors for dimensions. Rationals appear in the
solver and are cleared to integers before they cross. The consequence is that
every inequality the kernel has to settle is linear over `ℤ`, which `omega`
closes, and every concrete instance is a finite computation, which `decide`
closes.

None of the five projects depends on mathlib, or on anything else.

## The recurring trick: arrange positivity, don't prove it

This is the technique that does the most work, and it generalizes well beyond
these five tools.

Many engineering guarantees reduce to "this quantity is non-negative
everywhere". Proving that directly is the hard part: for a quadratic form it
means positive semidefiniteness, which needs Sylvester's criterion or a spectral
argument, which needs real analysis.

So don't ask. Require the quantity to *arrive already in a form whose
non-negativity is syntactic*:

- A **sum of weighted squares** `Σ cᵢ (aᵢx + bᵢy)²` with `cᵢ ≥ 0` is non-negative
  by `0 ≤ z * z`, with no spectral theory. (`lyapcert`)
- A **threshold** `θ` separating chosen from unchosen items turns an optimality
  claim into a slot-by-slot list induction, replacing an exchange argument over
  permutations. (`carbonsched`, and the same shape in `tolstack`)
- An **explicit witness at each extreme** turns "the interval is exact, not
  conservative" into two evaluations. (`tolstack`, `gridcert`)

In each case the search side does the hard work of finding the form, which is
where sophistication belongs, and the kernel gets a syntactic check.

## Soundness is not enough: also be complete

A checker that never wrongly accepts is sound. A checker that also never wrongly
rejects is complete, and completeness is what makes the tool usable.

Every checker here proves both, and completeness is stated constructively: a
rejection returns **the specific counterexample**, proved admissible. The
assembly that violates the window. The dispatch that overloads the branch. The
schedule that would have been cheaper.

An engineer who is told "this fails" and not "here is what fails" cannot act.
Constructive completeness is the difference between a verification result and a
usable tool, and it costs almost nothing once the extremes are already witnessed.

## Compilation is not verification

A Lean build passing means the files elaborate. It does **not** mean the theorems
you care about are proved:

- a proof may contain `sorry` and still compile, with only a warning
- a proof may rest on an axiom you did not intend
- a theorem may be *restated* into something trivially true

The first two are mechanically detectable, so detect them mechanically. Every
project has an `Audit.lean` that pins each headline result's exact axiom
footprint:

```lean
/-- info: 'GridCert.screen_sound' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.screen_sound
```

If any result ever comes to depend on `sorryAx`, the build breaks rather than
warns. Test the gate by planting a `sorry` and confirming failure; an untested
gate is not a gate.

The third failure mode — a theorem restated into vacuity — is not mechanically
detectable and needs a human reading the statement. Two things help: state the
claim with the rival **universally quantified** (`∀ alt, ...` rather than
`∀ alt ∈ someList, ...`), and cross-check against an independent implementation.
Both are done here.

## Where the boundary is drawn matters

The method's leverage comes from choosing a boundary where the certificate is
small. That choice is a design decision, and it can be made badly.

A worked example from `gridcert`. The first version certified a sensitivity row
by checking it against the flow at the *binding dispatch*. Perturbing a row
entry by one unit still passed, because that bus happened to inject zero at the
binding point. The check was partly vacuous. The fix was to certify every
column against a unit-injection solution, at which point all four perturbations
fail the build.

The lesson is general: **a certificate must pin down the whole object, not the
part the current instance happens to exercise.** Test that by perturbing the
certificate and confirming rejection. If a perturbation passes, the boundary is
in the wrong place.

## When this is the wrong approach

- **The object genuinely is continuous.** AC power flow is transcendental. A
  certificate for it is a Newton-Kantorovich existence ball, and checking that
  needs interval arithmetic over `ℝ`, which needs mathlib. Reach for the library
  rather than contorting to avoid it.
- **There is no succinct certificate.** Some claims have no witness smaller than
  the search. Then verify the algorithm rather than its output.
- **The modelling gap dominates.** If the honest uncertainty is whether your
  matrix is your plant, proving things about the matrix is not where the risk
  is. Say so, prominently, and go measure something.

## Checklist for a new domain

1. Name the claim, with the alternatives universally quantified.
2. Find a certificate that makes the claim syntactically checkable, and check
   that it pins the whole object.
3. Choose an integer or rational encoding so the check is linear arithmetic.
4. Prove soundness, and prove completeness constructively.
5. Put the search in an untrusted language, and have it emit the certificate.
6. Pin the axiom footprint, and test the gate.
7. Write down what is **not** proved, at the same prominence as what is.

Step 7 is not decoration. It is the step that makes the other six trustworthy.
