/-
# TolStack.Audit

The CI gate. Every headline result is pinned to its exact axiom footprint with
`#guard_msgs`, so the build breaks if any of them ever comes to depend on
`sorryAx`. `propext`, `Classical.choice` and `Quot.sound` are the three standard
Lean axioms; anything else appearing here is a regression.

This is the mechanical check. It says the proofs are complete. It says nothing
about whether the definitions in `TolStack.Basic` faithfully model the drawing
in front of you, which is the part that still needs a human.
-/
import TolStack

namespace TolStack
namespace Audit

/-- info: 'TolStack.Stack.eval_mem_worstCase' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms TolStack.Stack.eval_mem_worstCase

/-- info: 'TolStack.Stack.wcLo_attained' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms TolStack.Stack.wcLo_attained

/-- info: 'TolStack.Stack.wcHi_attained' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms TolStack.Stack.wcHi_attained

/-- info: 'TolStack.Stack.fitsWithin_sound' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms TolStack.Stack.fitsWithin_sound

/-- info: 'TolStack.Stack.fitsWithin_complete' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms TolStack.Stack.fitsWithin_complete

/-- info: 'TolStack.Stack.noInterference_sound' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms TolStack.Stack.noInterference_sound

/-- info: 'TolStack.Stack.noInterference_complete' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms TolStack.Stack.noInterference_complete

/-- info: 'TolStack.Stack.wcHi_sub_wcLo' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms TolStack.Stack.wcHi_sub_wcLo

/-- info: 'TolStack.Stack.rssSq_le_wcWidth_sq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms TolStack.Stack.rssSq_le_wcWidth_sq

/-- info: 'TolStack.Stack.fitsWithin_imp_rssFitsWithin' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms TolStack.Stack.fitsWithin_imp_rssFitsWithin

/-- info: 'TolStack.Stack.rss_check_unsound' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms TolStack.Stack.rss_check_unsound

/-- info: 'TolStack.Stack.fitsWithin_iff_slack_nonneg' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms TolStack.Stack.fitsWithin_iff_slack_nonneg

/-- info: 'TolStack.Stack.fitsWithin_budget' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms TolStack.Stack.fitsWithin_budget

/-- info: 'TolStack.Stack.refines_worstCase' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms TolStack.Stack.refines_worstCase

/-- info: 'TolStack.Stack.refines_fitsWithin' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms TolStack.Stack.refines_fitsWithin

/-- info: 'TolStack.Stack.nominal_mem_worstCase' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms TolStack.Stack.nominal_mem_worstCase

/-- info: 'TolStack.Examples.axialGap_in_window' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms TolStack.Examples.axialGap_in_window

/-- info: 'TolStack.Examples.axialGap_tight_window_fails' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms TolStack.Examples.axialGap_tight_window_fails

/-- info: 'TolStack.Examples.axialGap_worst_build' depends on axioms: [propext] -/
#guard_msgs in
#print axioms TolStack.Examples.axialGap_worst_build

end Audit
end TolStack
