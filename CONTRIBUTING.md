# Contributing

The bar for anything merged here is that `scripts/verify-all.sh` passes, which
means every theorem type-checks, no proof depends on `sorry`, and every
generated certificate is current with the solver that produced it.

## Ground rules

1. **No `sorry`, ever.** The audit modules make this a build failure rather than
   a convention, so a `sorry` will not get past CI even if review misses it.
2. **No dependencies without a reason you can state.** Every project here is
   dependency-free, including of mathlib. That is a deliberate constraint, not
   an accident. If a change needs mathlib, say in the PR what it buys and why
   integer or rational arithmetic will not do.
3. **New results go in the audit module.** If you add a headline theorem, add a
   `#guard_msgs`-pinned `#print axioms` line for it.
4. **The solver is never trusted.** Search happens in Python; Lean re-derives
   the claim from the certificate. If you find yourself wanting Lean to accept a
   number because the Python computed it, that is the thing this repo exists to
   avoid.
5. **State what is not proved.** Every README has a "what is not proved"
   section. If your change moves that line, move the section with it.

## Adding a project

Follow the shape the others use: a `Basic`-style model module, a soundness or
optimality module, a generated `Examples` module, an `Audit` module, a Python
companion with codegen, and a `scripts/verify.sh` that runs all of it. Add it to
the matrix in `.github/workflows/ci.yml` and to `scripts/verify-all.sh`.
