/-
# GridCert.Flow

DC network model, superposition, and the N-1 screening test.

The point of this module is that the PTDF row a screening test runs on is not
taken on faith. A row is certified by exhibiting, for each bus, an angle vector
that solves the network equations for a unit injection at that bus; Lean checks
those solutions by computation, and `flow_addA` / `flow_smulA` are what let a
whole dispatch's flow be assembled from them. That is superposition, proved,
rather than assumed because the model is "linear".

What the module does *not* do is claim the DC model is the grid. See the README.
-/
import GridCert.Box

set_option autoImplicit false

namespace GridCert

/-- A branch. `susc` is the series susceptance `1/x`, scaled to an integer. -/
structure Line where
  src : Nat
  dst : Nat
  susc : Int
  deriving DecidableEq, Repr, Inhabited

abbrev Network := List Line

/-- Bus voltage angles, scaled to integers. -/
abbrev Angles := List Int

/-- Real power on a branch, in the scaled units induced by `susc` and `Angles`. -/
def Line.flow (l : Line) (θ : Angles) : Int :=
  l.susc * (θ.getD l.src 0 - θ.getD l.dst 0)

/-- Net injection at a bus: what flows out on incident branches. -/
def injAt : Network → Angles → Nat → Int
  | [], _, _ => 0
  | l :: ls, θ, i =>
      (if l.src = i then l.flow θ else 0) - (if l.dst = i then l.flow θ else 0)
        + injAt ls θ i

/-! ## Angle arithmetic -/

def addA : Angles → Angles → Angles
  | [], _ => []
  | _, [] => []
  | a :: as, b :: bs => (a + b) :: addA as bs

def smulA (k : Int) : Angles → Angles
  | [] => []
  | a :: as => k * a :: smulA k as

theorem length_addA : ∀ (a b : Angles), a.length = b.length →
    (addA a b).length = a.length := by
  intro a
  induction a with
  | nil => intro b _; simp [addA]
  | cons x xs ih =>
      intro b h
      cases b with
      | nil => simp at h
      | cons y ys => simp only [addA, List.length_cons]; simp at h; rw [ih ys h]

@[simp] theorem length_smulA (k : Int) : ∀ (a : Angles), (smulA k a).length = a.length := by
  intro a; induction a with
  | nil => simp [smulA]
  | cons x xs ih => simp [smulA, ih]

theorem getD_addA : ∀ (a b : Angles) (i : Nat), a.length = b.length →
    (addA a b).getD i 0 = a.getD i 0 + b.getD i 0 := by
  intro a
  induction a with
  | nil => intro b i h; cases b <;> simp_all [addA]
  | cons x xs ih =>
      intro b i h
      cases b with
      | nil => simp at h
      | cons y ys =>
        simp only [List.length_cons, Nat.add_right_cancel_iff] at h
        cases i with
        | zero => simp [addA, List.getD]
        | succ n => simpa [addA, List.getD] using ih ys n h

@[simp] theorem getD_smulA (k : Int) : ∀ (a : Angles) (i : Nat),
    (smulA k a).getD i 0 = k * a.getD i 0 := by
  intro a
  induction a with
  | nil => intro i; simp [smulA]
  | cons x xs ih =>
      intro i
      cases i with
      | zero => simp [smulA, List.getD]
      | succ n => simpa [smulA, List.getD] using ih n

/-! ## Superposition

Branch flow and nodal injection are both linear in the angles. This is what
licenses building a dispatch's flows out of per-bus unit solutions, which is
exactly what a PTDF row is.
-/

theorem flow_addA (l : Line) {θ₁ θ₂ : Angles} (h : θ₁.length = θ₂.length) :
    l.flow (addA θ₁ θ₂) = l.flow θ₁ + l.flow θ₂ := by
  simp only [Line.flow, getD_addA θ₁ θ₂ _ h]
  grind

theorem flow_smulA (l : Line) (k : Int) (θ : Angles) :
    l.flow (smulA k θ) = k * l.flow θ := by
  simp only [Line.flow, getD_smulA]
  grind

theorem injAt_addA (net : Network) {θ₁ θ₂ : Angles} (h : θ₁.length = θ₂.length) (i : Nat) :
    injAt net (addA θ₁ θ₂) i = injAt net θ₁ i + injAt net θ₂ i := by
  induction net with
  | nil => simp [injAt]
  | cons l ls ih =>
      simp only [injAt, flow_addA l h, ih]
      split <;> split <;> omega

theorem injAt_smulA (net : Network) (k : Int) (θ : Angles) (i : Nat) :
    injAt net (smulA k θ) i = k * injAt net θ i := by
  induction net with
  | nil => simp [injAt]
  | cons l ls ih =>
      simp only [injAt, flow_smulA l k θ, ih]
      split <;> split <;> grind

/-! ## Solved power flow

`Solves net θ p K` says the angle vector `θ` is an exact DC power flow solution
for the dispatch `p`, at scale `K`: the residual is zero at every bus. Because
it is a Boolean, `decide` settles it, and `solves_injAt` turns that one check
into a statement about each bus individually.

This is what stops a sensitivity row from being taken on faith. A row that
claims a branch flow is checked against the flow the network equations actually
produce at the binding dispatch.
-/

def solvesFrom : Network → Angles → Dispatch → Int → Nat → Bool
  | _, _, [], _, _ => true
  | net, θ, x :: xs, K, j =>
      decide (injAt net θ j = K * x) && solvesFrom net θ xs K (j + 1)

/-- Zero DC power flow residual at every bus, at scale `K`. -/
def Solves (net : Network) (θ : Angles) (p : Dispatch) (K : Int) : Bool :=
  solvesFrom net θ p K 0

theorem solvesFrom_injAt : ∀ (net : Network) (θ : Angles) (p : Dispatch) (K : Int) (j i : Nat),
    solvesFrom net θ p K j = true → i < p.length →
    injAt net θ (j + i) = K * p.getD i 0 := by
  intro net θ p
  induction p with
  | nil => intro K j i _ hi; simp at hi
  | cons x xs ih =>
      intro K j i h hi
      simp only [solvesFrom, Bool.and_eq_true, decide_eq_true_eq] at h
      cases i with
      | zero => simpa using h.1
      | succ n =>
        have hn : n < xs.length := by simp at hi; omega
        have hres := ih K (j + 1) n h.2 hn
        have harg : j + 1 + n = j + (n + 1) := by omega
        rw [harg] at hres
        have hg : (x :: xs).getD (n + 1) 0 = xs.getD n 0 := rfl
        rw [hg]
        exact hres

/-- **Zero residual, bus by bus.** -/
theorem solves_injAt {net : Network} {θ : Angles} {p : Dispatch} {K : Int}
    (h : Solves net θ p K = true) {i : Nat} (hi : i < p.length) :
    injAt net θ i = K * p.getD i 0 := by
  simpa using solvesFrom_injAt net θ p K 0 i h hi

/-! ## Certifying a sensitivity row

A sensitivity row is a claim about the network, and it is checked as one. For
each bus, the study supplies an angle vector; `RowCertified` demands that it be
an exact solution for a unit injection at that bus withdrawn at the slack, and
that the monitored branch's flow under it be the row entry.

That pins down every entry, not just the ones a particular dispatch happens to
excite. Together with `flow_addA` and `flow_smulA` above, which say branch flow
is linear in the angles, the row is then determined: it is the PTDF row, and the
study did not have to be believed about it.
-/

/-- Unit injection at `bus`, withdrawn at `slack`. -/
def unitDispatch (n bus slack : Nat) : Dispatch :=
  (List.range n).map (fun j => (if j = bus then 1 else 0) - (if j = slack then 1 else 0))

/-- One column: the witness solves the network, and reproduces the row entry. -/
def columnCertified (net : Network) (l : Line) (row : Row) (thetas : List Angles)
    (n slack : Nat) (K : Int) (i : Nat) : Bool :=
  Solves net (thetas.getD i []) (unitDispatch n i slack) K
    && decide (l.flow (thetas.getD i []) = row.getD i 0)

/-- Every non-slack column checks out. -/
def RowCertified (net : Network) (l : Line) (row : Row) (thetas : List Angles)
    (n slack : Nat) (K : Int) : Bool :=
  (List.range n).all (fun i => decide (i = slack) || columnCertified net l row thetas n slack K i)

/-- **What a certified row buys, column by column.** For every bus other than
the slack, the supplied angles have zero power flow residual for a unit
injection there, and the monitored branch's flow under them is exactly the row
entry. -/
theorem rowCertified_column {net : Network} {l : Line} {row : Row} {thetas : List Angles}
    {n slack : Nat} {K : Int} (h : RowCertified net l row thetas n slack K = true)
    {i : Nat} (hi : i < n) (hne : i ≠ slack) :
    Solves net (thetas.getD i []) (unitDispatch n i slack) K = true
      ∧ l.flow (thetas.getD i []) = row.getD i 0 := by
  simp only [RowCertified, List.all_eq_true] at h
  have hmem : i ∈ List.range n := List.mem_range.mpr hi
  have := h i hmem
  simp only [Bool.or_eq_true, decide_eq_true_eq, columnCertified, Bool.and_eq_true,
    decide_eq_true_eq] at this
  rcases this with hslack | hcol
  · exact absurd hslack hne
  · exact hcol

/-! ## Screening -/

/-- Combine two sensitivity rows: `a₁ + c · a₂`. Post-contingency rows are built
this way, with `c` the line outage distribution factor. -/
def combine (c : Int) : Row → Row → Row
  | [], _ => []
  | _, [] => []
  | x :: xs, y :: ys => (x + c * y) :: combine c xs ys

/-- **Superposition for sensitivity rows.** The flow under a combined row is the
combination of the flows, which is what makes an LODF-adjusted screen valid. -/
theorem dot_combine (c : Int) : ∀ (a₁ a₂ : Row) (p : Dispatch),
    a₁.length = a₂.length → a₁.length = p.length →
    dot (combine c a₁ a₂) p = dot a₁ p + c * dot a₂ p := by
  intro a₁
  induction a₁ with
  | nil => intro a₂ p h hp; cases a₂ <;> cases p <;> simp_all [combine, dot]
  | cons x xs ih =>
      intro a₂ p h hp
      cases a₂ with
      | nil => simp at h
      | cons y ys =>
        cases p with
        | nil => simp at hp
        | cons z zs =>
          simp only [List.length_cons, Nat.add_right_cancel_iff] at h hp
          simp only [combine, dot, ih ys zs h hp]
          grind

/-- Scale a sensitivity row. Needed because an LODF is rational: both rows get
cleared to a common denominator before they are combined. -/
def scaleRow (k : Int) : Row → Row
  | [] => []
  | x :: xs => k * x :: scaleRow k xs

theorem dot_scaleRow (k : Int) : ∀ (a : Row) (p : Dispatch),
    dot (scaleRow k a) p = k * dot a p := by
  intro a
  induction a with
  | nil => intro p; cases p <;> simp [scaleRow, dot]
  | cons x xs ih =>
      intro p
      cases p with
      | nil => simp [scaleRow, dot]
      | cons y ys => simp only [scaleRow, dot, ih ys]; grind

/-- **The post-contingency flow identity.** If the emitted row really is the
cleared combination `d · aℓ + n · ak`, then its dot product against any dispatch
is `d` times the monitored flow plus `n` times the outaged flow. Checking the
row equality is a finite list comparison; the identity it buys holds for every
dispatch. -/
theorem dot_postContingency {d n : Int} {aℓ ak rowPost : Row}
    (hrow : combine n (scaleRow d aℓ) ak = rowPost)
    (hlen : (scaleRow d aℓ).length = ak.length) :
    ∀ p : Dispatch, (scaleRow d aℓ).length = p.length →
      dot rowPost p = d * dot aℓ p + n * dot ak p := by
  intro p hp
  rw [← hrow, dot_combine n (scaleRow d aℓ) ak p hlen hp, dot_scaleRow]

/-- The screening test: the whole box stays inside `±limit`. -/
def screen (a : Row) (b : Box) (limit : Int) : Bool :=
  decide (upper a b ≤ limit) && decide (-limit ≤ lower a b)

/-- **Screening is sound.** Passing means every dispatch in the box keeps the
branch inside its rating, with no dispatch left unchecked. -/
theorem screen_sound {a : Row} {b : Box} {limit : Int} (h : screen a b limit = true)
    {p : Dispatch} (hp : Mem p b = true) :
    -limit ≤ dot a p ∧ dot a p ≤ limit := by
  simp only [screen, Bool.and_eq_true, decide_eq_true_eq] at h
  have h1 := dot_le_upper a p b hp
  have h2 := lower_le_dot a p b hp
  omega

/-- **Screening is complete on the high side.** A failure on the upper bound
comes with the dispatch that causes it. -/
theorem screen_complete_hi {a : Row} {b : Box} {limit : Int}
    (hlen : a.length = b.length) (hwf : Box.Wf b = true) (h : ¬ (upper a b ≤ limit)) :
    Mem (argUpper a b) b = true ∧ ¬ (dot a (argUpper a b) ≤ limit) := by
  refine ⟨argUpper_mem a b hlen hwf, ?_⟩
  rw [dot_argUpper a b hlen]
  exact h

/-- **Screening is complete on the low side.** -/
theorem screen_complete_lo {a : Row} {b : Box} {limit : Int}
    (hlen : a.length = b.length) (hwf : Box.Wf b = true) (h : ¬ (-limit ≤ lower a b)) :
    Mem (argLower a b) b = true ∧ ¬ (-limit ≤ dot a (argLower a b)) := by
  refine ⟨argLower_mem a b hlen hwf, ?_⟩
  rw [dot_argLower a b hlen]
  exact h

/-- The screening margin: how much headroom the worst dispatch leaves. Negative
means the branch is overloaded somewhere in the box. -/
def margin (a : Row) (b : Box) (limit : Int) : Int :=
  min (limit - upper a b) (lower a b + limit)

theorem screen_iff_margin_nonneg (a : Row) (b : Box) (limit : Int) :
    screen a b limit = true ↔ 0 ≤ margin a b limit := by
  simp only [screen, Bool.and_eq_true, decide_eq_true_eq, margin, Int.le_min]
  omega

end GridCert
