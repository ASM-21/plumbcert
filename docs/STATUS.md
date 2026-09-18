# Status

The honest paragraph, in one place, as of v0.1.0.

## What was extended in this pass

The repository arrived at this pass already building and already calling itself
done. Treating that as unproven turned up three things.

**A real defect.** Mutation testing, added in this pass, perturbs each constant
in a generated module and re-runs the full gate. It found a hand-written
`tolstack` theorem whose window constants could be changed to produce a
*different but still true* statement. That is the failure mode an axiom audit
cannot catch, and the repo's own method document had called it mechanically
undetectable. It is now pinned by `axialGap_interval_is_exact`. The first
version of the mutation operator was also wrong, perturbing in one direction
only, which cannot kill constants inside `= false` assertions; it now tries
several directions and reports a constant as free only if every wrong value
passes.

**A reduced claim.** A literature search was run after the results existed
rather than before. It cost the project its headline. The method is the
certifying algorithms paradigm and is decades old; two of the five tools
(`dimcert`, `lyapcert`) are re-instantiations of work that already exists,
including in Lean 4. Both READMEs now say so in their own words, and
[RELATED-WORK.md](RELATED-WORK.md) records what the search changed rather than
quietly fixing the framing.

**Publication hygiene.** Apache-2.0 with a NOTICE recording the provenance of
every bundled input, a complete citation file, an employer-independence
statement enforced by a build guard, and two renames forced by collision
evidence: `plumbline` is taken on PyPI, and `dimcheck` collided directly with an
existing physics dimension checker in the same domain.

## What is genuinely done

Five Lean developments, 262 theorems, no `sorry`, no axioms beyond the standard
three, no dependencies including mathlib. Every checker is proved sound and
constructively complete, so rejections return the counterexample. Every
generated certificate is regenerated and diffed by the gate. Every quoted figure
in the prose is recomputed from the tools. Three prose guards and the axiom gate
are each verified by injecting the failure they claim to catch.

The strongest result is `gridcert`: kernel-checked N-1 thermal screening over a
box of operating points rather than sampled points, with sensitivity rows
re-derived from the network equations rather than trusted.

## What remains blocked, and why

**Real data.** Three of five tools ship synthetic inputs. Marginal emissions data
is reachable but licensed such that bundling it is inappropriate, so it was
deliberately not used rather than quietly used. Utility network models are not
public, and the maintainer's employer access is precisely the access that must
not be used here. The unblock is the MATPOWER importer, which is the top open
issue; IEEE test cases are permissively licensed and reachable today.

**Scale.** Every check is `decide` on integer arithmetic and kernel reduction has
a performance cliff whose location is unknown. Five buses is comfortable, 118 is
untested.

**The `q^(2k)` step in `lyapcert`**, the one place a step is stated in a doc
comment rather than mechanized. Closing it needs rational arithmetic.

**AC power flow**, which is where the dependency-free approach genuinely stops
being right and mathlib becomes the correct tool.

Full detail in [LIMITATIONS.md](LIMITATIONS.md).

## How to check any of this yourself

```bash
git clone https://github.com/ASM-21/plumbcert && cd plumbcert
./scripts/verify-all.sh          # proofs, axiom audit, certificates, prose guards
python3 scripts/mutate.py --full # every certificate constant, both directions
./scripts/provenance.sh          # commit, environment, input digests
```

To run the headline tool on a network of your own, which is the most useful
thing anyone could do with this:

```bash
cd gridcert/python
python3 -m gridcert --template mine.json   # then fill in your buses and lines
python3 -m gridcert mine.json
```

Corrections, especially to [RELATED-WORK.md](RELATED-WORK.md), are welcome. The
claims most vulnerable to a citation I missed are named at the end of that file.
