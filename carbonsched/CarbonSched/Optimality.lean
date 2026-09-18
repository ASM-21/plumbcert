/-
# CarbonSched.Optimality

Exact optimality of a carbon-aware schedule, certified by a single number.

The certificate is a threshold `θ`: every slot the schedule occupies is at or
below it, and every slot the schedule was allowed to occupy but didn't is at or
above it. That is checkable by kernel computation, and it is enough.

The engine is `cost_diff_le`, whose statement is the invariant that makes the
whole thing an ordinary list induction:

    cost m p - cost m' p ≤ θ * (count m - count m')

Slot by slot, a slot the certified schedule takes and the rival doesn't costs at
most `θ` and moves the count by one; a slot the rival takes and the certified
schedule doesn't costs at least `θ` and moves the count the other way. When the
two schedules run the load for the same number of slots the right-hand side
collapses to zero, which is optimality.

No permutations, no sorting, no exchange argument, and no assumption that the
profile is sorted. The certified schedule need not be the greedy one, or unique;
anything carrying a valid threshold is optimal.
-/
import CarbonSched.Basic

set_option autoImplicit false

namespace CarbonSched

/-- The core invariant. Proved by simultaneous induction over the four lists;
mismatched lengths are impossible because `Sub`, `BelowSel` and `AboveUnsel` all
return `false` on them. -/
theorem cost_diff_le (θ : Int) : ∀ (m m' f : Mask) (p : Profile),
    Sub m f = true → Sub m' f = true →
    BelowSel m p θ = true → AboveUnsel m f p θ = true →
    cost m p - cost m' p ≤ θ * (count m - count m') := by
  intro m
  induction m with
  | nil =>
      intro m' f p h1 h2 _ _
      cases f <;> cases m' <;> cases p <;> simp_all [Sub, cost, count]
  | cons b bs ih =>
      intro m' f p h1 h2 h3 h4
      cases m' with
      | nil => cases f <;> simp_all [Sub]
      | cons b' bs' =>
        cases f with
        | nil => simp_all [Sub]
        | cons fh ft =>
          cases p with
          | nil => simp_all [BelowSel]
          | cons c cs =>
            simp only [Sub, BelowSel, AboveUnsel, Bool.and_eq_true] at h1 h2 h3 h4
            have hrec := ih bs' ft cs h1.2 h2.2 h3.2 h4.2
            have hcb := count_nonneg bs
            have hcb' := count_nonneg bs'
            cases b <;> cases b' <;> cases fh <;>
              simp_all [cost, count, Int.mul_sub, Int.mul_add] <;> omega

/-- **A threshold certificate proves optimality.** Any allowed schedule that
runs the load for the same number of slots costs at least as much. The rival is
completely arbitrary: this is a statement about every schedule, not about the
ones an algorithm might produce. -/
theorem optimal {m m' f : Mask} {p : Profile} {θ : Int}
    (hsub : Sub m f = true) (hsub' : Sub m' f = true)
    (hbel : BelowSel m p θ = true) (habove : AboveUnsel m f p θ = true)
    (hcount : count m = count m') :
    cost m p ≤ cost m' p := by
  have h := cost_diff_le θ m m' f p hsub hsub' hbel habove
  rw [hcount] at h
  simp at h
  omega

/-- A certified schedule beats any allowed schedule that runs at least as long,
provided the profile has no negative slots. Useful when the rival is a baseline
that over-runs, such as an uncontrolled load. -/
theorem optimal_le_longer {m m' f : Mask} {p : Profile} {θ : Int}
    (hsub : Sub m f = true) (hsub' : Sub m' f = true)
    (hbel : BelowSel m p θ = true) (habove : AboveUnsel m f p θ = true)
    (hθ : 0 ≤ θ) (hcount : count m ≤ count m') :
    cost m p ≤ cost m' p := by
  have h := cost_diff_le θ m m' f p hsub hsub' hbel habove
  have : θ * (count m - count m') ≤ 0 :=
    Int.mul_nonpos_of_nonneg_of_nonpos hθ (by omega)
  omega

/-! ## Bundling the check -/

/-- Everything a certificate has to satisfy, as one Boolean. -/
def Certified (m f : Mask) (p : Profile) (θ : Int) : Bool :=
  Sub m f && BelowSel m p θ && AboveUnsel m f p θ

theorem certified_optimal {m m' f : Mask} {p : Profile} {θ : Int}
    (h : Certified m f p θ = true) (hsub' : Sub m' f = true)
    (hcount : count m = count m') :
    cost m p ≤ cost m' p := by
  simp only [Certified, Bool.and_eq_true] at h
  exact optimal h.1.1 hsub' h.1.2 h.2 hcount

end CarbonSched
