/-
# CarbonSched.Basic

Carbon-aware scheduling of a deferrable load over a slotted horizon.

A schedule is a `List Bool` over the slots: `true` means the load runs in that
slot. Everything downstream is list recursion over that mask, which is what lets
the optimality argument be an ordinary induction with no set theory, no
permutations and no sorting.

Feasibility is a second mask. It carries release times, deadlines and forced
outages all at once, without any of them appearing in the theorems: a slot the
load may occupy is `true` in the feasibility mask, and how it got that way is
the caller's business.
-/

set_option autoImplicit false

namespace CarbonSched

/-- Marginal carbon intensity per slot, in whatever integer unit the caller
picks (the examples use kg CO₂ per MWh). -/
abbrev Profile := List Int

/-- Which slots the load occupies. -/
abbrev Mask := List Bool

/-- Total carbon of a schedule against a profile. -/
def cost : Mask → Profile → Int
  | [], _ => 0
  | _, [] => 0
  | b :: bs, c :: cs => (if b then c else 0) + cost bs cs

/-- How many slots the schedule occupies. -/
def count : Mask → Int
  | [] => 0
  | b :: bs => (if b then 1 else 0) + count bs

/-- `Sub m f`: every slot the schedule uses is one it is allowed to use. Also
forces the two masks to have the same length. -/
def Sub : Mask → Mask → Bool
  | [], [] => true
  | b :: bs, f :: fs => (!b || f) && Sub bs fs
  | _, _ => false

/-- Every occupied slot is at or below `θ`. Length-checked against the profile. -/
def BelowSel : Mask → Profile → Int → Bool
  | [], [], _ => true
  | b :: bs, c :: cs, θ => (!b || decide (c ≤ θ)) && BelowSel bs cs θ
  | _, _, _ => false

/-- Every slot that is allowed but unoccupied is at or above `θ`. -/
def AboveUnsel : Mask → Mask → Profile → Int → Bool
  | [], [], [], _ => true
  | b :: bs, f :: fs, c :: cs, θ =>
      (b || !f || decide (θ ≤ c)) && AboveUnsel bs fs cs θ
  | _, _, _, _ => false

/-- Every occupied slot costs at most `hi`. -/
def SelLe : Mask → Profile → Int → Bool
  | [], [], _ => true
  | b :: bs, c :: cs, hi => (!b || decide (c ≤ hi)) && SelLe bs cs hi
  | _, _, _ => false

/-- Every occupied slot costs at least `lo`. -/
def SelGe : Mask → Profile → Int → Bool
  | [], [], _ => true
  | b :: bs, c :: cs, lo => (!b || decide (lo ≤ c)) && SelGe bs cs lo
  | _, _, _ => false

@[simp] theorem cost_nil_left (p : Profile) : cost [] p = 0 := by cases p <;> rfl
@[simp] theorem cost_nil_right (m : Mask) : cost m [] = 0 := by cases m <;> rfl
@[simp] theorem count_nil : count [] = 0 := rfl

theorem count_nonneg (m : Mask) : 0 ≤ count m := by
  induction m with
  | nil => simp
  | cons b bs ih => cases b <;> simp [count] <;> omega

/-! ## Building masks -/

/-- The all-slots-allowed mask of a given length. -/
def allowAll : Nat → Mask
  | 0 => []
  | n + 1 => true :: allowAll n

/-- Slots `[release, deadline)` are allowed, the rest are not. -/
def window (n release deadline : Nat) : Mask :=
  (List.range n).map (fun t => decide (release ≤ t ∧ t < deadline))

/-- Run as early as possible: the first `k` allowed slots. This is the
do-nothing baseline that carbon-aware scheduling is measured against. -/
def earliest : Mask → Nat → Mask
  | [], _ => []
  | _ :: fs, 0 => false :: earliest fs 0
  | f :: fs, k + 1 =>
      if f then true :: earliest fs k else false :: earliest fs (k + 1)

theorem count_allowAll : ∀ n : Nat, count (allowAll n) = (n : Int) := by
  intro n
  induction n with
  | zero => simp [allowAll, count]
  | succ k ih => simp only [allowAll, count, ih]; push_cast; omega

end CarbonSched
