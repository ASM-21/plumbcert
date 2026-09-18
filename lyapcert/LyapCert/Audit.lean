/-
# LyapCert.Audit

The CI gate. Each headline result is pinned to its exact axiom footprint, so the
build breaks if any of them ever comes to depend on `sorryAx`.
-/
import LyapCert
import LyapCert.Examples

set_option autoImplicit false

namespace LyapCert
namespace Audit

/-- info: 'LyapCert.mul_self_nonneg' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms LyapCert.mul_self_nonneg

/-- info: 'LyapCert.envelope' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms LyapCert.envelope

/-- info: 'LyapCert.nonincreasing' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms LyapCert.nonincreasing

/-- info: 'LyapCert.sublevel_invariant' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms LyapCert.sublevel_invariant

/-- info: 'LyapCert.settles' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms LyapCert.settles

/-- info: 'LyapCert.Quad.eval_compose' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms LyapCert.Quad.eval_compose

/-- info: 'LyapCert.Quad.eval_scaleVec' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms LyapCert.Quad.eval_scaleVec

/-- info: 'LyapCert.SOS.eval_nonneg' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms LyapCert.SOS.eval_nonneg

/-- info: 'LyapCert.Cert.V_nonneg' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms LyapCert.Cert.V_nonneg

/-- info: 'LyapCert.Cert.decay' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms LyapCert.Cert.decay

/-- info: 'LyapCert.Cert.envelope' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms LyapCert.Cert.envelope

/-- info: 'LyapCert.Cert.nonincreasing' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms LyapCert.Cert.nonincreasing

/-- info: 'LyapCert.Cert.sublevel_invariant' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms LyapCert.Cert.sublevel_invariant

/-- info: 'LyapCert.Cert.settles' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms LyapCert.Cert.settles

/-- info: 'LyapCert.Examples.agc_valid' does not depend on any axioms -/
#guard_msgs in
#print axioms LyapCert.Examples.agc_valid

/-- info: 'LyapCert.Examples.agc_envelope' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms LyapCert.Examples.agc_envelope

/-- info: 'LyapCert.Examples.losslessTank_invariant' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms LyapCert.Examples.losslessTank_invariant

/-- info: 'LyapCert.Examples.losslessTank_settles' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms LyapCert.Examples.losslessTank_settles

/-- info: 'LyapCert.Examples.deadbeatPipeline_settles' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms LyapCert.Examples.deadbeatPipeline_settles

end Audit
end LyapCert
