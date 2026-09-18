/-
# GridCert.Audit

The CI gate. Each headline result is pinned to its exact axiom footprint, so the
build breaks if any of them ever comes to depend on `sorryAx`.
-/
import GridCert
import GridCert.Examples

set_option autoImplicit false

namespace GridCert
namespace Audit

/-- info: 'GridCert.dot_le_upper' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.dot_le_upper

/-- info: 'GridCert.lower_le_dot' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.lower_le_dot

/-- info: 'GridCert.dot_argUpper' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.dot_argUpper

/-- info: 'GridCert.dot_argLower' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.dot_argLower

/-- info: 'GridCert.argUpper_mem' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.argUpper_mem

/-- info: 'GridCert.argLower_mem' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.argLower_mem

/-- info: 'GridCert.screen_sound' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.screen_sound

/-- info: 'GridCert.screen_complete_hi' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.screen_complete_hi

/-- info: 'GridCert.screen_complete_lo' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.screen_complete_lo

/-- info: 'GridCert.screen_iff_margin_nonneg' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.screen_iff_margin_nonneg

/-- info: 'GridCert.flow_addA' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.flow_addA

/-- info: 'GridCert.flow_smulA' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.flow_smulA

/-- info: 'GridCert.injAt_addA' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.injAt_addA

/-- info: 'GridCert.injAt_smulA' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.injAt_smulA

/-- info: 'GridCert.dot_combine' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.dot_combine

/-- info: 'GridCert.dot_postContingency' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.dot_postContingency

/-- info: 'GridCert.solves_injAt' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.solves_injAt

/-- info: 'GridCert.rowCertified_column' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.rowCertified_column

/-- info: 'GridCert.Examples.aEBaseCaseRowCertified' does not depend on any axioms -/
#guard_msgs in
#print axioms GridCert.Examples.aEBaseCaseRowCertified

/-- info: 'GridCert.Examples.aEBaseCaseSafe' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.Examples.aEBaseCaseSafe

/-- info: 'GridCert.Examples.aEWithDEOutSafe' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.Examples.aEWithDEOutSafe

/-- info: 'GridCert.Examples.aDWithABOutRowCertified' does not depend on any axioms -/
#guard_msgs in
#print axioms GridCert.Examples.aDWithABOutRowCertified

/-- info: 'GridCert.Examples.aDWithABOutViolates' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.Examples.aDWithABOutViolates

/-- info: 'GridCert.Examples.dEBaseCaseViolates' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms GridCert.Examples.dEBaseCaseViolates

end Audit
end GridCert
