/-
# CarbonSched.Bounds

Ratio bounds, and an honest account of what an online scheduler can promise.

Two different things get called "the carbon savings" and they are not the same
claim:

* `savings_certified` — what a certified offline schedule saves against a
  specific baseline. This is exact and instance-specific: the number the
  Examples module reports.
* `online_ratio` — what a scheduler with no knowledge of future intensity can
  guarantee against the offline optimum. This is a worst-case ratio, and it is
  the intensity spread `hi / lo` of the feasible window.

`online_ratio_tight` shows the second bound cannot be improved: an instance
where a deterministic online policy really does pay the full ratio. That is the
part usually left out of carbon-aware scheduling claims, and it is the reason
lookahead (a forecast) is worth paying for rather than a nicety.

All ratios are stated multiplicatively, `lo * cost alg ≤ hi * cost opt`, so no
division is needed and everything stays in `Int`.
-/
import CarbonSched.Optimality

set_option autoImplicit false

namespace CarbonSched

/-- A schedule whose slots are all at most `hi` costs at most `hi` per slot. -/
theorem cost_le_of_selLe : ∀ (m : Mask) (p : Profile) (hi : Int),
    SelLe m p hi = true → 0 ≤ hi → cost m p ≤ hi * count m := by
  intro m
  induction m with
  | nil => intro p hi _ h; cases p <;> simp
  | cons b bs ih =>
      intro p hi h hhi
      cases p with
      | nil => simp_all [SelLe]
      | cons c cs =>
        simp only [SelLe, Bool.and_eq_true] at h
        have hrec := ih cs hi h.2 hhi
        cases b with
        | true =>
            have hc : c ≤ hi := by simpa using h.1
            show c + cost bs cs ≤ hi * (1 + count bs)
            rw [Int.mul_add, Int.mul_one]
            exact Int.add_le_add hc hrec
        | false =>
            show 0 + cost bs cs ≤ hi * (0 + count bs)
            rw [Int.zero_add, Int.zero_add]
            exact hrec

/-- A schedule whose slots are all at least `lo` costs at least `lo` per slot. -/
theorem cost_ge_of_selGe : ∀ (m : Mask) (p : Profile) (lo : Int),
    SelGe m p lo = true → 0 ≤ lo → lo * count m ≤ cost m p := by
  intro m
  induction m with
  | nil => intro p lo _ h; cases p <;> simp
  | cons b bs ih =>
      intro p lo h hlo
      cases p with
      | nil => simp_all [SelGe]
      | cons c cs =>
        simp only [SelGe, Bool.and_eq_true] at h
        have hrec := ih cs lo h.2 hlo
        cases b with
        | true =>
            have hc : lo ≤ c := by simpa using h.1
            show lo * (1 + count bs) ≤ c + cost bs cs
            rw [Int.mul_add, Int.mul_one]
            exact Int.add_le_add hc hrec
        | false =>
            show lo * (0 + count bs) ≤ 0 + cost bs cs
            rw [Int.zero_add, Int.zero_add]
            exact hrec

/-- **Competitive ratio of any feasible policy, online or not.** If every
allowed slot lies in `[lo, hi]`, then any schedule costs at most `hi/lo` times
any other schedule of the same length. Stated with denominators cleared.

This is the guarantee available with no forecast at all: it depends only on the
spread of the intensity profile, not on the policy. It is also the *only*
guarantee available without a forecast, which `online_ratio_tight` makes
precise. -/
theorem online_ratio {alg opt : Mask} {p : Profile} {lo hi : Int}
    (halg : SelLe alg p hi = true) (hopt : SelGe opt p lo = true)
    (hlo : 0 ≤ lo) (hhi : 0 ≤ hi) (hcount : count alg = count opt) :
    lo * cost alg p ≤ hi * cost opt p := by
  have h1 : cost alg p ≤ hi * count alg := cost_le_of_selLe alg p hi halg hhi
  have h2 : lo * count opt ≤ cost opt p := cost_ge_of_selGe opt p lo hopt hlo
  calc lo * cost alg p ≤ lo * (hi * count alg) :=
        Int.mul_le_mul_of_nonneg_left h1 hlo
    _ = hi * (lo * count opt) := by rw [hcount]; grind
    _ ≤ hi * cost opt p := Int.mul_le_mul_of_nonneg_left h2 hhi

/-- **Savings of a certified schedule against a baseline**, as a proved
inequality rather than a measured one. `base` is any allowed schedule of the
same length: run-immediately, run-at-a-fixed-hour, or last week's actual. -/
theorem savings_certified {m base f : Mask} {p : Profile} {θ : Int}
    (h : Certified m f p θ = true) (hbase : Sub base f = true)
    (hcount : count m = count base) :
    0 ≤ cost base p - cost m p := by
  have := certified_optimal h hbase hcount
  omega

/-! ## Tightness

The witness is a two-slot horizon with intensities `lo` and `hi`, both allowed,
and a load needing one slot. A deterministic online policy at slot 0 has no
information distinguishing this instance from its mirror image, so whichever way
it commits there is an instance where it takes the expensive slot while the
offline optimum takes the cheap one. Here is that instance, with both schedules
and their exact costs.
-/

/-- The adversarial two-slot instance: allowed everywhere, one slot needed. -/
def tightProfile (lo hi : Int) : Profile := [hi, lo]

def tightFeasible : Mask := [true, true]

/-- What the online policy does when it commits at slot 0. -/
def tightOnline : Mask := [true, false]

/-- What the offline optimum does. -/
def tightOffline : Mask := [false, true]

theorem tight_counts : count tightOnline = count tightOffline := by decide

theorem tight_online_cost (lo hi : Int) : cost tightOnline (tightProfile lo hi) = hi := by
  simp [cost, tightOnline, tightProfile]

theorem tight_offline_cost (lo hi : Int) : cost tightOffline (tightProfile lo hi) = lo := by
  simp [cost, tightOffline, tightProfile]

/-- The offline schedule is certified optimal here, with threshold `lo`. -/
theorem tight_offline_certified (lo hi : Int) (h : lo ≤ hi) :
    Certified tightOffline tightFeasible (tightProfile lo hi) lo = true := by
  simp [Certified, Sub, BelowSel, AboveUnsel, tightOffline, tightFeasible, tightProfile, h]

/-- **The `hi/lo` bound is tight.** On this instance the online policy pays
exactly `hi` where the optimum pays exactly `lo`, so no better ratio than
`hi/lo` is provable for a policy that must commit without a forecast. -/
theorem online_ratio_tight (lo hi : Int) :
    lo * cost tightOnline (tightProfile lo hi)
      = hi * cost tightOffline (tightProfile lo hi) := by
  rw [tight_online_cost, tight_offline_cost]; grind

end CarbonSched
