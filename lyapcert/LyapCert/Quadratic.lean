/-
# LyapCert.Quadratic

The computable half: quadratic Lyapunov functions on a two-state system, with
positivity carried by construction.

The design choice that makes this work without mathlib is to never ask "is this
matrix positive semidefinite". That question needs Sylvester's criterion or a
spectral argument. Instead a candidate Lyapunov function arrives already written
as a sum of weighted squares,

  V(v) = Σ cᵢ (aᵢ x + bᵢ y)²   with every cᵢ ≥ 0,

so `V ≥ 0` is immediate from `0 ≤ z * z`, and the decay condition arrives with a
second sum of squares `S` certifying the identity

  num · V(v) - den · V(M v) = S(v).

Both sides are quadratic forms, so that identity is an equality of three integer
coefficients: decidable, and checked by the kernel. Finding `P` and `S` is the
solver's job, in Python, in exact rational arithmetic. Checking them is Lean's.
Nothing here trusts the solver.
-/
import LyapCert.Arith
import LyapCert.Envelope

set_option autoImplicit false

namespace LyapCert

/-- A two-dimensional integer state. -/
structure Vec2 where
  x : Int
  y : Int
  deriving DecidableEq, Repr, Inhabited

/-- A 2×2 integer matrix, rows `(a b)` and `(c d)`. -/
structure Mat2 where
  a : Int
  b : Int
  c : Int
  d : Int
  deriving DecidableEq, Repr, Inhabited

def Mat2.apply (M : Mat2) (v : Vec2) : Vec2 :=
  ⟨M.a * v.x + M.b * v.y, M.c * v.x + M.d * v.y⟩

/-- A quadratic form `q11 x² + q12 x y + q22 y²`. `q12` is the full cross
coefficient, not the half-coefficient of the symmetric matrix, which keeps every
certificate an integer even when the matrix entry would be a half. -/
structure Quad where
  q11 : Int
  q12 : Int
  q22 : Int
  deriving DecidableEq, Repr, Inhabited

namespace Quad

def eval (Q : Quad) (v : Vec2) : Int :=
  Q.q11 * (v.x * v.x) + Q.q12 * (v.x * v.y) + Q.q22 * (v.y * v.y)

def add (Q R : Quad) : Quad := ⟨Q.q11 + R.q11, Q.q12 + R.q12, Q.q22 + R.q22⟩
def sub (Q R : Quad) : Quad := ⟨Q.q11 - R.q11, Q.q12 - R.q12, Q.q22 - R.q22⟩
def smul (c : Int) (Q : Quad) : Quad := ⟨c * Q.q11, c * Q.q12, c * Q.q22⟩

/-- Pull a quadratic form back along a linear map: `(Q.compose M)(v) = Q(M v)`. -/
def compose (Q : Quad) (M : Mat2) : Quad :=
  ⟨Q.q11 * M.a * M.a + Q.q12 * M.a * M.c + Q.q22 * M.c * M.c,
   2 * Q.q11 * M.a * M.b + Q.q12 * (M.a * M.d + M.b * M.c) + 2 * Q.q22 * M.c * M.d,
   Q.q11 * M.b * M.b + Q.q12 * M.b * M.d + Q.q22 * M.d * M.d⟩

@[simp] theorem eval_add (Q R : Quad) (v : Vec2) : (add Q R).eval v = Q.eval v + R.eval v := by
  grind [add, eval]

@[simp] theorem eval_sub (Q R : Quad) (v : Vec2) : (sub Q R).eval v = Q.eval v - R.eval v := by
  grind [sub, eval]

@[simp] theorem eval_smul (c : Int) (Q : Quad) (v : Vec2) :
    (smul c Q).eval v = c * Q.eval v := by
  grind [smul, eval]

/-- The pullback really is the pullback. This is the lemma that lets a matrix
identity stand in for a statement about every state. -/
@[simp] theorem eval_compose (Q : Quad) (M : Mat2) (v : Vec2) :
    (Q.compose M).eval v = Q.eval (M.apply v) := by
  simp only [compose, eval, Mat2.apply]
  grind

/-- Quadratic forms are homogeneous of degree two. -/
theorem eval_scaleVec (Q : Quad) (c : Int) (v : Vec2) :
    Q.eval ⟨c * v.x, c * v.y⟩ = c * c * Q.eval v := by
  grind [eval]

end Quad

/-- A weighted square `coeff · (a x + b y)²`. -/
structure Sq where
  coeff : Int
  a : Int
  b : Int
  deriving DecidableEq, Repr, Inhabited

namespace Sq

def lin (t : Sq) (v : Vec2) : Int := t.a * v.x + t.b * v.y

def eval (t : Sq) (v : Vec2) : Int := t.coeff * (t.lin v * t.lin v)

def quad (t : Sq) : Quad := ⟨t.coeff * t.a * t.a, 2 * (t.coeff * t.a * t.b), t.coeff * t.b * t.b⟩

theorem eval_eq_quad (t : Sq) (v : Vec2) : t.eval v = t.quad.eval v := by
  grind [eval, lin, quad, Quad.eval]

theorem eval_nonneg {t : Sq} (h : 0 ≤ t.coeff) (v : Vec2) : 0 ≤ t.eval v :=
  Int.mul_nonneg h (mul_self_nonneg (t.lin v))

end Sq

/-- A sum of weighted squares. -/
abbrev SOS := List Sq

namespace SOS

def eval : SOS → Vec2 → Int
  | [], _ => 0
  | t :: ts, v => t.eval v + eval ts v

def quad : SOS → Quad
  | [] => ⟨0, 0, 0⟩
  | t :: ts => Quad.add t.quad (quad ts)

/-- Every weight is non-negative, so the form is a genuine sum of squares. -/
def nonnegCoeffs : SOS → Bool
  | [] => true
  | t :: ts => decide (0 ≤ t.coeff) && nonnegCoeffs ts

theorem eval_eq_quad (s : SOS) (v : Vec2) : s.eval v = s.quad.eval v := by
  induction s with
  | nil => simp [eval, quad, Quad.eval]
  | cons t ts ih => simp [eval, quad, ih, Sq.eval_eq_quad]

/-- **Positivity for free.** A sum of squares with non-negative weights is
non-negative at every state, with no positive-definiteness test anywhere. -/
theorem eval_nonneg {s : SOS} (h : s.nonnegCoeffs = true) (v : Vec2) : 0 ≤ s.eval v := by
  induction s with
  | nil => simp [eval]
  | cons t ts ih =>
      simp only [nonnegCoeffs, Bool.and_eq_true, decide_eq_true_eq] at h
      have := ih h.2
      have := Sq.eval_nonneg h.1 v
      simp only [eval]
      omega

end SOS

/-! ## Certificates -/

/-- A stability certificate for the integer map `v ↦ M v`.

* `P` is the Lyapunov function as a sum of squares.
* `S` certifies the decay identity `num · V(v) - den · V(M v) = S(v)`.
* `num / den` is the per-step decay factor.
-/
structure Cert where
  M : Mat2
  P : SOS
  S : SOS
  num : Int
  den : Int
  deriving Repr, Inhabited

namespace Cert

/-- The Lyapunov function. -/
def V (C : Cert) (v : Vec2) : Int := C.P.eval v

/-- Everything that has to hold, as one Boolean the kernel can evaluate. -/
def Valid (C : Cert) : Bool :=
  C.P.nonnegCoeffs && C.S.nonnegCoeffs &&
  decide (0 < C.den) && decide (0 ≤ C.num) &&
  decide (Quad.sub (Quad.smul C.num C.P.quad) (Quad.smul C.den (C.P.quad.compose C.M)) = C.S.quad)

/-- A non-expansive certificate: the decay factor is at most one. -/
def NonExpansive (C : Cert) : Bool := C.Valid && decide (C.num ≤ C.den)

theorem V_nonneg {C : Cert} (h : C.Valid = true) (v : Vec2) : 0 ≤ C.V v := by
  simp only [Valid, Bool.and_eq_true] at h
  exact SOS.eval_nonneg h.1.1.1.1 v

/-- **The decay condition, discharged by computation.** The Boolean check
implies the inequality at every state, not just at tested points. -/
theorem decay {C : Cert} (h : C.Valid = true) (v : Vec2) :
    C.den * C.V (C.M.apply v) ≤ C.num * C.V v := by
  simp only [Valid, Bool.and_eq_true, decide_eq_true_eq] at h
  obtain ⟨⟨⟨⟨_hP, hS⟩, _hden⟩, _hnum⟩, hid⟩ := h
  have hval := congrArg (fun Q => Quad.eval Q v) hid
  simp only [Quad.eval_sub, Quad.eval_smul, Quad.eval_compose] at hval
  have hSnn : 0 ≤ C.S.eval v := SOS.eval_nonneg hS v
  rw [SOS.eval_eq_quad C.S v] at hSnn
  simp only [V, SOS.eval_eq_quad]
  omega

theorem den_pos {C : Cert} (h : C.Valid = true) : 0 < C.den := by
  simp only [Valid, Bool.and_eq_true, decide_eq_true_eq] at h
  exact h.1.1.2

theorem num_nonneg {C : Cert} (h : C.Valid = true) : 0 ≤ C.num := by
  simp only [Valid, Bool.and_eq_true, decide_eq_true_eq] at h
  exact h.1.2

/-! ### The three engineering statements, instantiated -/

/-- `V(x_k) ≤ (num/den)^k V(x_0)`, denominators cleared. -/
theorem envelope {C : Cert} (h : C.Valid = true) (k : Nat) (v : Vec2) :
    ipow C.den k * C.V (iterate C.M.apply k v) ≤ ipow C.num k * C.V v :=
  LyapCert.envelope C.M.apply C.V C.num C.den (den_pos h) (num_nonneg h) (decay h) k v

/-- A non-expansive certificate makes `V` non-increasing along the trajectory. -/
theorem nonincreasing {C : Cert} (h : C.NonExpansive = true) (k : Nat) (v : Vec2) :
    C.V (iterate C.M.apply k v) ≤ C.V v := by
  simp only [NonExpansive, Bool.and_eq_true, decide_eq_true_eq] at h
  exact LyapCert.nonincreasing C.M.apply C.V C.num C.den (den_pos h.1) (num_nonneg h.1)
    h.2 (V_nonneg h.1) (decay h.1) k v

/-- **The certified envelope.** Start inside a sublevel set and stay there. -/
theorem sublevel_invariant {C : Cert} (h : C.NonExpansive = true) (c : Int) (k : Nat)
    (v : Vec2) (hv : C.V v ≤ c) : C.V (iterate C.M.apply k v) ≤ c := by
  simp only [NonExpansive, Bool.and_eq_true, decide_eq_true_eq] at h
  exact LyapCert.sublevel_invariant C.M.apply C.V C.num C.den (den_pos h.1) (num_nonneg h.1)
    h.2 (V_nonneg h.1) (decay h.1) c k v hv

/-- **Certified settling.** The hypothesis is a finite integer comparison. -/
theorem settles {C : Cert} (h : C.Valid = true) (c : Int) (k : Nat) (v : Vec2)
    (hk : ipow C.num k * C.V v ≤ ipow C.den k * c) :
    C.V (iterate C.M.apply k v) ≤ c :=
  LyapCert.settles C.M.apply C.V C.num C.den (den_pos h) (num_nonneg h) (decay h) c k v hk

end Cert

end LyapCert
