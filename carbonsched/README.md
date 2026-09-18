# CarbonSched

Machine-checked optimality for carbon-aware scheduling of deferrable loads. A
Python scheduler picks the slots and emits a one-integer certificate; Lean
re-checks the certificate and derives optimality against **every** alternative
schedule, not just the ones an algorithm would consider.

This is Stage 3 of the Lean-for-mechanical-engineering brief.

## Try it

```bash
cd python && python3 -m carbonsched ../examples/scenarios.json
```
```
ok    industrial batch: 1924 over slots [9, 10, 11, 12, 13, 14] (threshold 344)
        allowed range [303, 561], forecast-free worst case 1.85x
        vs run now: 2989 -> 1924, saves 1065 (35.6%)
```
The threshold is the certificate. Lean uses it to prove no other schedule of the same length costs less, quantified over every alternative rather than the ones an algorithm would consider.

## The idea

The usual way to prove a greedy scheduler optimal is an exchange argument over
permutations, which needs a lot of machinery. This development does not do that.

A schedule is a `List Bool` over slots. The certificate is a threshold `θ`:

- every slot the schedule **occupies** costs at most `θ`
- every slot the schedule was **allowed** to occupy but didn't costs at least `θ`

Both halves are decidable, so `decide` checks them. And that is enough, because
of one invariant that is an ordinary list induction:

```
cost m p - cost m' p  ≤  θ * (count m - count m')
```

Slot by slot: one the certified schedule takes and the rival doesn't costs at
most `θ` and moves the count by one; one the rival takes and the certified
schedule doesn't costs at least `θ` and moves it back. When both schedules run
the load for the same number of slots, the right side is zero. That is
optimality, with no sorting, no permutations, and no assumption that the profile
is sorted or that the certified schedule came from any particular algorithm.

## What is actually proved

No `sorry`, no axioms beyond the standard three. `CarbonSched/Audit.lean` pins
each result's axiom footprint with `#guard_msgs`.

| Claim | Theorem |
| --- | --- |
| **A threshold certificate proves optimality.** No allowed schedule of the same length costs less. The rival is universally quantified | `optimal`, `certified_optimal` |
| The same, against a baseline that over-runs (given a non-negative threshold) | `optimal_le_longer` |
| **Proved savings** against any baseline: run-now, a fixed night shift, or last week's actual | `savings_certified` |
| **Competitive ratio without a forecast.** If allowed intensities lie in `[lo, hi]`, any policy is within `hi/lo` of optimal. Cleared denominators, so no division | `online_ratio` |
| **That ratio is tight.** An explicit two-slot instance where a policy committing without a forecast pays exactly `hi` while the optimum pays exactly `lo` | `online_ratio_tight`, `tight_offline_certified` |
| Per-slot cost bounds underlying the ratio | `cost_le_of_selLe`, `cost_ge_of_selGe` |
| Three scenarios certified optimal, with proved savings against their baselines | `Examples.*_optimal`, `Examples.*_beats*` |

30 theorems, 30 definitions, no dependencies. Not even mathlib.

## The part worth arguing about

Carbon-aware scheduling gets sold on savings numbers. Two different claims wear
that label and they are not equally strong:

**What a certified schedule saves against a baseline** is exact and
instance-specific. The industrial batch scenario below saves 35.6% against
running immediately, and that inequality is proved.

**What a scheduler can guarantee without a forecast** is a worst-case ratio, and
it is exactly the intensity spread of the feasible window. `online_ratio_tight`
exhibits an instance where a policy that must commit blind really does pay the
full ratio, so the bound cannot be improved by being cleverer. The only way past
it is a forecast. That is the argument for paying for one, and it is the part
usually left out.

The `flat profile` scenario is in the library for the same reason the
RSS counterexample is in Stage 1(A): on a day with no carbon signal the optimal
schedule saves 0.2%, and a tool reporting large savings on a day like that is
reporting a bug.

## Prior art: the bound is known, the proof is new

The competitive bound proved here is **not a new algorithmic result**. It
descends from El-Yaniv, Fiat, Karp and Turpin, "Optimal Search and One-Way
Trading Online Algorithms" (*Algorithmica* 30(1), 2001), whose threat-based
strategy is optimal with a ratio governed by the max/min price ratio. Lechowicz
et al. apply that theory directly to carbon-aware load shifting and prove their
ratios best-achievable for deterministic online algorithms (*ACM POMACS* 7(3),
2023). Google's carbon-intelligent computing (Radovanovic et al., *IEEE Trans.
Power Systems* 38(2), 2023) is the practical ancestor.

Note also that the `hi/lo` spread proved here is the bound for comparison against
the offline optimum over a *fixed window*, and is not the same object as the
classic `ln θ + 1` one-way-trading ratio. What appears to be new is the machine
checking. See [../docs/RELATED-WORK.md](../docs/RELATED-WORK.md).

## What is not proved

- **One load, one machine.** Multiple loads competing for slot capacity is a
  min-cost matching, and a threshold no longer certifies it; that needs an LP
  dual and a sum-over-injection lemma. The clean next step, and genuinely harder.
- **Preemption is free.** The load can occupy any set of allowed slots. A
  process that must run contiguously, or that pays a startup penalty, is a
  different problem and this says nothing about it.
- **The profile is an input.** Nothing here forecasts marginal intensity,
  quantifies forecast error, or distinguishes average from marginal emissions
  factors. Feed it the wrong profile and it will optimally schedule against the
  wrong day.
- **The horizon is fixed and slotted.** No rolling horizon, no re-planning, no
  intra-slot dynamics.
- **Savings percentages are arithmetic, not theorems.** The *inequality*
  `baseline ≥ certified` is proved and so are both costs; the percentage is
  division on two proved numbers, stated in doc comments.

## Layout

```
CarbonSched/Basic.lean       schedules as masks, cost, feasibility, baselines
CarbonSched/Optimality.lean  the threshold certificate and the optimality theorem
CarbonSched/Bounds.lean      ratio bounds, proved savings, and the tightness witness
CarbonSched/Examples.lean    generated: three scenarios, checked by decide
CarbonSched/Audit.lean       axiom footprint gate
python/carbonsched/          scheduler that emits certificates, plus codegen
python/tests/                brute-force optimality checks and property tests
examples/scenarios.json      the scenarios
scripts/verify.sh            everything above, in one command
```

## Use

```bash
lake build                                                # proofs + audit
cd python && python3 -m carbonsched ../examples/scenarios.json
python3 -m carbonsched ../examples/scenarios.json --lean ../CarbonSched/Examples.lean
./scripts/verify.sh                                       # full gate
```

Add a scenario by putting its intensity profile, window and slot count in
`examples/scenarios.json`, regenerate, and build. An infeasible scenario exits
non-zero; a feasible one either produces a module that compiles or the
certificate was wrong, and there is no third outcome.

The Python tests do something the Lean proofs make unnecessary but that is worth
having anyway: on 300 random instances they enumerate **every** schedule of the
right length by brute force and confirm the certified one is minimal. If the two
models ever disagree, that test says so.

## The scenarios

Intensity profiles are shaped like a PJM summer weekday, in kg CO₂ per MWh:
coal on the margin overnight, solar pushing midday down, inefficient gas peakers
in the evening ramp. Illustrative, not measured.

**Industrial batch**, six hours anywhere in the day. Runs 09:00 to 15:00 for
1924, against 2989 running immediately: 35.6% saved, and no six-hour schedule
does better.

**Fleet charging**, four hours, plugged in at 18:00 and needed by midnight. Saves
4.5%. The window, not the algorithm, is what limits it: the day's cheapest hours
are simply not available, and the certificate proves nothing better exists inside
the window. This is the honest shape of most real deferral problems.

**Flat profile**, three hours on a day with no carbon signal. Saves 0.2%.
