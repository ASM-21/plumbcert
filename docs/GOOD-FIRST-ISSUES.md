# Ready-to-file issues

Copy any of these into a GitHub issue as-is. Each states the change, why it
matters, where to start, and what "done" means, so nobody has to reverse-engineer
the intent from the code.

The label suggestions assume: `good-first-issue`, `help-wanted`, `lean`,
`python`, `research`.

---

### Read a MATPOWER case file into gridcert
`good-first-issue` `python` `gridcert`

**Why.** The study network is currently hand-written JSON, which means nobody can
point `gridcert` at their own system. Reading MATPOWER `.m` cases would open it
to IEEE 14, 30, 57 and 118-bus, plus anything a user already has.

**Where to start.** `gridcert/python/gridcert/network.py` defines `Network` and
`Line`. You need a function producing those from a MATPOWER `mpc` struct. The
existing JSON loader in `__main__.py` shows the shape.

**The one subtlety.** `Line.susc` must be an integer, because that is what keeps
the certificates exact and small. Real cases have arbitrary reactances, so you
will need to pick a rational scale per case and clear denominators, the way
`certify_row` already does for angles. Document the scale you chose and how much
it perturbs the case.

**Done when.** `python -m gridcert case14.m` runs a screen, the generated Lean
module builds, and a test compares your PTDF rows against MATPOWER's own
`makePTDF` output on at least two cases.

---

### Find where `decide` falls over
`help-wanted` `lean` `research`

**Why.** Every concrete check in this repo is `decide` on integer arithmetic,
and kernel reduction has a cliff. It is somewhere above a five-bus network and
below something. Nobody knows where, and that number determines whether this
approach scales to a real system.

**Where to start.** Generate synthetic `gridcert` cases of increasing size and
time `lake build` on the generated module. `tolstack` with a long chain is a
cheaper second axis.

**Done when.** `docs/SCALING.md` reports build time against problem size for at
least two of the tools, names the first size that becomes impractical, and says
which part blows up (row width, coefficient magnitude, or number of screens).

**If it turns out badly.** The fallback is `native_decide`, which trades kernel
reduction for compiled evaluation and moves the compiler into the trusted base.
That is a real trust-tier decision. If you get there, propose it as an opt-in
flag with the tradeoff documented, not as a silent default.

---

### Wire real carbon intensity data into carbonsched
`good-first-issue` `python` `carbonsched`

**Why.** The intensity profiles are illustrative and the README says so, which
means the savings numbers currently demonstrate the machinery rather than
measuring anything. Real marginal emissions data would make them mean something.

**Where to start.** `carbonsched/examples/scenarios.json` is the input format.
Candidate sources: WattTime, Electricity Maps, or a grid operator's own
published marginal emissions. A small fetcher that caches a few real days into
that format is enough; do not add a runtime API dependency.

**Keep.** The `flat profile` scenario. It is there to catch a tool that reports
large savings on a day with no carbon signal, and that check gets more valuable
with real data, not less.

**Done when.** At least three real days from a named source are committed as
JSON, with provenance and date recorded, and the README savings figures are
regenerated from them.

---

### A worked tutorial from a textbook problem
`good-first-issue` `docs`

**Why.** Both entry points into this repo currently open with theory. Someone
evaluating whether this is worth their time needs to see the hand method and the
certified method side by side on a problem they recognize.

**Where to start.** Pick one tolerance stack-up and one dimensional check at
FE-exam difficulty. Show the hand calculation, then the JSON, then the generated
theorem, then what the theorem rules out that the hand calculation does not.

**Done when.** `docs/TUTORIAL.md` exists, a reader who has never used Lean can
follow it end to end, and every command in it is copy-pasteable.

---

### Generalize the quadratic certificate past two states
`help-wanted` `lean` `lyapcert`

**Why.** `Quad` and `Sq` are hardcoded to two states, which limits `lyapcert` to
toy plants. The envelope theorems in `Envelope.lean` are already dimension-free
and quantify over an arbitrary state type, so this does not touch the Lyapunov
argument at all.

**Where to start.** `lyapcert/LyapCert/Quadratic.lean`. Generalize `Quad` from
three coefficients to a coefficient list and `Sq` from `(coeff, a, b)` to
`(coeff, List Int)`. Three algebraic lemmas need redoing: `eval_compose`,
`eval_eq_quad`, and `eval_nonneg`.

**Done when.** A three-state or four-state system certifies end to end, the
axiom audit still passes, and the two-state examples still build unchanged.

---

### Close the `q^(2k)` gap in lyapcert
`help-wanted` `lean` `lyapcert`

**Why.** This is the one place in the repo where a step is stated in a doc
comment rather than mechanized, and it should not stay that way. A matrix with
all eigenvalues inside the unit circle cannot have integer entries, so systems
are certified through the scaled form `B = qA`, and reading the result back to
`A` divides by `q^(2k)`.

**Where to start.** Degree-two homogeneity is already proved
(`Quad.eval_scaleVec`), which is the ingredient the argument needs. What is
missing is stating the envelope over rationals so the division is expressible.
Core Lean's `Rat` may be enough; mathlib's `ℚ` certainly is.

**Done when.** The envelope theorem is stated for the unscaled system `A` and
proved, and the doc-comment caveat is deleted from `lyapcert/README.md` and this
roadmap.

---

### Multi-load scheduling with per-slot capacity
`research` `lean` `carbonsched`

**Why.** `carbonsched` handles one deferrable load. Several loads competing for
per-slot capacity is what a real demand-response program actually is, and a
threshold certificate no longer suffices for it.

**What it needs.** The problem becomes min-cost bipartite matching. The
certificate is an LP dual, and weak duality needs a sum-over-injection lemma
(`Σ_j v_{σ(j)} ≤ Σ_t v_t` for injective `σ`), which core Lean does not give you.
This is the first place in the repo where a `Finset` would genuinely earn its
keep, so it is also a good test of whether the no-dependency stance should hold.

**Done when.** A two-load instance certifies optimal against a brute-force
enumeration, and `docs/CONCEPTS.md` gains a paragraph on when a threshold stops
being a sufficient certificate.

**Before starting.** Read `carbonsched/CarbonSched/Optimality.lean` and be sure
you understand why `cost_diff_le` works, because the whole question is what
replaces it.
