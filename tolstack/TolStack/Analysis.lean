/-
# TolStack.Analysis

Worst-case vs. RSS (root-sum-square) stacks.

RSS involves a square root, which would drag in irrational arithmetic. It is
avoided entirely here by comparing *squares*: a chain passes an RSS check against
a window of width `W` iff `rssSq ≤ W * W`. That is exactly equivalent to
`sqrt (Σ wᵢ²) ≤ W` for non-negative `W`, and it stays in `Int`.

Two results:

* `rssSq_le_wcWidth_sq` — RSS is never more conservative than worst-case, which
  is the whole reason designers use it.
* `rss_check_unsound` — a concrete, kernel-checked counterexample showing RSS is
  *not* a guarantee. There is an assembly that passes the RSS check and still has
  a manufacturable configuration outside the window. This is the standard
  engineering caveat, here as a theorem rather than a footnote.
-/
import TolStack.Basic

namespace TolStack
namespace Stack

/-- Sum of the tolerance band widths: the worst-case spread of the chain. -/
def wcWidth : Stack → Int
  | []     => 0
  | t :: s => t.dim.width + wcWidth s

/-- Sum of squared band widths. The RSS spread is its square root; keeping the
square avoids irrational arithmetic. -/
def rssSq : Stack → Int
  | []     => 0
  | t :: s => t.dim.width * t.dim.width + rssSq s

@[simp] theorem wcWidth_nil : wcWidth [] = 0 := rfl

@[simp] theorem wcWidth_cons (t : Term) (s : Stack) :
    wcWidth (t :: s) = t.dim.width + wcWidth s := rfl

@[simp] theorem rssSq_nil : rssSq [] = 0 := rfl

@[simp] theorem rssSq_cons (t : Term) (s : Stack) :
    rssSq (t :: s) = t.dim.width * t.dim.width + rssSq s := rfl

/-- The worst-case interval has exactly the summed band width, for any mix of
signs. -/
theorem wcHi_sub_wcLo (s : Stack) : s.wcHi - s.wcLo = s.wcWidth := by
  induction s with
  | nil => simp
  | cons t s ih =>
      have hterm : t.hi - t.lo = t.dim.width := by
        cases hs : t.sign <;>
          simp only [Term.lo, Term.hi, Dim.lo, Dim.hi, Dim.width, hs] <;> omega
      simp only [wcHi_cons, wcLo_cons, wcWidth_cons]
      omega

theorem wcWidth_nonneg {s : Stack} (h : s.Wf) : 0 ≤ s.wcWidth := by
  induction s with
  | nil => simp
  | cons t s ih =>
      obtain ⟨ht, hs⟩ := wf_cons h
      have h1 := Dim.width_nonneg ht
      have h2 := ih hs
      simp only [wcWidth_cons]
      omega

theorem rssSq_nonneg {s : Stack} (h : s.Wf) : 0 ≤ s.rssSq := by
  induction s with
  | nil => simp
  | cons t s ih =>
      obtain ⟨ht, hs⟩ := wf_cons h
      have h1 := Int.mul_nonneg (Dim.width_nonneg ht) (Dim.width_nonneg ht)
      have h2 := ih hs
      simp only [rssSq_cons]
      omega

/-- **RSS is never more conservative than worst-case.**

`Σ wᵢ² ≤ (Σ wᵢ)²` for non-negative widths, i.e. the RSS spread never exceeds the
worst-case spread. -/
theorem rssSq_le_wcWidth_sq {s : Stack} (h : s.Wf) :
    s.rssSq ≤ s.wcWidth * s.wcWidth := by
  induction s with
  | nil => simp
  | cons t s ih =>
      obtain ⟨ht, hs⟩ := wf_cons h
      have hw : 0 ≤ t.dim.width := Dim.width_nonneg ht
      have hW : 0 ≤ wcWidth s := wcWidth_nonneg hs
      have ihs := ih hs
      have hc1 : 0 ≤ t.dim.width * wcWidth s := Int.mul_nonneg hw hW
      have hc2 : 0 ≤ wcWidth s * t.dim.width := Int.mul_nonneg hW hw
      have hexp : (t.dim.width + wcWidth s) * (t.dim.width + wcWidth s)
          = t.dim.width * t.dim.width + t.dim.width * wcWidth s
            + (wcWidth s * t.dim.width + wcWidth s * wcWidth s) := by
        rw [Int.add_mul, Int.mul_add, Int.mul_add]
      simp only [rssSq_cons, wcWidth_cons]
      omega

/-- The RSS acceptance test against a design window `[lo, hi]`.

Passes iff the RSS spread fits the window. Squared to stay in `Int`. -/
def rssFitsWithin (s : Stack) (lo hi : Int) : Bool :=
  decide (s.rssSq ≤ (hi - lo) * (hi - lo))

/-- Passing the worst-case check implies passing the RSS check: worst-case is
the strictly stronger criterion. -/
theorem fitsWithin_imp_rssFitsWithin {s : Stack} {lo hi : Int} (hwf : s.Wf)
    (h : s.fitsWithin lo hi = true) : s.rssFitsWithin lo hi = true := by
  simp only [fitsWithin, Bool.and_eq_true, decide_eq_true_eq] at h
  simp only [rssFitsWithin, decide_eq_true_eq]
  have hrss := rssSq_le_wcWidth_sq hwf
  have hwidth := wcHi_sub_wcLo s
  have hWnn := wcWidth_nonneg hwf
  have hle : s.wcWidth ≤ hi - lo := by omega
  have hmono : s.wcWidth * s.wcWidth ≤ (hi - lo) * (hi - lo) :=
    Int.mul_le_mul hle hle hWnn (by omega)
  omega

/-! ## RSS is not a guarantee

A four-part chain, each feature 1.000 mm ±0.100 mm, against a ±0.200 mm window
on a 4.000 mm nominal. The RSS spread is exactly 0.400 mm so the RSS check
passes, but all four parts can legitimately come in at their upper limit, putting
the assembly at 4.400 mm. -/

/-- 1.000 mm ±0.100 mm, in micrometres. -/
def part : Dim := { label := "part", nominal := 1000, lowDev := -100, upDev := 100 }

/-- Four such parts stacked in the same direction. -/
def fourParts : Stack :=
  [⟨.pos, part⟩, ⟨.pos, part⟩, ⟨.pos, part⟩, ⟨.pos, part⟩]

/-- **RSS acceptance does not imply the assembly is in spec.**

The chain passes `rssFitsWithin 3800 4200`, yet an assembly built entirely from
in-tolerance parts reaches 4400. -/
theorem rss_check_unsound :
    fourParts.Wf
    ∧ fourParts.rssFitsWithin 3800 4200 = true
    ∧ fourParts.fitsWithin 3800 4200 = false
    ∧ ∃ xs, Realizes fourParts xs ∧ ¬ (3800 ≤ eval fourParts xs ∧ eval fourParts xs ≤ 4200) := by
  refine ⟨by decide, by decide, by decide, fourParts.argHi, argHi_realizes (by decide), ?_⟩
  rw [eval_argHi]
  decide

end Stack
end TolStack
