/-
# TolStack.Basic

A machine-checked 1D worst-case tolerance stack-up verifier.

All lengths are `Int` in micrometres (µm). Working in exact integers rather than
floats means every theorem below is about the arithmetic actually performed by
the checker, and `omega` discharges the linear goals without any mathlib
dependency.

The two results that matter are `fitsWithin_sound` (the checker never passes an
assembly that can interfere) and `fitsWithin_complete` (it never rejects one that
cannot). Together they say the computed interval is exactly the reachable set of
gaps, not a conservative superset.
-/

namespace TolStack

/-- Direction in which a dimension contributes to the stack axis. -/
inductive Sign where
  | pos
  | neg
  deriving Repr, DecidableEq, Inhabited

/-- A toleranced linear dimension: nominal size with a lower and upper deviation.

`lowDev` is normally negative and `upDev` positive, but neither is required; only
`Wf` (band not inverted) is assumed where it is needed. -/
structure Dim where
  label   : String := ""
  nominal : Int
  lowDev  : Int
  upDev   : Int
  deriving Repr, DecidableEq, Inhabited

namespace Dim

/-- Least value the manufactured feature may take. -/
def lo (d : Dim) : Int := d.nominal + d.lowDev

/-- Greatest value the manufactured feature may take. -/
def hi (d : Dim) : Int := d.nominal + d.upDev

/-- Total width of the tolerance band. -/
def width (d : Dim) : Int := d.upDev - d.lowDev

/-- Well-formedness: the tolerance band is not inverted. -/
def Wf (d : Dim) : Prop := d.lowDev ≤ d.upDev

instance (d : Dim) : Decidable d.Wf :=
  inferInstanceAs (Decidable (d.lowDev ≤ d.upDev))

/-- `x` is a value this feature is permitted to take after manufacture. -/
def Realizes (d : Dim) (x : Int) : Prop := d.lo ≤ x ∧ x ≤ d.hi

theorem lo_le_hi {d : Dim} (h : d.Wf) : d.lo ≤ d.hi := by
  unfold lo hi; unfold Wf at h; omega

theorem width_nonneg {d : Dim} (h : d.Wf) : 0 ≤ d.width := by
  unfold width; unfold Wf at h; omega

theorem realizes_lo {d : Dim} (h : d.Wf) : d.Realizes d.lo :=
  ⟨Int.le_refl _, lo_le_hi h⟩

theorem realizes_hi {d : Dim} (h : d.Wf) : d.Realizes d.hi :=
  ⟨lo_le_hi h, Int.le_refl _⟩

end Dim

/-- One signed entry in a stack chain. -/
structure Term where
  sign : Sign
  dim  : Dim
  deriving Repr, Inhabited

/-- A 1D stack-up: a chain of signed toleranced dimensions. -/
abbrev Stack := List Term

namespace Term

/-- The signed contribution of a realized value `x`. -/
def apply (t : Term) (x : Int) : Int :=
  match t.sign with
  | .pos => x
  | .neg => -x

/-- Least possible signed contribution of this term. -/
def lo (t : Term) : Int :=
  match t.sign with
  | .pos => t.dim.lo
  | .neg => -t.dim.hi

/-- Greatest possible signed contribution of this term. -/
def hi (t : Term) : Int :=
  match t.sign with
  | .pos => t.dim.hi
  | .neg => -t.dim.lo

/-- A realized value attaining this term's least contribution. -/
def argLo (t : Term) : Int :=
  match t.sign with
  | .pos => t.dim.lo
  | .neg => t.dim.hi

/-- A realized value attaining this term's greatest contribution. -/
def argHi (t : Term) : Int :=
  match t.sign with
  | .pos => t.dim.hi
  | .neg => t.dim.lo

theorem apply_mem {t : Term} {x : Int} (h : t.dim.Realizes x) :
    t.lo ≤ t.apply x ∧ t.apply x ≤ t.hi := by
  obtain ⟨h1, h2⟩ := h
  cases hs : t.sign <;> simp only [lo, hi, apply, hs] <;> omega

theorem argLo_realizes {t : Term} (h : t.dim.Wf) : t.dim.Realizes t.argLo := by
  cases hs : t.sign <;> simp only [argLo, hs]
  · exact Dim.realizes_lo h
  · exact Dim.realizes_hi h

theorem argHi_realizes {t : Term} (h : t.dim.Wf) : t.dim.Realizes t.argHi := by
  cases hs : t.sign <;> simp only [argHi, hs]
  · exact Dim.realizes_hi h
  · exact Dim.realizes_lo h

theorem apply_argLo (t : Term) : t.apply t.argLo = t.lo := by
  cases hs : t.sign <;> simp only [apply, argLo, lo, hs]

theorem apply_argHi (t : Term) : t.apply t.argHi = t.hi := by
  cases hs : t.sign <;> simp only [apply, argHi, hi, hs]

theorem lo_le_hi {t : Term} (h : t.dim.Wf) : t.lo ≤ t.hi := by
  have := Dim.lo_le_hi h
  cases hs : t.sign <;> simp only [lo, hi, hs] <;> omega

end Term

namespace Stack

/-- Least attainable value of the stack chain (worst-case low limit). -/
def wcLo : Stack → Int
  | []     => 0
  | t :: s => t.lo + wcLo s

/-- Greatest attainable value of the stack chain (worst-case high limit). -/
def wcHi : Stack → Int
  | []     => 0
  | t :: s => t.hi + wcHi s

/-- Value of the chain when every feature is exactly at nominal. -/
def nominal : Stack → Int
  | []     => 0
  | t :: s => t.apply t.dim.nominal + nominal s

/-- Every dimension in the chain has a non-inverted tolerance band. -/
def Wf (s : Stack) : Prop := ∀ t ∈ s, t.dim.Wf

instance (s : Stack) : Decidable s.Wf :=
  inferInstanceAs (Decidable (∀ t ∈ s, t.dim.Wf))

/-- `xs` is a list of realized feature values, one per term, each within its
tolerance band. -/
inductive Realizes : Stack → List Int → Prop
  | nil : Realizes [] []
  | cons {t : Term} {s : Stack} {x : Int} {xs : List Int} :
      t.dim.Realizes x → Realizes s xs → Realizes (t :: s) (x :: xs)

/-- The realized value of the chain for a given set of manufactured parts. -/
def eval : Stack → List Int → Int
  | t :: s, x :: xs => t.apply x + eval s xs
  | _,      _       => 0

@[simp] theorem eval_nil : eval [] [] = 0 := rfl

@[simp] theorem eval_cons (t : Term) (s : Stack) (x : Int) (xs : List Int) :
    eval (t :: s) (x :: xs) = t.apply x + eval s xs := rfl

@[simp] theorem wcLo_nil : wcLo [] = 0 := rfl

@[simp] theorem wcLo_cons (t : Term) (s : Stack) : wcLo (t :: s) = t.lo + wcLo s := rfl

@[simp] theorem wcHi_nil : wcHi [] = 0 := rfl

@[simp] theorem wcHi_cons (t : Term) (s : Stack) : wcHi (t :: s) = t.hi + wcHi s := rfl

theorem wf_cons {t : Term} {s : Stack} (h : Wf (t :: s)) : t.dim.Wf ∧ Wf s :=
  ⟨h t (List.mem_cons_self ..), fun u hu => h u (List.mem_cons_of_mem _ hu)⟩

/-! ## Soundness: every realizable assembly lands inside the computed interval -/

theorem eval_mem_worstCase {s : Stack} {xs : List Int} (h : Realizes s xs) :
    s.wcLo ≤ eval s xs ∧ eval s xs ≤ s.wcHi := by
  induction h with
  | nil => simp
  | cons hx _ ih =>
      have hb := Term.apply_mem hx
      simp only [eval_cons, wcLo_cons, wcHi_cons]
      omega

/-! ## Completeness: both endpoints are actually attained -/

/-- The parts list realizing the worst-case low limit. -/
def argLo : Stack → List Int
  | []     => []
  | t :: s => t.argLo :: argLo s

/-- The parts list realizing the worst-case high limit. -/
def argHi : Stack → List Int
  | []     => []
  | t :: s => t.argHi :: argHi s

theorem argLo_realizes {s : Stack} (h : s.Wf) : Realizes s s.argLo := by
  induction s with
  | nil => exact .nil
  | cons t s ih =>
      obtain ⟨ht, hs⟩ := wf_cons h
      exact .cons (Term.argLo_realizes ht) (ih hs)

theorem argHi_realizes {s : Stack} (h : s.Wf) : Realizes s s.argHi := by
  induction s with
  | nil => exact .nil
  | cons t s ih =>
      obtain ⟨ht, hs⟩ := wf_cons h
      exact .cons (Term.argHi_realizes ht) (ih hs)

theorem eval_argLo (s : Stack) : eval s s.argLo = s.wcLo := by
  induction s with
  | nil => rfl
  | cons t s ih =>
      show t.apply t.argLo + eval s (argLo s) = t.lo + wcLo s
      rw [Term.apply_argLo, ih]

theorem eval_argHi (s : Stack) : eval s s.argHi = s.wcHi := by
  induction s with
  | nil => rfl
  | cons t s ih =>
      show t.apply t.argHi + eval s (argHi s) = t.hi + wcHi s
      rw [Term.apply_argHi, ih]

theorem wcLo_attained {s : Stack} (h : s.Wf) :
    ∃ xs, Realizes s xs ∧ eval s xs = s.wcLo :=
  ⟨s.argLo, argLo_realizes h, eval_argLo s⟩

theorem wcHi_attained {s : Stack} (h : s.Wf) :
    ∃ xs, Realizes s xs ∧ eval s xs = s.wcHi :=
  ⟨s.argHi, argHi_realizes h, eval_argHi s⟩

theorem wcLo_le_wcHi {s : Stack} (h : s.Wf) : s.wcLo ≤ s.wcHi := by
  induction s with
  | nil => simp
  | cons t s ih =>
      obtain ⟨ht, hs⟩ := wf_cons h
      have h1 := Term.lo_le_hi ht
      have h2 := ih hs
      simp only [wcLo_cons, wcHi_cons]
      omega

/-! ## The checker -/

/-- Decision procedure: does this chain always land inside the design window
`[lo, hi]`? -/
def fitsWithin (s : Stack) (lo hi : Int) : Bool :=
  decide (lo ≤ s.wcLo) && decide (s.wcHi ≤ hi)

/-- Clearance check: the chain is a gap that never closes to interference. -/
def noInterference (s : Stack) : Bool := decide (0 ≤ s.wcLo)

/-- **No false pass.** If the checker accepts, every manufacturable assembly is
in spec. -/
theorem fitsWithin_sound {s : Stack} {lo hi : Int} (h : s.fitsWithin lo hi = true)
    {xs : List Int} (hr : Realizes s xs) :
    lo ≤ eval s xs ∧ eval s xs ≤ hi := by
  simp only [fitsWithin, Bool.and_eq_true, decide_eq_true_eq] at h
  have := eval_mem_worstCase hr
  omega

/-- **No false fail.** If the checker rejects a well-formed chain, some
manufacturable assembly really is out of spec. -/
theorem fitsWithin_complete {s : Stack} {lo hi : Int} (hwf : s.Wf)
    (h : s.fitsWithin lo hi = false) :
    ∃ xs, Realizes s xs ∧ ¬ (lo ≤ eval s xs ∧ eval s xs ≤ hi) := by
  simp only [fitsWithin, Bool.and_eq_false_iff, decide_eq_false_iff_not,
    Int.not_le] at h
  rcases h with h | h
  · exact ⟨s.argLo, argLo_realizes hwf, by rw [eval_argLo]; omega⟩
  · exact ⟨s.argHi, argHi_realizes hwf, by rw [eval_argHi]; omega⟩

theorem noInterference_sound {s : Stack} (h : s.noInterference = true)
    {xs : List Int} (hr : Realizes s xs) : 0 ≤ eval s xs := by
  simp only [noInterference, decide_eq_true_eq] at h
  have := eval_mem_worstCase hr
  omega

theorem noInterference_complete {s : Stack} (hwf : s.Wf)
    (h : s.noInterference = false) :
    ∃ xs, Realizes s xs ∧ eval s xs < 0 := by
  simp only [noInterference, decide_eq_false_iff_not, Int.not_le] at h
  exact ⟨s.argLo, argLo_realizes hwf, by rw [eval_argLo]; omega⟩

end Stack

end TolStack
