/-
# DimCert.Dimension

Physical dimensions as the free abelian group on the seven SI base dimensions,
written additively in the exponents.

Everything is `Int`, so equality is decidable by kernel computation and every
algebraic law below falls to `omega`. No mathlib, no dependencies.

The second half of the file is the part that gives dimensional analysis its
teeth: a change of unit system is an integer decade shift per base dimension
(`Rescale`), and `decadeShift` is a group homomorphism from dimensions to that
shift. That homomorphism is what `DimCert.Expr` uses to prove the checker
sound.
-/

set_option autoImplicit false

namespace DimCert

/-- Exponents of the seven SI base dimensions. -/
structure Dimension where
  length      : Int := 0
  mass        : Int := 0
  time        : Int := 0
  current     : Int := 0
  temperature : Int := 0
  amount      : Int := 0
  luminous    : Int := 0
  deriving DecidableEq, Repr, Inhabited

namespace Dimension

/-- The dimensionless dimension, the identity of the group. -/
def one : Dimension := {}

def mul (a b : Dimension) : Dimension :=
  { length := a.length + b.length
    mass := a.mass + b.mass
    time := a.time + b.time
    current := a.current + b.current
    temperature := a.temperature + b.temperature
    amount := a.amount + b.amount
    luminous := a.luminous + b.luminous }

def inv (a : Dimension) : Dimension :=
  { length := -a.length
    mass := -a.mass
    time := -a.time
    current := -a.current
    temperature := -a.temperature
    amount := -a.amount
    luminous := -a.luminous }

def div (a b : Dimension) : Dimension := mul a (inv b)

/-- Integer power. Rational exponents are deliberately not modelled; the one
half-power that engineering formulas actually need is handled by `sqrt?`, which
is defined exactly when it is exact. -/
def pow (a : Dimension) (n : Int) : Dimension :=
  { length := n * a.length
    mass := n * a.mass
    time := n * a.time
    current := n * a.current
    temperature := n * a.temperature
    amount := n * a.amount
    luminous := n * a.luminous }

instance : Mul Dimension := ⟨mul⟩
instance : Div Dimension := ⟨div⟩
instance : Inv Dimension := ⟨inv⟩
instance : HPow Dimension Int Dimension := ⟨pow⟩

@[simp] theorem mul_def (a b : Dimension) : a * b = mul a b := rfl
@[simp] theorem div_def (a b : Dimension) : a / b = div a b := rfl
@[simp] theorem inv_def (a : Dimension) : a⁻¹ = inv a := rfl
@[simp] theorem pow_def (a : Dimension) (n : Int) : a ^ n = pow a n := rfl

/-! ## Abelian group laws -/

theorem mul_assoc (a b c : Dimension) : a * b * c = a * (b * c) := by
  cases a; cases b; cases c; simp [mul, Dimension.mk.injEq]; omega

theorem mul_comm (a b : Dimension) : a * b = b * a := by
  cases a; cases b; simp [mul, Dimension.mk.injEq]; omega

theorem one_mul (a : Dimension) : one * a = a := by
  cases a; simp [mul, one]

theorem mul_one (a : Dimension) : a * one = a := by
  cases a; simp [mul, one]

theorem mul_inv (a : Dimension) : a * a⁻¹ = one := by
  cases a; simp [mul, inv, one, Dimension.mk.injEq]; omega

theorem div_self (a : Dimension) : a / a = one := by
  cases a; simp [div, mul, inv, one, Dimension.mk.injEq]; omega

theorem div_mul_cancel (a b : Dimension) : a / b * b = a := by
  cases a; cases b; simp [div, mul, inv, Dimension.mk.injEq]; omega

theorem pow_zero (a : Dimension) : a ^ (0 : Int) = one := by
  cases a; simp [pow, one]

theorem pow_one (a : Dimension) : a ^ (1 : Int) = a := by
  cases a; simp [pow]

theorem pow_add (a : Dimension) (m n : Int) : a ^ (m + n) = a ^ m * a ^ n := by
  cases a; simp [pow, mul, Int.add_mul]

theorem pow_two (a : Dimension) : a ^ (2 : Int) = a * a := by
  cases a; simp [pow, mul, Dimension.mk.injEq]; omega

/-! ## Square roots, exactly when they are exact -/

/-- Every exponent is even, so the dimension is a perfect square. -/
def IsSquare (d : Dimension) : Prop :=
  d.length % 2 = 0 ∧ d.mass % 2 = 0 ∧ d.time % 2 = 0 ∧ d.current % 2 = 0 ∧
  d.temperature % 2 = 0 ∧ d.amount % 2 = 0 ∧ d.luminous % 2 = 0

instance (d : Dimension) : Decidable d.IsSquare := by
  unfold IsSquare; infer_instance

def half (d : Dimension) : Dimension :=
  { length := d.length / 2
    mass := d.mass / 2
    time := d.time / 2
    current := d.current / 2
    temperature := d.temperature / 2
    amount := d.amount / 2
    luminous := d.luminous / 2 }

/-- The square root of a dimension, defined exactly when it is exact. -/
def sqrt? (d : Dimension) : Option Dimension :=
  if d.IsSquare then some (half d) else none

/-- `sqrt?` really does return a square root. -/
theorem sqrt?_sq {d e : Dimension} (h : sqrt? d = some e) : e * e = d := by
  unfold sqrt? at h
  split at h
  · rename_i hsq
    cases d with
    | mk l m t c k n j =>
      simp only [IsSquare] at hsq
      obtain ⟨h1, h2, h3, h4, h5, h6, h7⟩ := hsq
      simp only [Option.some.injEq] at h
      subst h
      simp only [mul_def, mul, half, Dimension.mk.injEq]
      refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_⟩ <;> omega
  · simp at h

/-! ## Unit-system changes -/

/-- A change of unit system: how many decades each base unit moves. `metre` to
`kilometre` is `length := 3`. -/
structure Rescale where
  length      : Int := 0
  mass        : Int := 0
  time        : Int := 0
  current     : Int := 0
  temperature : Int := 0
  amount      : Int := 0
  luminous    : Int := 0
  deriving DecidableEq, Repr, Inhabited

/-- How far the numeric value of a quantity of dimension `d` moves, in decades,
when the base units are rescaled by `r`. A quantity measured in bigger units has
a smaller number, hence the sign convention in `DimCert.Expr`. -/
def decadeShift (d : Dimension) (r : Rescale) : Int :=
  d.length * r.length + d.mass * r.mass + d.time * r.time +
  d.current * r.current + d.temperature * r.temperature +
  d.amount * r.amount + d.luminous * r.luminous

/-- **The homomorphism.** Dimensions multiply, decade shifts add. -/
theorem decadeShift_mul (a b : Dimension) (r : Rescale) :
    decadeShift (a * b) r = decadeShift a r + decadeShift b r := by
  cases a; cases b
  simp [decadeShift, mul, Int.add_mul]
  omega

theorem decadeShift_one (r : Rescale) : decadeShift one r = 0 := by
  simp [decadeShift, one]

theorem decadeShift_inv (a : Dimension) (r : Rescale) :
    decadeShift a⁻¹ r = -decadeShift a r := by
  cases a
  simp [decadeShift, inv, Int.neg_mul]
  omega

theorem decadeShift_div (a b : Dimension) (r : Rescale) :
    decadeShift (a / b) r = decadeShift a r - decadeShift b r := by
  cases a; cases b
  simp [decadeShift, div, mul, inv, Int.add_mul, Int.neg_mul]
  omega

theorem decadeShift_pow (a : Dimension) (n : Int) (r : Rescale) :
    decadeShift (a ^ n) r = n * decadeShift a r := by
  cases a
  simp [decadeShift, pow, Int.mul_add, Int.mul_assoc]

/-- A dimensionless quantity is the same number in every unit system. This is
the reason engineers reach for dimensionless groups. -/
theorem decadeShift_eq_zero_of_one {d : Dimension} (h : d = one) (r : Rescale) :
    decadeShift d r = 0 := by subst h; exact decadeShift_one r

end Dimension

end DimCert
