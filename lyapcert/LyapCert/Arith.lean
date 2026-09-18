/-
# LyapCert.Arith

The small arithmetic toolkit this development needs, built from core `Int`
lemmas. `ipow` is defined here rather than reused from core so that every
inequality about it below is proved in this file with no external dependency.
-/

set_option autoImplicit false

namespace LyapCert

/-- Squares are non-negative. `grind` cannot see this (it treats `x * x` as an
opaque atom), so it goes by cases on the sign. -/
theorem mul_self_nonneg (x : Int) : 0 ≤ x * x := by
  rcases Int.le_total 0 x with h | h
  · exact Int.mul_nonneg h h
  · have h' : 0 ≤ -x := by omega
    have hp := Int.mul_nonneg h' h'
    rw [Int.neg_mul_neg] at hp
    exact hp

/-- Integer power, defined locally to keep this library dependency-free. -/
def ipow (a : Int) : Nat → Int
  | 0 => 1
  | n + 1 => a * ipow a n

@[simp] theorem ipow_zero (a : Int) : ipow a 0 = 1 := rfl

@[simp] theorem ipow_succ (a : Int) (n : Nat) : ipow a (n + 1) = a * ipow a n := rfl

theorem ipow_nonneg {a : Int} (h : 0 ≤ a) (k : Nat) : 0 ≤ ipow a k := by
  induction k with
  | zero => simp
  | succ n ih => exact Int.mul_nonneg h ih

theorem ipow_pos {a : Int} (h : 0 < a) (k : Nat) : 0 < ipow a k := by
  induction k with
  | zero => simp
  | succ n ih => exact Int.mul_pos h ih

theorem ipow_le_ipow {a b : Int} (ha : 0 ≤ a) (hab : a ≤ b) (k : Nat) :
    ipow a k ≤ ipow b k := by
  induction k with
  | zero => simp
  | succ n ih =>
      have hb : 0 ≤ b := Int.le_trans ha hab
      calc a * ipow a n ≤ a * ipow b n :=
            Int.mul_le_mul_of_nonneg_left ih ha
        _ ≤ b * ipow b n := by
            have := ipow_nonneg hb n
            exact Int.mul_le_mul_of_nonneg_right hab this

/-- The rearrangement at the heart of the envelope induction, isolated so the
induction step is a single application. -/
theorem step_chain {A B C D E num den : Int}
    (hA : 0 ≤ A) (hnum : 0 ≤ num)
    (h1 : den * B ≤ num * C)
    (h2 : num * (A * C) ≤ num * (D * E)) :
    den * A * B ≤ num * D * E := by
  calc den * A * B = A * (den * B) := by grind
    _ ≤ A * (num * C) := Int.mul_le_mul_of_nonneg_left h1 hA
    _ = num * (A * C) := by grind
    _ ≤ num * (D * E) := h2
    _ = num * D * E := by grind

end LyapCert
