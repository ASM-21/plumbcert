# plumbcert

**Machine-checked certificates for engineering studies.** An untrusted search
finds the answer; the Lean 4 kernel re-derives the engineering claim from a small
certificate. Five tools, no dependencies, not even mathlib.

```bash
git clone https://github.com/ASM-21/plumbcert && cd plumbcert && ./scripts/verify-all.sh
```

That command type-checks every theorem, confirms no proof depends on `sorry`,
confirms every generated certificate is current with the solver that produced it,
and confirms the prose in these files still matches what the tools compute.

> **Independence.** This is an independent personal project by Andrew Morrissey.
> It is **not affiliated with, endorsed by, or produced on behalf of** PPL
> Electric Utilities or any employer, and it uses only public and synthetic data.
> No non-public, internal, customer or client data appears anywhere in this
> repository or its history. The example network is a synthetic five-bus teaching
> case; see [NOTICE](NOTICE) for the provenance of every bundled input.

---

## The result worth leading with

An interconnection screening study claims that no dispatch the system could be in
overloads a given branch. In practice that rests on a sensitivity matrix from a
program nobody reads, applied to a handful of sampled dispatches.

`gridcert` replaces both halves. The dispatch becomes a **box** — one interval
per bus, covering load forecast error, commitment freedom and the study
generator's range together — and the proof quantifies over every dispatch inside
it. The sensitivity rows stop being trusted: each is re-derived from
zero-residual solutions of the network equations, so perturbing any single entry
by one unit fails the build.

```
ok    A-E base case:        [-227.8, 260.2] MW vs ±400, margin +139.8 MW
FAIL  A-D with A-B out:     [160.5, 558.0] MW vs ±400, margin -158.0 MW
        binding dispatch (MW): B=-330, C=-300, D=-400, E=+0
```

Two of five screens fail, and each failure ships with the specific dispatch that
causes it, proved admissible. Kernel-checked N-1 screening over a *box* of
operating points rather than sampled points appears to be the first of its kind;
see [docs/RELATED-WORK.md](docs/RELATED-WORK.md) for how that claim was checked.

## The five tools

| Tool | What it certifies | Status of the claim |
| --- | --- | --- |
| [**gridcert**](gridcert) | DC power flow N-1 thermal screening, sound and complete over a box of dispatches, PTDF rows re-derived rather than trusted | First formalization found |
| [**tolstack**](tolstack) | Worst-case 1D tolerance stack-up: sound and complete acceptance, exact limits, tightening is always safe, and a counterexample showing RSS is not a bound | First formalization found; the RSS fact is long known in the tolerance literature |
| [**carbonsched**](carbonsched) | Carbon-aware load scheduling: optimality against every alternative schedule, and the forecast-free competitive bound | First formalization found; the bound restates one-way-trading theory |
| [**lyapcert**](lyapcert) | Discrete-time stability: forward-invariant envelopes, geometric decay, certified settling, from a sum-of-squares certificate | Re-instantiation of standard SOS practice |
| [**dimcert**](dimcert) | Dimensional consistency: a formula's truth cannot depend on its units, and every dimensional error is exposed by a change of units | Re-instantiation; already done, including in Lean 4 |

## The method, and whose it is

The design is **certifying algorithms** (McConnell, Mehlhorn, Näher and
Schweitzer, *Computer Science Review*, 2011), in the lineage of program checking
(Blum and Kannan, *JACM*, 1995) and proof-carrying code (Necula, *POPL*, 1997).
Applying it inside a proof assistant to certificates produced by untrusted
numerical search is likewise established, notably in the sums-of-squares
community (Harrison 2007; Monniaux and Corbineau 2011; Roux, Voronin and
Sankaranarayanan 2016).

**This repository does not claim that method as new.** It is a measured
demonstration of a known technique across engineering domains that had not
previously received proof-assistant treatment. The full prior-art assessment,
including where the search cost this project its original framing, is in
[docs/RELATED-WORK.md](docs/RELATED-WORK.md).

What the demonstration shows in practice:

**Search is untrusted.** Finding a Lyapunov function, a tolerance allocation, a
schedule or a PTDF row needs floating point and heuristics. All of it happens in
Python, outside the trusted base. A solver bug costs a rejected certificate,
never a false theorem.

**Checking is a kernel computation.** What crosses the boundary is small: a
threshold, a sum of squares, an angle vector. Carrying physical quantities as
scaled integers keeps every check inside linear integer arithmetic, which is why
none of this needs mathlib.

**Positivity is arranged, not proved.** Asking whether a matrix is positive
semidefinite needs real analysis. Receiving it already written as a sum of
weighted squares makes non-negativity immediate from `0 ≤ z * z`. The same move
turns tolerance optimality into a threshold check and scheduling optimality into
a list induction.

**Claims are universally quantified.** `screen_sound` covers every dispatch in
the box; `optimal` covers every alternative schedule; `fitsWithin_sound` covers
every in-tolerance assembly. That is what testing cannot give you.

**Failures come with witnesses.** Every checker is complete as well as sound, so
a rejection returns the specific assembly, dispatch or schedule that breaks,
proved admissible. A tool that says "no" without saying "here" is not usable.

**Compilation is not verification**, a point already well made in the Lean
community. A passing build still accepts a proof containing `sorry` or resting on
an unintended axiom. Every project has an `Audit.lean` pinning each headline
result's exact axiom footprint with `#guard_msgs`.

## How this repo tries to stay honest

Three gates, each tested by injecting the failure it claims to catch, because a
guard that has never fired is an assumption:

- `scripts/verify-all.sh` — proofs, axiom audit, certificate freshness, tests.
- `scripts/mutate.py` — mutation testing. Perturbs each constant in a generated
  module and re-runs the gate. A survivor names a constant no theorem pins. This
  found a real defect: a hand-written `tolstack` theorem whose window constants
  could be changed to yield a different, still-true statement. That is the one
  failure mode an axiom audit cannot catch, and it is now pinned.
- `scripts/check-prose.py` — recomputes every quoted figure from the tools,
  fails if a required caveat is deleted, and fails on overclaiming phrases
  outside a scoped quotation.

## What this is not

Lean guarantees the theorems follow from the definitions. It does **not**
guarantee the definitions model your drawing, your plant, your network or your
day. A tolerance chain that omits a contributor is still provably correct about
the chain it was given. A DC screen is a screen, not an AC study, and nothing
here closes the gap to AC.

No regulator accepts machine-checked proofs for engineering studies, and nothing
here should be read as implying otherwise. The auditability argument is a
proposal. See [docs/LIMITATIONS.md](docs/LIMITATIONS.md), which states every
blocker in one place.

Two tools ship known blind spots deliberately:

- `dimcert` proves that `S = P + Q` passes every dimensional check and is still
  wrong physics. Watts, vars and volt-amperes share a dimension.
- `carbonsched` includes a flat-intensity day where optimal scheduling saves
  0.2%, because a tool reporting large savings on such a day has a bug.

## Layout

```
gridcert/  tolstack/  carbonsched/  lyapcert/  dimcert/
  <Namespace>/            Lean sources, including Audit.lean
  python/                 untrusted solver + codegen + tests
  examples/               JSON inputs
  scripts/verify.sh       that tool's full gate
scripts/verify-all.sh     every tool
scripts/mutate.py         mutation testing of certificate constants
scripts/check-prose.py    prose guards (--inject to self-test)
scripts/stats.sh          regenerate the counts in this README
scripts/rename.sh         rebrand the repo in one command
docs/CONCEPTS.md          the method, written to be lifted elsewhere
docs/RELATED-WORK.md      prior art, and what the literature search changed
docs/FINDINGS.md          the claims, numbered, each with what would falsify it
docs/LIMITATIONS.md       every blocker, stated once
docs/STATUS.md            what is done, what is blocked, how to check it
docs/ROADMAP.md           what to build next, graded by effort
docs/GOOD-FIRST-ISSUES.md ready-to-file issues
```

## Running it on your own network

The shipped study is a synthetic five-bus case, so the most useful thing anyone
can do with this repo is point it at a real network:

```bash
cd gridcert/python
python3 -m gridcert --template mine.json   # then fill in your buses and lines
python3 -m gridcert mine.json
```

Susceptances must be integers; the template explains how to scale if yours are
not. Automating that from MATPOWER case files is the top open issue.

## Requirements

Lean 4.22.0 via [elan](https://github.com/leanprover/elan), and Python 3.10+.
Nothing else, and no network access after the toolchain is installed.

## Citing

See [CITATION.cff](CITATION.cff). Author: Andrew Morrissey
([ORCID 0009-0004-8758-2687](https://orcid.org/0009-0004-8758-2687)).

## License

Apache-2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
