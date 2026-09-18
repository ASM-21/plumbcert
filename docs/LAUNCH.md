# Launch checklist

Ordered so that the cheap, reversible things happen before the ones that spend
credibility. Nothing here should take more than an evening except items 8 and 9.

## Before pushing

- [ ] Replace `Andrew` in `LICENSE` and `CITATION.cff` with the name you want on
      it, and add your ORCID to the citation file if you have one.
- [x] Licence: **Apache-2.0**, chosen: it is the Lean
      ecosystem norm (Lean core and mathlib both use it) and its explicit patent
      grant matters more than usual for tooling that touches ASME and IEEE
      standards work. Swap `LICENSE`, the `license:` line in `CITATION.cff`, and
      the closing line of the README.
- [ ] Run `./scripts/verify-all.sh` one more time on a clean clone. The five
      `verify.sh` scripts regenerate certificates in place, so confirm
      `git status` is clean afterward.
- [ ] Skim each project README's "what is not proved" section. Those are the
      sections that will be quoted at you; make sure you still believe them.

## Repo setup

- [ ] **Name**: `plumbcert`. Checked against PyPI and GitHub before committing
      to it. Two earlier names were rejected on collision: `lean-engineering`
      collided with **Lean manufacturing**, which would have buried the repo in
      Toyota Production System results in exactly the audience most wanted, and
      `plumbline` is taken on PyPI by an existing EPT/DEM tool. The subproject
      `dimcheck` was renamed to `dimcert` because PyPI already has a sympy-based
      physics dimension checker under that name, a direct same-domain collision.
      `./scripts/rename.sh newname` rebrands everything in one command.
- [ ] **Do not claim "proof-carrying engineering" as a coinage.** The literature
      search found a 2026 Lean 4 paper (arXiv:2606.09600) already using
      "proof-carrying certificates ... in Lean 4", and the underlying method is
      the long-established certifying-algorithms paradigm. Use the phrase, if at
      all, as plain description, and cite Necula 1997 / McConnell et al. 2011 /
      Blum and Kannan 1995 wherever the method is described. See
      docs/RELATED-WORK.md.
- [ ] **Description** (the one-liner GitHub shows in search results, and the
      single highest-leverage string in this document):
      *Kernel-checked N-1 screening over a box of dispatches, plus tolerance,
      dimensional, stability and scheduling certificates. Lean 4, no mathlib.*
      (152 characters, so GitHub and Google will not truncate it.)
- [ ] **Topics**: `lean4`, `formal-verification`, `theorem-proving`,
      `mechanical-engineering`, `power-systems`, `tolerance-analysis`,
      `dimensional-analysis`, `control-theory`, `lyapunov`,
      `carbon-aware-computing`, `interconnection`, `smart-grid`.
      `lean4` matters most: it is how the Lean community finds anything.
- [ ] Enable Issues and Discussions. Discussions is where "can this do X"
      arrives, and those questions are your roadmap.
- [ ] Add the CI badge to the top of the README once the first run is green.
- [ ] Tag `v0.1.0` and cut a GitHub Release. A release with notes is what makes
      the work look finished rather than in progress.

## Findability, in order of value per hour

1. **Lean Zulip.** `#announce` for the release, `#lean4` or `#general` for the
   discussion. This is where the people who will actually read the proofs are,
   and the reception there is worth more than any amount of general traffic.
   Draft below.
2. **Reservoir**, the Lean package index. It indexes GitHub repos with a
   lakefile at the root, which a monorepo does not have. If you want listings,
   the fix is to split one project into its own repo, or add a thin top-level
   lakefile. Worth checking Reservoir's current indexing rules before deciding;
   they have changed before.
3. **arXiv preprint**, cs.LO cross-listed to eess.SY. Title the category, not
   the repo: something like *Proof-carrying engineering: certificate checking
   for physical-systems verification without a real-analysis library*.
   [docs/CONCEPTS.md](CONCEPTS.md) is already most of the introduction. This is the item with the
   longest tail: it makes the work citable, which is what turns a repo into
   something that gets built on. See roadmap item 13.
4. **LinkedIn**, once, aimed at the power-systems audience rather than the
   formal-methods one. Lead with the gridcert result, not the proof count.
5. **Email the LeanDynamicalSystems authors** (Doll and Shames, Melbourne). You
   have a concrete thing to say: their `IsLyapunov` hypotheses are exactly what
   lyapcert discharges by computation. That is a collaboration opening, not a
   cold email.

## Not recommended

- **Hacker News.** The audience overlap is poor and the failure mode is a thread
  arguing about whether formal methods are worth it, which teaches you nothing
  and costs a first impression you only get once.
- **Leading with the theorem count anywhere.** 259 theorems is a number that
  impresses nobody who knows what a theorem is. Lead with a result.

---

## Draft: Lean Zulip announcement

This audience will recognise the method immediately, so lead by conceding it.

> **plumbcert: certificate-checked engineering studies in Lean 4**
>
> I've put up five small Lean 4 developments aimed at engineering practice
> rather than mathematics: worst-case tolerance stack-up, dimensional
> consistency, discrete-time Lyapunov certificates, carbon-aware load
> scheduling, and N-1 thermal screening for power system interconnection
> studies.
>
> The method is not new and I'm not claiming it: search runs untrusted in
> Python, a small certificate crosses into Lean, and the kernel re-derives the
> claim by `decide`. That's certifying algorithms (McConnell et al. 2011,
> after Blum and Kannan, and Necula's proof-carrying code), and inside a prover
> it's what the SOS community has done since Harrison 2007 and
> Monniaux–Corbineau 2011. What I think is worth showing is that it transfers
> cleanly to engineering-study artifacts, and that carrying quantities as scaled
> integers keeps every check in linear integer arithmetic, so none of the five
> depends on mathlib.
>
> Two of the five are frankly re-instantiations. Dimensional analysis is
> Kennedy 1997 and is already formalized in Lean 4 (Bobbin et al. 2025; Allen
> 2025); the SOS/Lyapunov one overlaps heavily with existing work and with
> Doll and Shames' Lean control-theory library. I've said so in each README.
> The one I'd defend as new is N-1 screening proved over a *box* of operating
> points rather than sampled ones.
>
> Two things I'd welcome comment on. First, whether `decide` holds up at
> realistic problem sizes; I know there's a kernel-reduction cliff and I don't
> know where it is, which is an open issue in the repo. Second, whether the
> mathlib avoidance is principled or just stubborn. It visibly costs me once:
> `lyapcert` certifies a scaled integer matrix and the read-back to the real
> system divides by `q^(2k)`, which is in a doc comment rather than mechanized.
>
> One thing that might be reusable independently: alongside the usual
> `#print axioms` gate, there's a mutation tester that perturbs each constant in
> a generated module and re-runs the build. It found a theorem of mine whose
> constants could be changed to give a different statement that stayed true,
> which the axiom gate cannot catch.
>
> Repo: <link>

## Draft: LinkedIn post

Aimed at the power-systems audience. Leads with the problem, not the proofs.

> An interconnection screening study makes a claim: no dispatch the system could
> be in overloads this branch. In practice that rests on a sensitivity matrix
> from a program nobody reads, applied to a handful of sampled dispatches.
>
> I spent some time asking what it would take to actually prove it, using the
> Lean theorem prover.
>
> Two things changed. The dispatch became a box rather than a snapshot, one
> interval per bus covering load forecast error, commitment freedom and the
> study generator's range together, with the proof quantifying over every
> dispatch inside it. And the sensitivity rows stopped being trusted: each is
> re-derived from zero-residual solutions of the network equations, so
> perturbing any single entry by one unit fails the build.
>
> On a synthetic five-bus study system with a 300 MW request, two of five
> screens fail, and each failure comes with the specific dispatch that causes
> it, proved admissible.
>
> The honest caveats matter more than the result. This is the DC model, so a
> certified DC screen is a screen and not a study. The network is synthetic and
> the data is public or invented. And no regulator accepts machine-checked
> proofs for engineering studies today; this is a proposal about auditability,
> not a compliance claim.
>
> It's an independent personal project, open source, with four other tools in
> the same repo covering tolerance stack-up, dimensional analysis, stability
> certificates and carbon-aware scheduling. If you have a network you can share,
> `python3 -m gridcert --template mine.json` gets you started in one command.

## Draft: email to the LeanDynamicalSystems authors

Moritz Doll and Iman Shames, University of Melbourne (arXiv:2607.19727). This is
the one genuine collaboration opening the literature search turned up, and it is
specific rather than a cold introduction.

> Subject: IsLyapunov hypotheses discharged by computation, from a
> dependency-free Lean 4 development
>
> I read your Foundations of Machine-Checked Control Theory in Lean paper while
> doing a prior-art check on a small Lean 4 project of my own, and wanted to
> flag a fit rather than an overlap.
>
> Your `IsLyapunov V Φ` asks for non-negativity and non-increase along the flow.
> I have a development that discharges exactly those two by kernel computation
> for the quadratic case: a Lyapunov function arrives as a sum of weighted
> squares, so non-negativity is syntactic, and the decay condition arrives with
> a second sum of squares certifying an identity between quadratic forms, which
> is an equality of integers and so falls to `decide`. It is over `Int` rather
> than `ℝ` and has no dependencies, which is why it cannot talk to your library
> as it stands.
>
> Porting looks small: replace the scalar type, keep the proofs, and hand the
> results to `IsLyapunov.isStableOn_nhdsSet`. Before I attempt that I would
> rather ask whether you have already covered SOS-certificate checking, since if
> so my development is redundant and I would say so in my README rather than
> publish it as a contribution.
>
> Repo and the relevant module: <link>
