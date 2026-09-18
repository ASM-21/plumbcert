# LyapCert

Machine-checked Lyapunov stability certificates for discrete-time systems. An
exact rational solver in Python finds the certificate; Lean re-checks it by
kernel computation and derives the stability envelope from it. Nothing about the
solver is trusted.

This is Stage 2 of the Lean-for-mechanical-engineering brief, done the
zero-dependency way after checking what the alternative would have cost. See
"On not using LeanDynamicalSystems" below, which is the part worth reading.

## Try it

```bash
cd python && python3 -m lyapcert ../examples/systems.json
```
```
ok    agc: V decays by <= 8241/10000 per step (0.8241), state norm by <= 0.9078
        integer dynamics B = ((8, -2), (1, 9)), scale q = 10
        V = 424747(267x + 10y)² + 57568509392(0x + 1y)²
```
Add your system's A matrix to the JSON as exact rationals. If it is not stable the solver says so and exits non-zero; if it is, the generated Lean module either compiles or the certificate was wrong.

## The design decision that makes this work

The hard part of a quadratic Lyapunov certificate is proving a matrix is
positive semidefinite. Sylvester's criterion or a spectral argument both need
real linear algebra, which means mathlib.

So the certificate never asks. A candidate Lyapunov function arrives already
written as a sum of weighted squares,

```
V(v) = Σ cᵢ (aᵢ x + bᵢ y)²      with every cᵢ ≥ 0
```

which makes `V ≥ 0` immediate from `0 ≤ z * z`. The decay condition arrives with
a second sum of squares certifying an identity between quadratic forms:

```
num · V(v) - den · V(M v) = S(v)
```

Both sides are quadratic, so that identity is an equality of three integers:
decidable, and checked by `decide`. Positivity that would have needed real
analysis becomes a finite integer computation, and the search that produced it
happens outside the trusted base entirely.

## What is actually proved

No `sorry`, no axioms beyond the standard three. `LyapCert/Audit.lean` pins each
result's axiom footprint with `#guard_msgs`.

| Claim | Theorem |
| --- | --- |
| **Certified envelope.** Every sublevel set of V is forward invariant: a state that starts inside never leaves, for all time | `Cert.sublevel_invariant` |
| **Geometric decay.** `V(x_k) ≤ (num/den)^k V(x_0)`, denominators cleared so no division is needed | `Cert.envelope` |
| **Certified settling.** If the integers say `num^k V(x_0) ≤ den^k c`, the state is inside level set `c` after `k` steps | `Cert.settles` |
| A non-expansive certificate makes V non-increasing along the whole trajectory | `Cert.nonincreasing` |
| The Boolean certificate check implies the decay inequality **at every state**, not at sampled ones | `Cert.decay` |
| A sum of squares with non-negative weights is non-negative everywhere | `SOS.eval_nonneg` |
| Pulling a quadratic form back along a linear map is what the composed form computes, which is what lets a matrix identity stand for a statement about every state | `Quad.eval_compose` |
| Quadratic forms are homogeneous of degree two | `Quad.eval_scaleVec` |
| The worked systems certify: a sampled load-frequency control loop, a lossless LC exchange, a deadbeat pipeline | `Examples.*_valid` |

42 theorems, 26 definitions, no dependencies. Not even mathlib.

The Lyapunov argument itself (`LyapCert/Envelope.lean`) is proved for an
arbitrary state type and an arbitrary `V : S → Int`. It knows nothing about
matrices or dimensions. Only the certificate checker is two-dimensional.

## On not using LeanDynamicalSystems

The brief cited a Lean control-theory library, and I flagged at the end of Stage
1 that I could not confirm it existed. It does: Doll and Shames,
*Foundations of Machine-Checked Control Theory in Lean*, arXiv:2607.19727, 22
July 2026, University of Melbourne. The library is real, it is on GitHub, and it
is well designed: stability is stated through neighborhood filters, so one
theorem covers points and sets, and continuous, discrete and hybrid systems at
once. Its `IsLyapunov V Φ` is exactly "V is continuous, non-negative, and
non-increasing along Φ".

It is built on mathlib, which is the reason this stage did not use it: mathlib
could not be built in the environment this was developed in, and an unverified
deliverable would have defeated the point of the exercise. That is an
environment constraint, not a criticism of the library.

The two fit together rather than compete. That library states the general
theorem and needs someone to supply its hypotheses. This one supplies exactly
those hypotheses, for the quadratic case, by computation: `Cert.V_nonneg` and
`Cert.decay` are non-negativity and non-increase, discharged from a Boolean
check. Porting is a small job: replace `Int` with `ℝ`, keep every proof, and
hand the results to `IsLyapunov.isStableOn_nhdsSet`. If you want the general
theory, that is the move, and it is the natural Stage 2b.

## Prior art: this is a re-instantiation

Finding a sum-of-squares certificate numerically and re-checking it exactly in a
proof assistant is **standard practice** in the SOS verification community, not
an idea introduced here. Harrison did it in HOL Light (*TPHOLs* 2007); Monniaux
and Corbineau generated Positivstellensatz witnesses for Coq (*ITP* 2011); Roux,
Voronin and Sankaranarayanan addressed exactly the untrustworthy-floating-point-SDP
problem (*SAS* 2016, *FMSD* 2018); Magron and others followed. Doll and Shames
formalized Lyapunov stability in Lean itself (arXiv:2607.19727, 2026).

What is left here is the Lean 4, mathlib-free, scaled-integer instantiation, and
one observation worth acting on: `Cert.V_nonneg` and `Cert.decay` discharge by
computation precisely the hypotheses that Doll and Shames' `IsLyapunov` requires,
so the two fit together rather than compete. See
[../docs/RELATED-WORK.md](../docs/RELATED-WORK.md).

## What is not proved

- **Two states.** The certificate checker is 2x2. The envelope theorems are
  dimension-free already, so extending means generalizing `Quad` and `Sq` to
  lists and redoing three algebraic lemmas, not redoing the Lyapunov argument.
- **Integer dynamics, and the one paper step.** A matrix with all eigenvalues
  strictly inside the unit circle cannot have integer entries, so a contracting
  system is certified through its scaled integer form `B = qA`. Reading the
  result back to `A` divides by `q^(2k)`, which needs rationals and so is stated
  in the doc comments rather than mechanized. The ingredient that licenses it,
  degree-two homogeneity, **is** mechanized (`Quad.eval_scaleVec`). Systems with
  integer dynamics (the lossless tank, the deadbeat pipeline) have no such gap
  and their envelope theorems apply directly.
- **Discrete time only.** No flows, no Lie derivatives, no sampling error. A
  certificate here says nothing about the continuous system the difference
  equation came from, including nothing about what happens between samples.
- **Synthesis is not verified, and does not need to be.** The Python solver could
  be wrong in any way at all and the Lean theorems would still hold, because the
  kernel re-derives everything from the certificate. What a solver bug costs you
  is a rejected certificate, not a false one.
- **The rate is not optimal.** The decay factor comes from a scan over rationals
  with an exact PSD test at each step, seeded by a float estimate. It finds a
  sound rate, not the tightest one. V can never decay faster than the square of
  the spectral radius, and the search stops when it finds something valid above
  that floor.
- **Nothing about the model.** As always: Lean checks that the theorems follow
  from the definitions, not that your A matrix is your plant.

## Layout

```
LyapCert/Arith.lean      the small integer toolkit, built from core lemmas
LyapCert/Envelope.lean   the Lyapunov argument, dimension-free
LyapCert/Quadratic.lean  quadratic forms, sums of squares, the certificate checker
LyapCert/Examples.lean   generated: three systems, checked by decide
LyapCert/Audit.lean      axiom footprint gate
python/lyapcert/exact.py exact rational synthesis, no floating point in the certificate path
python/lyapcert/codegen.py  certificate to Lean
examples/systems.json    the systems
scripts/verify.sh        everything above, in one command
```

## Use

```bash
lake build                                              # proofs + audit
cd python && python3 -m lyapcert ../examples/systems.json
python3 -m lyapcert ../examples/systems.json --lean ../LyapCert/Examples.lean
./scripts/verify.sh                                     # full gate
```

Add a system by adding its A matrix to `examples/systems.json` as exact
rationals, regenerate, and build. If the system is not stable the solver says so
and exits non-zero; if it is, the generated module either compiles or the
certificate was wrong, and there is no third outcome.

## The worked systems

**Load-frequency control loop**, sampled at 0.1 s, states frequency deviation
and governor setpoint. Certified decay of V of 0.8241 per step, so the state
norm contracts by about 0.9078 per step. The spectral radius is 0.8602, so the
certificate is close to tight and provably cannot be better than 0.74 for V.

**Lossless LC exchange**, a quarter-period step. V is exactly invariant, the
slack is empty, and the envelope theorem applies directly to the system with no
scaling: energy in, energy stays. This is the case where a marginally stable
system has no solution to the Lyapunov equation at all and the solver falls back
to the identity form.

**Deadbeat pipeline**, two taps. V halves each step and hits zero at step two,
certified from the initial state ⟨12, 5⟩ by `decide`.
