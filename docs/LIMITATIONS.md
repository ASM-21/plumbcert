# Limitations and blockers, stated once

Everything this repo cannot do, in one place, so it does not have to be
reconstructed from five READMEs. Scoped honestly: a named blocker with what was
tried and what would unblock it reads as discipline; a vague one reads as
abandonment.

## The limit that dominates all others

**Lean guarantees the theorems follow from the definitions. It does not
guarantee the definitions model reality.** A tolerance chain that omits a
contributor is still provably correct about the chain it was given. A sensitivity
row certified against a network is certified against *that* network, not against
the as-built system. If the honest uncertainty in your problem is whether the
model is the plant, this repository proves things on the wrong side of that gap
and says so.

Nothing below is a bigger risk than this paragraph.

## Blocked: real measured data

**What is blocked.** Three of the five tools ship synthetic or hand-shaped
inputs rather than measured data.

- `carbonsched` intensity profiles are shaped by hand to resemble a summer
  weekday. They are **not** measured marginal emissions from any grid operator.
- `gridcert` uses a synthetic five-bus teaching network with invented ratings and
  an invented interconnection request.
- `tolstack` and `lyapcert` inputs are invented.

**Why.** Two reasons, and they are different. Marginal emissions data from
WattTime and Electricity Maps is available but licensed in ways that make
redistribution inside a repository the wrong call, so it was deliberately not
bundled rather than quietly used. Utility network models are not public at all,
and the maintainer's access to non-public models through his employer is
precisely the access that must not be used here (see the independence statement
in the README).

**What was tried.** Public test cases exist and are the right unblock: MATPOWER
ships IEEE 14, 30, 57 and 118-bus cases under a permissive license, and those are
reachable. They are not yet wired in because `gridcert` requires integer
susceptances, which needs a per-case rational scaling step.

**What would unblock it.** The MATPOWER importer, which is the highest-value open
item in the repo. See [GOOD-FIRST-ISSUES.md](GOOD-FIRST-ISSUES.md). For
`carbonsched`, a fetcher that caches a few real days locally without
redistributing the dataset.

**Consequence for the claims.** The verification results do not depend on the
data being real: every theorem is about the input it is given. But the *savings
percentages and margins are illustrative*, and no claim in this repo should be
read as a measurement of any real system.

## Not proved: scale

Every concrete check is `decide` on integer arithmetic, and kernel reduction has
a performance cliff. Its location is **unknown**. The five-bus network is
comfortable; 118-bus is untested. If it turns out badly, the fallback is
`native_decide`, which moves the compiler into the trusted base and is a real
trust-tier decision, not a free speedup. That would be documented as an opt-in
rather than adopted silently.

## Not proved: per tool

- **gridcert.** DC only: no reactive power, no voltage magnitudes, no losses, flat
  voltage profile, small-angle approximation. Thermal limits only, so no voltage,
  stability or short-circuit screening. N-1, not N-1-1, and no generator
  contingencies. The box is an input: if the real operating envelope is wider
  than the box, a pass proves nothing about the dispatches left out. **This is
  where a screening study is most likely to be wrong, and formalization does not
  help with it.**
- **tolstack.** 1D only. No datum reference frames, no MMC/LMC bonus tolerance, no
  geometric controls, no angular contributions. Full ASME Y14.5 is a research
  programme, not a sprint.
- **carbonsched.** One load, one machine. Multiple loads competing for slot
  capacity is min-cost matching and needs an LP dual, which a threshold
  certificate cannot supply. Preemption is free; contiguity and startup costs are
  not modelled. The intensity profile is an input and nothing here forecasts it
  or quantifies forecast error.
- **lyapcert.** Two states. Discrete time only, so nothing about the continuous
  system the difference equation came from, including nothing between samples.
  One paper step remains: a contracting matrix cannot have integer entries, so
  systems are certified through a scaled integer form and reading back to the
  real system divides by `q^(2k)`, which is stated in a doc comment rather than
  mechanized. Degree-two homogeneity, the ingredient that licenses it, *is*
  mechanized.
- **dimcert.** SI prefix changes only; non-decimal conversions (inches, Btu) need
  rational arithmetic. Integer exponents only. No affine units, so no Celsius or
  Fahrenheit. And the method's own ceiling: dimensional consistency is necessary,
  never sufficient. `S = P + Q` passes and is wrong.

## Deliberately not used

Sources that were reachable but not used, named so their absence is not mistaken
for oversight:

- **WattTime / Electricity Maps marginal emissions.** Reachable; licensing makes
  redistribution inappropriate. Would be fetched-and-cached, not bundled.
- **Any non-public utility network model, load forecast, or interconnection study
  data.** Excluded on independence grounds, permanently, regardless of
  availability.
- **mathlib.** Reachable and excellent. Not used because carrying quantities as
  scaled integers makes it unnecessary, and the dependency-free property is worth
  more here than the generality. The one place this visibly costs something is
  the `lyapcert` `q^(2k)` step above. For AC power flow it would stop being the
  right call.

## No regulatory precedent

No regulator accepts machine-checked proofs for engineering studies. FERC Order
No. 2023, NERC TPL-001, IEEE 1547 and ASME Y14.5 contain no requirement or
guidance for formal verification of study software. The auditability argument in
this repo is a **proposal**, and documented industry concern about interconnection
(LBNL's *Queued Up*) is about throughput and process, not software correctness.
Nothing here should be cited as evidence of regulatory acceptance.
