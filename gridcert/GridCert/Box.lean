/-
# GridCert.Box

Bounds on a linear form over a box of injections.

This is the machinery behind "for every dispatch the operator could hand me,
does this line stay inside its rating". The dispatch is not a single vector; it
is a box, one interval per bus, covering unit commitment freedom, load forecast
error and a study generator's output range at once.

The three results are the same shape as the tolerance stack-up in Stage 1(A),
and for the same reason: a screening test is only worth running if it never
misses a violation (`sound`), never invents one (`complete`), and reports limits
that some real dispatch actually attains (`attained`).
-/

set_option autoImplicit false

namespace GridCert

/-- Per-bus injection range, in MW. -/
structure Range where
  lo : Int
  hi : Int
  deriving DecidableEq, Repr, Inhabited

/-- A box of dispatches: one range per bus. -/
abbrev Box := List Range

/-- A linear sensitivity row, one coefficient per bus. In practice a PTDF row,
scaled to integers. -/
abbrev Row := List Int

/-- A specific dispatch. -/
abbrev Dispatch := List Int

/-- No range is inverted. -/
def Box.Wf : Box → Bool
  | [] => true
  | r :: rs => decide (r.lo ≤ r.hi) && Box.Wf rs

/-- The dispatch lies inside the box. -/
def Mem : Dispatch → Box → Bool
  | [], [] => true
  | p :: ps, r :: rs => decide (r.lo ≤ p) && decide (p ≤ r.hi) && Mem ps rs
  | _, _ => false

/-- The linear form: sensitivity row against a dispatch. -/
def dot : Row → Dispatch → Int
  | [], _ => 0
  | _, [] => 0
  | a :: as, p :: ps => a * p + dot as ps

/-- Largest value the form can take over the box. -/
def upper : Row → Box → Int
  | [], _ => 0
  | _, [] => 0
  | a :: as, r :: rs => max (a * r.lo) (a * r.hi) + upper as rs

/-- Smallest value the form can take over the box. -/
def lower : Row → Box → Int
  | [], _ => 0
  | _, [] => 0
  | a :: as, r :: rs => min (a * r.lo) (a * r.hi) + lower as rs

/-- A dispatch attaining the upper bound: each bus goes to whichever end of its
range the sensitivity favours. -/
def argUpper : Row → Box → Dispatch
  | [], _ => []
  | _, [] => []
  | a :: as, r :: rs => (if a * r.lo ≥ a * r.hi then r.lo else r.hi) :: argUpper as rs

/-- A dispatch attaining the lower bound. -/
def argLower : Row → Box → Dispatch
  | [], _ => []
  | _, [] => []
  | a :: as, r :: rs => (if a * r.lo ≤ a * r.hi then r.lo else r.hi) :: argLower as rs

/-! ## Soundness -/

theorem dot_le_upper : ∀ (a : Row) (p : Dispatch) (b : Box),
    Mem p b = true → dot a p ≤ upper a b := by
  intro a
  induction a with
  | nil => intro p b _; cases p <;> cases b <;> simp [dot, upper]
  | cons x xs ih =>
      intro p b h
      cases p with
      | nil => cases b <;> simp_all [Mem, dot, upper]
      | cons y ys =>
        cases b with
        | nil => simp_all [Mem]
        | cons r rs =>
          simp only [Mem, Bool.and_eq_true, decide_eq_true_eq] at h
          have hrec := ih ys rs h.2
          have hstep : x * y ≤ max (x * r.lo) (x * r.hi) := by
            rcases Int.le_total 0 x with hx | hx
            · have := Int.mul_le_mul_of_nonneg_left h.1.2 hx
              exact Int.le_trans this (Int.le_max_right _ _)
            · have hnx : 0 ≤ -x := by omega
              have := Int.mul_le_mul_of_nonneg_left h.1.1 hnx
              have h2 : x * y ≤ x * r.lo := by
                simp only [Int.neg_mul] at this; omega
              exact Int.le_trans h2 (Int.le_max_left _ _)
          simp only [dot, upper]
          omega

theorem lower_le_dot : ∀ (a : Row) (p : Dispatch) (b : Box),
    Mem p b = true → lower a b ≤ dot a p := by
  intro a
  induction a with
  | nil => intro p b _; cases p <;> cases b <;> simp [dot, lower]
  | cons x xs ih =>
      intro p b h
      cases p with
      | nil => cases b <;> simp_all [Mem, dot, lower]
      | cons y ys =>
        cases b with
        | nil => simp_all [Mem]
        | cons r rs =>
          simp only [Mem, Bool.and_eq_true, decide_eq_true_eq] at h
          have hrec := ih ys rs h.2
          have hstep : min (x * r.lo) (x * r.hi) ≤ x * y := by
            rcases Int.le_total 0 x with hx | hx
            · have := Int.mul_le_mul_of_nonneg_left h.1.1 hx
              exact Int.le_trans (Int.min_le_left _ _) this
            · have hnx : 0 ≤ -x := by omega
              have := Int.mul_le_mul_of_nonneg_left h.1.2 hnx
              have h2 : x * r.hi ≤ x * y := by
                simp only [Int.neg_mul] at this; omega
              exact Int.le_trans (Int.min_le_right _ _) h2
          simp only [dot, lower]
          omega

/-! ## Tightness: the bounds are attained -/

theorem argUpper_mem : ∀ (a : Row) (b : Box),
    a.length = b.length → Box.Wf b = true → Mem (argUpper a b) b = true := by
  intro a
  induction a with
  | nil => intro b hlen _; cases b <;> simp_all [argUpper, Mem]
  | cons x xs ih =>
      intro b hlen hwf
      cases b with
      | nil => simp at hlen
      | cons r rs =>
        simp only [Box.Wf, Bool.and_eq_true, decide_eq_true_eq] at hwf
        simp only [List.length_cons, Nat.add_right_cancel_iff] at hlen
        simp only [argUpper, Mem, Bool.and_eq_true, decide_eq_true_eq]
        refine ⟨⟨?_, ?_⟩, ih rs hlen hwf.2⟩ <;> split <;> omega

theorem argLower_mem : ∀ (a : Row) (b : Box),
    a.length = b.length → Box.Wf b = true → Mem (argLower a b) b = true := by
  intro a
  induction a with
  | nil => intro b hlen _; cases b <;> simp_all [argLower, Mem]
  | cons x xs ih =>
      intro b hlen hwf
      cases b with
      | nil => simp at hlen
      | cons r rs =>
        simp only [Box.Wf, Bool.and_eq_true, decide_eq_true_eq] at hwf
        simp only [List.length_cons, Nat.add_right_cancel_iff] at hlen
        simp only [argLower, Mem, Bool.and_eq_true, decide_eq_true_eq]
        refine ⟨⟨?_, ?_⟩, ih rs hlen hwf.2⟩ <;> split <;> omega

theorem dot_argUpper : ∀ (a : Row) (b : Box),
    a.length = b.length → dot a (argUpper a b) = upper a b := by
  intro a
  induction a with
  | nil => intro b hlen; cases b <;> simp_all [argUpper, dot, upper]
  | cons x xs ih =>
      intro b hlen
      cases b with
      | nil => simp at hlen
      | cons r rs =>
        simp only [List.length_cons, Nat.add_right_cancel_iff] at hlen
        simp only [argUpper, dot, upper, ih rs hlen]
        split <;> rename_i hcase
        · rw [Int.max_eq_left hcase]
        · rw [Int.max_eq_right (by omega)]

theorem dot_argLower : ∀ (a : Row) (b : Box),
    a.length = b.length → dot a (argLower a b) = lower a b := by
  intro a
  induction a with
  | nil => intro b hlen; cases b <;> simp_all [argLower, dot, lower]
  | cons x xs ih =>
      intro b hlen
      cases b with
      | nil => simp at hlen
      | cons r rs =>
        simp only [List.length_cons, Nat.add_right_cancel_iff] at hlen
        simp only [argLower, dot, lower, ih rs hlen]
        split <;> rename_i hcase
        · rw [Int.min_eq_left hcase]
        · rw [Int.min_eq_right (by omega)]

end GridCert
