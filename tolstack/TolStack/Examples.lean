/-
# TolStack.Examples

A worked axial stack: bearing and spacer retained by a snap ring inside a
counterbored housing. The closing dimension is the axial gap left for the
retaining ring.

    gap = bore depth − bearing width − spacer length − ring thickness

Every number below is in micrometres. All the claims about this assembly are
proved by kernel computation (`decide`), so the printed report and the theorems
cannot drift apart.
-/
import TolStack.Basic
import TolStack.Analysis

namespace TolStack
namespace Examples

open Stack

/-- Housing counterbore depth, 37.000 mm +0.050 / −0.000. -/
def bore : Dim :=
  { label := "housing counterbore depth", nominal := 37000, lowDev := 0, upDev := 50 }

/-- Bearing width, 15.000 mm ±0.030. -/
def bearing : Dim :=
  { label := "bearing width", nominal := 15000, lowDev := -30, upDev := 30 }

/-- Spacer length, 20.000 mm ±0.050. -/
def spacer : Dim :=
  { label := "spacer length", nominal := 20000, lowDev := -50, upDev := 50 }

/-- Retaining ring thickness, 1.600 mm +0.000 / −0.060. -/
def ring : Dim :=
  { label := "retaining ring thickness", nominal := 1600, lowDev := -60, upDev := 0 }

/-- The closing gap: bore depth less everything stacked inside it. -/
def axialGap : Stack :=
  [⟨.pos, bore⟩, ⟨.neg, bearing⟩, ⟨.neg, spacer⟩, ⟨.neg, ring⟩]

theorem axialGap_wf : axialGap.Wf := by decide

/-- Nominal gap is 0.400 mm. -/
theorem axialGap_nominal : axialGap.nominal = 400 := by decide

/-- The gap can range from 0.320 mm to 0.590 mm. -/
theorem axialGap_bounds : axialGap.wcLo = 320 ∧ axialGap.wcHi = 590 := by decide

/-- The parts never interfere: the gap is strictly positive in the worst case. -/
theorem axialGap_no_interference : axialGap.noInterference = true := by decide

/-- Design window 0.250 – 0.600 mm: accepted, and therefore guaranteed for every
assembly built from in-tolerance parts. -/
theorem axialGap_in_window {xs : List Int} (h : Realizes axialGap xs) :
    250 ≤ eval axialGap xs ∧ eval axialGap xs ≤ 600 :=
  fitsWithin_sound (by decide) h

/-- Tightening the window to 0.350 – 0.550 mm is not achievable with these part
tolerances, and the checker produces the offending build.

The two bounds are pinned by `axialGap_tight_window_is_tight` below. Without
that, mutating either constant would yield a different statement that happens to
remain true, which is the one failure mode an axiom audit cannot catch: a
theorem restated into something weaker. Mutation testing (`scripts/mutate.py`)
found exactly that here, and this pair is the fix. -/
theorem axialGap_tight_window_fails :
    ∃ xs, Realizes axialGap xs ∧ ¬ (350 ≤ eval axialGap xs ∧ eval axialGap xs ≤ 550) :=
  fitsWithin_complete axialGap_wf (by decide)

/-- **The tight window is exactly tight.** 350 and 550 are not arbitrary: the
stack's reachable interval is [320, 590], so 350 is the least lower bound that
excludes the worst build and 550 the greatest upper bound that excludes the best
one. Widening either by a single micrometre on the binding side makes the window
achievable again, which pins both constants. -/
theorem axialGap_tight_window_is_tight :
    axialGap.fitsWithin 350 550 = false
  ∧ axialGap.fitsWithin 320 550 = false
  ∧ axialGap.fitsWithin 320 590 = true := by
  refine ⟨by decide, by decide, by decide⟩

/-- **The reachable interval is exactly [320, 590].** Narrowing either side by a
single micrometre makes the stack fail, so neither endpoint is arbitrary. This
is what pins the two constants: without it, either could be moved outward to
give a different statement that happens to stay true. -/
theorem axialGap_interval_is_exact :
    axialGap.fitsWithin 320 590 = true
  ∧ axialGap.fitsWithin 321 590 = false
  ∧ axialGap.fitsWithin 320 589 = false := by
  refine ⟨by decide, by decide, by decide⟩

/-- The specific build that violates the tight window: bore at its low limit and
every internal part at its high limit, giving a 0.320 mm gap. -/
theorem axialGap_worst_build :
    axialGap.argLo = [37000, 15030, 20050, 1600] ∧ eval axialGap axialGap.argLo = 320 := by
  refine ⟨by decide, ?_⟩
  rw [eval_argLo]; decide

/-! ## Reporting -/

/-- Render micrometres as millimetres with three decimals. -/
def mm (x : Int) : String :=
  let neg := x < 0
  let n := x.natAbs
  let whole := n / 1000
  let frac := n % 1000
  let pad := if frac < 10 then "00" else if frac < 100 then "0" else ""
  (if neg then "-" else "") ++ toString whole ++ "." ++ pad ++ toString frac

def Term.report (t : Term) : String :=
  let dir := match t.sign with | .pos => "+" | .neg => "-"
  s!"  {dir} {t.dim.label}: {mm t.dim.nominal} [{mm t.dim.lo}, {mm t.dim.hi}]"

/-- A human-readable stack-up report. Every number here is produced by the same
functions the theorems are stated about. -/
def report (s : Stack) (lo hi : Int) : String :=
  let rows := String.intercalate "\n" (s.map Term.report)
  let verdict := if s.fitsWithin lo hi then "PASS" else "FAIL"
  let rssVerdict := if s.rssFitsWithin lo hi then "pass" else "fail"
  "Stack-up report (all values in mm)\n" ++
  rows ++ "\n" ++
  s!"  nominal        : {mm s.nominal}\n" ++
  s!"  worst-case     : [{mm s.wcLo}, {mm s.wcHi}]  (spread {mm s.wcWidth})\n" ++
  s!"  design window  : [{mm lo}, {mm hi}]\n" ++
  s!"  worst-case test: {verdict}\n" ++
  s!"  RSS test       : {rssVerdict}   (statistical estimate only, not a bound)"

end Examples
end TolStack
