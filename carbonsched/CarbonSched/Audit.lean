/-
# CarbonSched.Audit

The CI gate. Each headline result is pinned to its exact axiom footprint, so the
build breaks if any of them ever comes to depend on `sorryAx`.
-/
import CarbonSched
import CarbonSched.Examples

set_option autoImplicit false

namespace CarbonSched
namespace Audit

/-- info: 'CarbonSched.cost_diff_le' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms CarbonSched.cost_diff_le

/-- info: 'CarbonSched.optimal' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms CarbonSched.optimal

/-- info: 'CarbonSched.optimal_le_longer' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms CarbonSched.optimal_le_longer

/-- info: 'CarbonSched.certified_optimal' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms CarbonSched.certified_optimal

/-- info: 'CarbonSched.cost_le_of_selLe' depends on axioms: [propext] -/
#guard_msgs in
#print axioms CarbonSched.cost_le_of_selLe

/-- info: 'CarbonSched.cost_ge_of_selGe' depends on axioms: [propext] -/
#guard_msgs in
#print axioms CarbonSched.cost_ge_of_selGe

/-- info: 'CarbonSched.online_ratio' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms CarbonSched.online_ratio

/-- info: 'CarbonSched.online_ratio_tight' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms CarbonSched.online_ratio_tight

/-- info: 'CarbonSched.savings_certified' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms CarbonSched.savings_certified

/-- info: 'CarbonSched.tight_offline_certified' depends on axioms: [propext] -/
#guard_msgs in
#print axioms CarbonSched.tight_offline_certified

/-- info: 'CarbonSched.Examples.industrialBatch_certified' does not depend on any axioms -/
#guard_msgs in
#print axioms CarbonSched.Examples.industrialBatch_certified

/-- info: 'CarbonSched.Examples.industrialBatch_optimal' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms CarbonSched.Examples.industrialBatch_optimal

/-- info: 'CarbonSched.Examples.industrialBatch_beatsRunNow' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms CarbonSched.Examples.industrialBatch_beatsRunNow

/-- info: 'CarbonSched.Examples.industrialBatch_beatsNightShift' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms CarbonSched.Examples.industrialBatch_beatsNightShift

/-- info: 'CarbonSched.Examples.fleetCharging_optimal' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms CarbonSched.Examples.fleetCharging_optimal

/-- info: 'CarbonSched.Examples.flatProfile_optimal' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms CarbonSched.Examples.flatProfile_optimal

end Audit
end CarbonSched
