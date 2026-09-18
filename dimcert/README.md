# DimCert

A machine-checked dimensional-consistency checker for engineering formulas.
Lean 4 for the proofs, Python for the working tool, JSON formula sheets as the
shared input.

This is Stage 1(B) of the Lean-for-mechanical-engineering brief, and it reuses
the shape that worked for Stage 1(A): a decidable check, a soundness theorem
that says what passing the check buys you, a completeness theorem that says
failures are real, and a Python companion that cannot drift from the
formalization because a test compares them byte for byte.

## Try it

```bash
cd python && python3 -m dimcert ../examples/interconnection.json
```
```
ok    base impedance
FAIL  WRONG: base impedance inverted
        lhs: kg m^2 s^-3 A^-2
        rhs: kg^-1 m^-2 s^3 A^2
        detectable by rescaling length by 1 decade
```
Exit code is 1 if any formula fails. When one does, the tool names the change of units that exposes it, which is the `separator` construction from the completeness theorem.

## The idea worth stating precisely

Dimensional analysis works because physical laws do not care what units you
write them in. That is the property this project formalizes rather than assumes.

A change of unit system is modelled as `Rescale`: an integer number of decades
moved per SI base dimension. Metres to kilometres is `length := 3`. `scale`
computes how the numeric value of an expression moves under such a change,
computed structurally from the operations. `infer` computes the expression's
dimension from its symbols. The headline theorem, `Expr.scale_eq_of_infer`, is
that the first is fully determined by the second:

```
infer e = some d  →  scale e r = -(d.decadeShift r)   for every r
```

A well-dimensioned expression scales exactly as its dimension dictates, and no
other feature of its structure matters. Everything else follows from that.

## What is actually proved

No `sorry`, no axioms beyond the standard three. `DimCert/Audit.lean` pins each
result's axiom footprint with `#guard_msgs`, so the build breaks if that stops
being true.

| Claim | Theorem |
| --- | --- |
| A well-dimensioned expression scales exactly as its dimension says | `Expr.scale_eq_of_infer` |
| A dimensionally consistent equation's two sides move identically under any change of units, so its truth cannot depend on the units | `Equation.scale_agree` |
| **Every dimensional error is detectable.** Different dimensions always separate under some explicit change of units | `Equation.separator_detects` |
| Dimensionless quantities have the same numeric value in every unit system, which is why per-unit and Reynolds numbers are comparable at all | `Expr.scale_eq_zero_of_dimensionless` |
| Dimensions form an abelian group, and decade shift is a homomorphism out of it | `Dimension.mul_assoc`, `decadeShift_mul`, `decadeShift_div`, `decadeShift_pow` |
| Square roots are defined exactly when exact, and really are square roots | `Dimension.sqrt?_sq` |
| Surge impedance `√(L/C)` is an impedance, skin depth `√(2ρ/ωμ)` is a length, natural frequency `√(k/m)` is a reciprocal time | `Units.surge_impedance`, `skin_depth`, `natural_frequency` |
| Base impedance `V²/S` is an impedance and per-unit impedance is dimensionless | `Units.base_impedance`, `Formulas.perUnit_is_unit_invariant` |
| 18 power-systems and heat-transfer formulas are consistent | `Formulas.*_checks` |
| 4 deliberately wrong formulas are rejected, and two malformed ones have no dimension at all | `Formulas.*_rejected`, `badSqrt_has_no_dimension` |

72 theorems, 120 definitions, no dependencies. Not even mathlib.

## Prior art: this is a re-instantiation

Dimensional analysis in a type system or proof assistant is **already done**, and
this tool claims no new theorem. Kennedy proved that program behaviour is
invariant under change of units (*POPL* 1997; Cambridge TR-391, 1996), which is
the result this tool's soundness theorem restates; it shipped in F# 2.0. Foster
and Wolff built a verified ISQ/SI type system in Isabelle/HOL (*Archive of Formal
Proofs*, 2020). Bobbin, Jones, Velkey and Josephson formalized dimensional
analysis and Buckingham Pi **in Lean 4** (arXiv:2509.13142, 2025), and Allen's
`lambda-s` claims a machine-checked Pi theorem (2025). Owre, Saha and Shankar
built a dimensional-analysis checker at *FM* 2012.

What is left here is narrow: a dependency-free integer encoding that fits the
rest of this toolchain, and the explicit `S = P + Q` blind spot below. See
[../docs/RELATED-WORK.md](../docs/RELATED-WORK.md).

## What is not proved, and one thing worth staring at

- **Dimensional consistency is necessary, never sufficient.** `S = P + Q` passes
  every check in this library and is wrong: watts, vars and volt-amperes share a
  dimension, so nothing dimensional can separate real from reactive power. That
  case is in the library as `apparentPowerSum`, proved to pass, sitting directly
  above the correct `S = √(P² + Q²)`, which also passes. The checker cannot tell
  them apart. Neither can any dimensional checker, and a tool that hides that
  from you is worse than no tool.
- **Definition fidelity.** Lean guarantees the theorems follow from the
  definitions. It does not guarantee that the dimension you declared for a
  symbol is the dimension that symbol has on your one-line diagram.
- **Unit changes are decimal.** `Rescale` covers SI prefix changes, which is the
  group that matters in practice. Non-decimal conversions (inches, Btu, per-unit
  bases that are not powers of ten) are a scaling by an arbitrary positive
  rational, which the same proof would cover but which would need rational
  arithmetic and therefore mathlib.
- **Integer exponents only.** Half-powers appear only through `sqrt`, which is
  defined exactly when every exponent is even. `√V` has no dimension here, which
  is the honest answer, but a formula genuinely requiring a quarter power would
  need a different exponent type.
- **No affine units.** Celsius and Fahrenheit are not multiplicative and are out
  of scope; temperature here means kelvin.

## Layout

```
DimCert/Dimension.lean  the group of dimensions, and the decade-shift homomorphism
DimCert/Units.lean      SI base and derived dimensions, identities by kernel computation
DimCert/Expr.lean       expression language, inference, and the soundness theorem
DimCert/Formulas.lean   checked formula library, plus rejections and the blind spot
DimCert/Report.lean     rendering
DimCert/Audit.lean      axiom footprint gate
python/dimcert/         same model as a working tool, plus JSON -> Lean codegen
python/tests/            parity against Lean's output, randomized property tests
examples/                a power-systems formula sheet
scripts/verify.sh        everything above, in one command
```

## Use

```bash
lake build                                             # proofs + axiom audit
cd python && python3 -m dimcert --library             # the checked library
python3 -m dimcert ../examples/interconnection.json   # check a formula sheet
./scripts/verify.sh                                    # full gate
```

Exit code is 1 if any formula fails, so a formula sheet can be checked in CI.
When a formula fails, the tool names the change of units that exposes it, which
is the `separator` construction from the completeness theorem.

To get a kernel-checked certificate for your own formula sheet:

```bash
python3 -m dimcert my_formulas.json --lean DimCert/Generated.lean
lake env lean DimCert/Generated.lean
```

Every verdict in the generated module is closed by `decide`, so the numbers the
Python tool prints and the verdicts the Lean kernel signs off on come from the
same JSON.

## Notes on the build

Same choices as Stage 1(A), for the same reasons. Everything is `Int`, so the
arithmetic is linear and `omega` discharges it; `decide` closes every concrete
formula check by kernel computation; there are no dependencies, so nothing can
break when mathlib moves. `set_option autoImplicit false` is on in every file,
which caught a real bug during development where a stray `Rescale` silently
became an auto-bound universe variable instead of the intended type.

## Next

Stage 2 is the Lyapunov control envelope, which is the first project in the
brief that genuinely needs mathlib and an external control-theory library.
Before starting it, confirm that `LeanDynamicalSystems` exists, builds against a
current toolchain, and states what the brief claims it states. If it does not,
the sensible substitute is a discrete-time quadratic Lyapunov argument over
integer or rational matrices, which stays inside the zero-dependency approach
that has now worked twice.
