/-
# LyapCert.Envelope

The Lyapunov argument itself, proved once and for any state type.

Nothing here knows about matrices, quadratic forms or dimensions. A system is a
state-update map, a Lyapunov function is any `V : S → Int` that is non-negative
and decreases by a factor `num / den` each step, and the results are the three
statements an engineer actually wants from a stability certificate:

* `sublevel_invariant` — the set `{x | V x ≤ c}` is forward invariant. This is
  the certified envelope: enter it and you never leave.
* `envelope` — the geometric bound `V(x_k) ≤ (num/den)^k V(x_0)`, in
  cleared-denominator integer form so no division is needed.
* `settles` — a certified settling time. If the integers say
  `num^k V(x_0) ≤ den^k c`, then after `k` steps the state is inside the level
  set `c`, for every initial condition satisfying the bound.

The hypotheses `hV` and `hdec` are exactly non-negativity and non-increase along
the flow, which is what a Lyapunov predicate over a metric state space requires.
Discharging them by computation is the job of `LyapCert.Quadratic`.
-/
import LyapCert.Arith

set_option autoImplicit false

namespace LyapCert

variable {S : Type}

/-- `iterate step k x` is the state after `k` steps. -/
def iterate (step : S → S) : Nat → S → S
  | 0, x => x
  | k + 1, x => step (iterate step k x)

@[simp] theorem iterate_zero (step : S → S) (x : S) : iterate step 0 x = x := rfl

@[simp] theorem iterate_succ (step : S → S) (k : Nat) (x : S) :
    iterate step (k + 1) x = step (iterate step k x) := rfl

section

variable (step : S → S) (V : S → Int) (num den : Int)

/-- **Geometric envelope.** Written multiplicatively: `den^k · V(x_k) ≤ num^k · V(x_0)`,
which is `V(x_k) ≤ (num/den)^k V(x_0)` with the division cleared. -/
theorem envelope (hden : 0 < den) (hnum : 0 ≤ num)
    (hdec : ∀ x, den * V (step x) ≤ num * V x) (k : Nat) (x : S) :
    ipow den k * V (iterate step k x) ≤ ipow num k * V x := by
  induction k with
  | zero => simp
  | succ k ih =>
      simp only [iterate_succ, ipow_succ]
      exact step_chain (ipow_nonneg (Int.le_of_lt hden) k) hnum
        (hdec (iterate step k x)) (Int.mul_le_mul_of_nonneg_left ih hnum)

/-- A non-expansive certificate (`num ≤ den`) makes `V` non-increasing along the
whole trajectory. -/
theorem nonincreasing (hden : 0 < den) (hnum : 0 ≤ num) (hle : num ≤ den)
    (hV : ∀ x, 0 ≤ V x)
    (hdec : ∀ x, den * V (step x) ≤ num * V x) (k : Nat) (x : S) :
    V (iterate step k x) ≤ V x := by
  have hEnv := envelope step V num den hden hnum hdec k x
  have hmono : ipow num k ≤ ipow den k := ipow_le_ipow hnum hle k
  have hchain : ipow num k * V x ≤ ipow den k * V x :=
    Int.mul_le_mul_of_nonneg_right hmono (hV x)
  exact Int.le_of_mul_le_mul_left (Int.le_trans hEnv hchain) (ipow_pos hden k)

/-- **The certified envelope.** Every sublevel set of `V` is forward invariant,
so a state that starts inside stays inside for all time. -/
theorem sublevel_invariant (hden : 0 < den) (hnum : 0 ≤ num) (hle : num ≤ den)
    (hV : ∀ x, 0 ≤ V x)
    (hdec : ∀ x, den * V (step x) ≤ num * V x) (c : Int) (k : Nat) (x : S)
    (hx : V x ≤ c) : V (iterate step k x) ≤ c :=
  Int.le_trans (nonincreasing step V num den hden hnum hle hV hdec k x) hx

/-- **Certified settling bound.** If the integer test `num^k · V(x₀) ≤ den^k · c`
passes, the state is inside the level set `c` after `k` steps. The test is a
finite integer computation, so it can be discharged by `decide`. -/
theorem settles (hden : 0 < den) (hnum : 0 ≤ num)
    (hdec : ∀ x, den * V (step x) ≤ num * V x) (c : Int) (k : Nat) (x : S)
    (hk : ipow num k * V x ≤ ipow den k * c) :
    V (iterate step k x) ≤ c :=
  Int.le_of_mul_le_mul_left
    (Int.le_trans (envelope step V num den hden hnum hdec k x) hk)
    (ipow_pos hden k)

end

end LyapCert
