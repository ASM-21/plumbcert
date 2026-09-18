/-
# DimCert.Audit

The CI gate. Each headline result is pinned to its exact axiom footprint, so the
build breaks if any of them ever comes to depend on `sorryAx`.
-/
import DimCert

set_option autoImplicit false

namespace DimCert
namespace Audit

/-- info: 'DimCert.Dimension.sqrt?_sq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms DimCert.Dimension.sqrt?_sq

/-- info: 'DimCert.Dimension.decadeShift_mul' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms DimCert.Dimension.decadeShift_mul

/-- info: 'DimCert.Dimension.decadeShift_div' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms DimCert.Dimension.decadeShift_div

/-- info: 'DimCert.Expr.scale_eq_of_infer' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms DimCert.Expr.scale_eq_of_infer

/-- info: 'DimCert.Expr.scale_eq_zero_of_dimensionless' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms DimCert.Expr.scale_eq_zero_of_dimensionless

/-- info: 'DimCert.Equation.scale_agree' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms DimCert.Equation.scale_agree

/-- info: 'DimCert.Equation.separator_detects' depends on axioms: [propext] -/
#guard_msgs in
#print axioms DimCert.Equation.separator_detects

/-- info: 'DimCert.Units.surge_impedance' does not depend on any axioms -/
#guard_msgs in
#print axioms DimCert.Units.surge_impedance

/-- info: 'DimCert.Units.base_impedance' does not depend on any axioms -/
#guard_msgs in
#print axioms DimCert.Units.base_impedance

/-- info: 'DimCert.Formulas.baseImpedance_checks' does not depend on any axioms -/
#guard_msgs in
#print axioms DimCert.Formulas.baseImpedance_checks

/-- info: 'DimCert.Formulas.surgeImpedance_checks' does not depend on any axioms -/
#guard_msgs in
#print axioms DimCert.Formulas.surgeImpedance_checks

/-- info: 'DimCert.Formulas.skinDepth_checks' does not depend on any axioms -/
#guard_msgs in
#print axioms DimCert.Formulas.skinDepth_checks

/-- info: 'DimCert.Formulas.reynolds_dimensionless' does not depend on any axioms -/
#guard_msgs in
#print axioms DimCert.Formulas.reynolds_dimensionless

/-- info: 'DimCert.Formulas.perUnit_is_unit_invariant' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms DimCert.Formulas.perUnit_is_unit_invariant

/-- info: 'DimCert.Formulas.badPower_rejected' does not depend on any axioms -/
#guard_msgs in
#print axioms DimCert.Formulas.badPower_rejected

/-- info: 'DimCert.Formulas.badBaseImpedance_rejected' does not depend on any axioms -/
#guard_msgs in
#print axioms DimCert.Formulas.badBaseImpedance_rejected

/-- info: 'DimCert.Formulas.badSum_has_no_dimension' does not depend on any axioms -/
#guard_msgs in
#print axioms DimCert.Formulas.badSum_has_no_dimension

/-- info: 'DimCert.Formulas.badSqrt_has_no_dimension' does not depend on any axioms -/
#guard_msgs in
#print axioms DimCert.Formulas.badSqrt_has_no_dimension

/-- info: 'DimCert.Formulas.apparentPowerSum_checks' does not depend on any axioms -/
#guard_msgs in
#print axioms DimCert.Formulas.apparentPowerSum_checks

end Audit
end DimCert
