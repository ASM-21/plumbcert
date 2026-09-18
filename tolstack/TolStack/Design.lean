/-
# TolStack.Design

The results a designer actually leans on when a print changes.

* `slack` — how much margin the chain has against the design window, and the
  fact that non-negative slack is *exactly* a passing check.
* `Refines` — tightening any tolerance in the chain can never turn a passing
  stack into a failing one, so it is always safe to hand a supplier a tighter
  print than the one that was verified.
* `fitsWithin_budget` — a passing chain's total band never exceeds the window
  width, which is the feasibility test to run before allocating tolerances.
* `nominal_mem_worstCase` — a chain of bilateral tolerances contains its own
  nominal, so the nominal gap is a legitimate design target.
-/
import TolStack.Basic
import TolStack.Analysis

namespace TolStack

namespace Term

/-- Containment of one term's reachable contribution inside another's, given the
same direction in the chain. -/
theorem refine_bounds {t u : Term} (hsign : t.sign = u.sign)
    (hlo : u.dim.lo ≤ t.dim.lo) (hhi : t.dim.hi ≤ u.dim.hi) :
    u.lo ≤ t.lo ∧ t.hi ≤ u.hi := by
  cases hs : t.sign <;> rw [hs] at hsign <;>
    simp only [Term.lo, Term.hi, hs, ← hsign] <;> omega

/-- A bilateral tolerance: the band brackets nominal on both sides. -/
def Centered (t : Term) : Prop := t.dim.lowDev ≤ 0 ∧ 0 ≤ t.dim.upDev

instance (t : Term) : Decidable t.Centered :=
  inferInstanceAs (Decidable (_ ∧ _))

theorem nominal_mem {t : Term} (h : t.Centered) :
    t.lo ≤ t.apply t.dim.nominal ∧ t.apply t.dim.nominal ≤ t.hi := by
  obtain ⟨h1, h2⟩ := h
  cases hs : t.sign <;>
    simp only [Term.lo, Term.hi, Term.apply, Dim.lo, Dim.hi, hs] <;> omega

end Term

namespace Stack

/-! ## Slack against the design window -/

/-- Margin on the low side of the design window. Negative means the chain can
undershoot the window. -/
def slackLo (s : Stack) (lo : Int) : Int := s.wcLo - lo

/-- Margin on the high side of the design window. Negative means the chain can
overshoot the window. -/
def slackHi (s : Stack) (hi : Int) : Int := hi - s.wcHi

/-- The checker is exactly a non-negativity test on both margins. -/
theorem fitsWithin_iff_slack_nonneg (s : Stack) (lo hi : Int) :
    s.fitsWithin lo hi = true ↔ (0 ≤ s.slackLo lo ∧ 0 ≤ s.slackHi hi) := by
  simp only [fitsWithin, Bool.and_eq_true, decide_eq_true_eq, slackLo, slackHi]
  omega

/-- Band still available to spend on component tolerances before the window is
violated. -/
def budgetRemaining (s : Stack) (lo hi : Int) : Int := (hi - lo) - s.wcWidth

/-- **Tolerance budget.** A chain can only pass if the sum of its component
bands fits inside the design window. Checking this first tells you whether an
allocation is feasible at all, independently of where the nominal sits. -/
theorem fitsWithin_budget {s : Stack} {lo hi : Int} (h : s.fitsWithin lo hi = true) :
    0 ≤ s.budgetRemaining lo hi := by
  simp only [fitsWithin, Bool.and_eq_true, decide_eq_true_eq] at h
  have hw := wcHi_sub_wcLo s
  simp only [budgetRemaining]
  omega

/-! ## Tightening tolerances is always safe -/

/-- `Refines s r`: chain `s` is chain `r` with every tolerance band tightened or
left alone. -/
inductive Refines : Stack → Stack → Prop
  | nil : Refines [] []
  | cons {t u : Term} {s r : Stack} :
      t.sign = u.sign → u.dim.lo ≤ t.dim.lo → t.dim.hi ≤ u.dim.hi →
      Refines s r → Refines (t :: s) (u :: r)

/-- A tightened chain reaches a subset of the values the loose chain reaches. -/
theorem refines_worstCase {s r : Stack} (h : Refines s r) :
    r.wcLo ≤ s.wcLo ∧ s.wcHi ≤ r.wcHi := by
  induction h with
  | nil => simp
  | cons hsign hlo hhi _ ih =>
      have hb := Term.refine_bounds hsign hlo hhi
      simp only [wcLo_cons, wcHi_cons]
      omega

/-- **Tightening never breaks a passing stack.** If the looser chain passes, so
does every refinement of it. -/
theorem refines_fitsWithin {s r : Stack} {lo hi : Int} (h : Refines s r)
    (hr : r.fitsWithin lo hi = true) : s.fitsWithin lo hi = true := by
  simp only [fitsWithin, Bool.and_eq_true, decide_eq_true_eq] at *
  have := refines_worstCase h
  omega

/-- Refinement is reflexive. -/
theorem refines_refl (s : Stack) : Refines s s := by
  induction s with
  | nil => exact .nil
  | cons t s ih => exact .cons rfl (Int.le_refl _) (Int.le_refl _) ih

/-! ## Nominal sits inside the worst-case band -/

/-- Every tolerance in the chain is bilateral. -/
def Centered (s : Stack) : Prop := ∀ t ∈ s, t.Centered

instance (s : Stack) : Decidable s.Centered :=
  inferInstanceAs (Decidable (∀ t ∈ s, t.Centered))

theorem centered_cons {t : Term} {s : Stack} (h : Centered (t :: s)) :
    t.Centered ∧ Centered s :=
  ⟨h t (List.mem_cons_self ..), fun u hu => h u (List.mem_cons_of_mem _ hu)⟩

/-- The all-nominal assembly is inside the worst-case interval. -/
theorem nominal_mem_worstCase {s : Stack} (h : s.Centered) :
    s.wcLo ≤ s.nominal ∧ s.nominal ≤ s.wcHi := by
  induction s with
  | nil => simp [Stack.nominal]
  | cons t s ih =>
      obtain ⟨ht, hs⟩ := centered_cons h
      have hterm := Term.nominal_mem ht
      have hrec := ih hs
      simp only [wcLo_cons, wcHi_cons, Stack.nominal]
      omega

end Stack

end TolStack
