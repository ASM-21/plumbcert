/-
# DimCert.Expr

The checker: an expression language over named physical quantities, a dimension
inference function, and the theorem that makes inference mean something.

The theorem is `scale_eq_of_infer`. `scale` says how the *numeric value* of an
expression moves when the base units are rescaled, computed structurally from
the operations. `infer` says what dimension the expression has, computed from
the declared dimensions of its symbols. The theorem is that the first is
determined by the second: a well-dimensioned expression scales exactly as its
dimension says it should, and nothing else about its structure matters.

Two consequences:

* `Equation.scale_agree` — a dimensionally consistent equation's two sides move
  identically under any change of unit, so whether it holds cannot depend on
  which units you wrote it in.
* `Equation.separator_detects` — the converse. If two sides carry different
  dimensions, there is an explicit change of units that pulls them apart. A
  dimensional error is never invisible; it is always a unit system away from
  showing up.
-/
import DimCert.Dimension

set_option autoImplicit false

namespace DimCert

open Dimension

/-- Combine two inferred dimensions that are required to agree, as addition and
subtraction require. -/
def joinEq : Option Dimension → Option Dimension → Option Dimension
  | some x, some y => if x = y then some x else none
  | _, _ => none

/-- `joinEq` succeeds exactly when both sides infer to the same dimension. -/
theorem joinEq_eq_some {p q : Option Dimension} {d : Dimension} :
    joinEq p q = some d ↔ (p = some d ∧ q = some d) := by
  cases p with
  | none => simp [joinEq]
  | some x =>
    cases q with
    | none => simp [joinEq]
    | some y =>
      simp only [joinEq]
      by_cases hxy : x = y
      · subst hxy; simp
      · simp only [if_neg hxy]
        constructor
        · intro h; exact absurd h (by simp)
        · intro h
          obtain ⟨h1, h2⟩ := h
          simp only [Option.some.injEq] at h1 h2
          exact absurd (h1.trans h2.symm) hxy

/-- An expression over named physical quantities. Numeric literals carry no
dimension and are all folded into `const`. -/
inductive Expr where
  | sym   : String → Dimension → Expr
  | const : Expr
  | mul   : Expr → Expr → Expr
  | div   : Expr → Expr → Expr
  | pow   : Expr → Int → Expr
  | add   : Expr → Expr → Expr
  | sub   : Expr → Expr → Expr
  | sqrt  : Expr → Expr
  deriving Repr, Inhabited

namespace Expr

/-- Infer the dimension of an expression, or fail. Addition and subtraction
require both sides to agree; `sqrt` requires the radicand to be a perfect square
in the exponents. -/
def infer : Expr → Option Dimension
  | sym _ d => some d
  | const => some Dimension.one
  | mul a b =>
      match infer a, infer b with
      | some x, some y => some (x * y)
      | _, _ => none
  | div a b =>
      match infer a, infer b with
      | some x, some y => some (x / y)
      | _, _ => none
  | pow a n =>
      match infer a with
      | some x => some (x ^ n)
      | none => none
  | add a b => joinEq (infer a) (infer b)
  | sub a b => joinEq (infer a) (infer b)
  | sqrt a =>
      match infer a with
      | some x => Dimension.sqrt? x
      | none => none

/-- How far the numeric value of the expression moves, in decades, when the base
units are rescaled by `r`. Measure a length in kilometres instead of metres and
the number gets smaller, hence the negation on symbols. -/
def scale : Expr → Rescale → Int
  | sym _ d, r => -(d.decadeShift r)
  | const, _ => 0
  | mul a b, r => scale a r + scale b r
  | div a b, r => scale a r - scale b r
  | pow a n, r => n * scale a r
  | add a b, r => scale a r
  | sub a b, r => scale a r
  | sqrt a, r => scale a r / 2

/-- **Soundness of the checker against a change of units.** A well-dimensioned
expression scales exactly as its inferred dimension dictates. -/
theorem scale_eq_of_infer {e : Expr} : ∀ {d : Dimension}, e.infer = some d →
    ∀ r : Rescale, e.scale r = -(d.decadeShift r) := by
  induction e with
  | sym s dd =>
      intro d h r
      simp only [infer, Option.some.injEq] at h
      subst h
      rfl
  | const =>
      intro d h r
      simp only [infer, Option.some.injEq] at h
      subst h
      simp [scale, decadeShift_one]
  | mul a b iha ihb =>
      intro d h r
      simp only [infer] at h
      cases ha : a.infer with
      | none => rw [ha] at h; simp at h
      | some x =>
        cases hb : b.infer with
        | none => rw [ha, hb] at h; simp at h
        | some y =>
          rw [ha, hb] at h
          simp only [Option.some.injEq] at h
          subst h
          simp only [scale, iha ha r, ihb hb r, decadeShift_mul]
          omega
  | div a b iha ihb =>
      intro d h r
      simp only [infer] at h
      cases ha : a.infer with
      | none => rw [ha] at h; simp at h
      | some x =>
        cases hb : b.infer with
        | none => rw [ha, hb] at h; simp at h
        | some y =>
          rw [ha, hb] at h
          simp only [Option.some.injEq] at h
          subst h
          simp only [scale, iha ha r, ihb hb r, decadeShift_div]
          omega
  | pow a n iha =>
      intro d h r
      simp only [infer] at h
      cases ha : a.infer with
      | none => rw [ha] at h; simp at h
      | some x =>
        rw [ha] at h
        simp only [Option.some.injEq] at h
        subst h
        simp only [scale, iha ha r, decadeShift_pow, Int.mul_neg]
  | add a b iha ihb =>
      intro d h r
      simp only [infer, joinEq_eq_some] at h
      exact iha h.1 r
  | sub a b iha ihb =>
      intro d h r
      simp only [infer, joinEq_eq_some] at h
      exact iha h.1 r
  | sqrt a iha =>
      intro d h r
      simp only [infer] at h
      cases ha : a.infer with
      | none => rw [ha] at h; simp at h
      | some x =>
        rw [ha] at h
        have hx : d * d = x := sqrt?_sq h
        have hs : x.decadeShift r = 2 * d.decadeShift r := by
          rw [← hx, decadeShift_mul]; omega
        simp only [scale, iha ha r, hs]
        omega

/-- Dimensionless expressions are unit-system invariant. -/
theorem scale_eq_zero_of_dimensionless {e : Expr} (h : e.infer = some Dimension.one)
    (r : Rescale) : e.scale r = 0 := by
  rw [scale_eq_of_infer h r, decadeShift_one]
  rfl

end Expr

/-! ## Equations -/

/-- A named engineering formula, as an equation between two expressions. -/
structure Equation where
  name : String
  lhs : Expr
  rhs : Expr
  deriving Repr, Inhabited

namespace Equation

/-- Dimensional consistency: both sides infer, and to the same dimension. -/
def checks (q : Equation) : Bool :=
  match q.lhs.infer, q.rhs.infer with
  | some a, some b => a = b
  | _, _ => false

/-- **A consistent formula is unit-system independent.** Both sides of a
dimensionally consistent equation move by the same number of decades under any
change of base units, so whether the equation holds cannot depend on the units
it was written in. -/
theorem scale_agree {q : Equation} (h : q.checks = true) (r : Rescale) :
    q.lhs.scale r = q.rhs.scale r := by
  simp only [checks] at h
  cases hl : q.lhs.infer with
  | none => rw [hl] at h; simp at h
  | some a =>
    cases hr : q.rhs.infer with
    | none => rw [hl, hr] at h; simp at h
    | some b =>
      rw [hl, hr] at h
      simp only [decide_eq_true_eq] at h
      subst h
      rw [Expr.scale_eq_of_infer hl r, Expr.scale_eq_of_infer hr r]

/-- A change of units that separates two different dimensions: shift whichever
base dimension they first disagree on by one decade. -/
def separator (a b : Dimension) : Rescale :=
  if a.length ≠ b.length then { length := 1 }
  else if a.mass ≠ b.mass then { mass := 1 }
  else if a.time ≠ b.time then { time := 1 }
  else if a.current ≠ b.current then { current := 1 }
  else if a.temperature ≠ b.temperature then { temperature := 1 }
  else if a.amount ≠ b.amount then { amount := 1 }
  else { luminous := 1 }

/-- **Every dimensional error is detectable.** Different dimensions always move
differently under some change of units, and `separator` produces one. -/
theorem separator_detects {a b : Dimension} (h : a ≠ b) :
    a.decadeShift (separator a b) ≠ b.decadeShift (separator a b) := by
  cases a; cases b
  simp only [ne_eq, Dimension.mk.injEq, not_and] at h
  unfold separator decadeShift
  repeat' split
  all_goals simp_all
  all_goals omega

end Equation

end DimCert
