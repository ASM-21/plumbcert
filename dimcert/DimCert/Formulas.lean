/-
# DimCert.Formulas

A library of engineering formulas, each checked by kernel computation.

The interesting half of this file is the bottom. `badPower`, `badBaseImpedance`
and friends are formulas that fail the check, proved to fail, because a checker
nobody has watched reject anything is not evidence of much. And `apparentPowerSum`
is the honest limit: adding watts to vars passes every dimensional check there
is and is still wrong physics.
-/
import DimCert.Expr
import DimCert.Units

set_option autoImplicit false

namespace DimCert
namespace Formulas

open Dimension Expr Units

/-! ## Symbols -/

def V : Expr := .sym "V" volt
def I : Expr := .sym "I" ampere
def R : Expr := .sym "R" ohm
def X : Expr := .sym "X" ohm
def Z : Expr := .sym "Z" ohm
def P : Expr := .sym "P" watt
def Q : Expr := .sym "Q" var
def S : Expr := .sym "S" voltAmpere
def E : Expr := .sym "E" joule
def t : Expr := .sym "t" second
def L : Expr := .sym "L" henry
def C : Expr := .sym "C" farad
def ω : Expr := .sym "ω" hertz
def ρ : Expr := .sym "ρ" resistivity
def μ : Expr := .sym "μ" permeability
def len : Expr := .sym "ℓ" metre
def A : Expr := .sym "A" area
def Vbase : Expr := .sym "V_base" volt
def Sbase : Expr := .sym "S_base" voltAmpere
def Zbase : Expr := .sym "Z_base" ohm
def N₁ : Expr := .sym "N₁" dimensionless
def N₂ : Expr := .sym "N₂" dimensionless
def V₁ : Expr := .sym "V₁" volt
def V₂ : Expr := .sym "V₂" volt

def m : Expr := .sym "m" kilogram
def cp : Expr := .sym "c_p" specificHeat
def ΔT : Expr := .sym "ΔT" kelvin
def Qheat : Expr := .sym "Q" joule
def k : Expr := .sym "k" thermalConductivity
def qflux : Expr := .sym "q" watt
def W : Expr := .sym "W" joule
def dens : Expr := .sym "ρ" density
def vel : Expr := .sym "v" velocity
def D : Expr := .sym "D" metre
def visc : Expr := .sym "μ" viscosity
def Re : Expr := .sym "Re" dimensionless
def two : Expr := .const

/-! ## Power systems -/

def ohmsLaw : Equation := ⟨"Ohm's law: V = I R", V, .mul I R⟩
def realPower : Equation := ⟨"real power: P = V I", P, .mul V I⟩
def powerResistive : Equation := ⟨"P = I² R", P, .mul (.pow I 2) R⟩
def powerVoltage : Equation := ⟨"P = V² / R", P, .div (.pow V 2) R⟩
def energyFromPower : Equation := ⟨"E = P t", E, .mul P t⟩
def faultCurrent : Equation := ⟨"I = V / Z", I, .div V Z⟩
def voltageDrop : Equation := ⟨"ΔV = I (R + X)", V, .mul I (.add R X)⟩
def conductorResistance : Equation := ⟨"R = ρ ℓ / A", R, .div (.mul ρ len) A⟩
def surgeImpedance : Equation := ⟨"Z_c = √(L/C)", Z, .sqrt (.div L C)⟩
def lineCharging : Equation := ⟨"Q = V² ω C", Q, .mul (.mul (.pow V 2) ω) C⟩
def skinDepth : Equation := ⟨"δ = √(2ρ / ω μ)", len, .sqrt (.div (.mul two ρ) (.mul ω μ))⟩
def transformerRatio : Equation := ⟨"V₁/V₂ = N₁/N₂", .div V₁ V₂, .div N₁ N₂⟩
def baseImpedance : Equation := ⟨"Z_base = V_base² / S_base", Zbase, .div (.pow Vbase 2) Sbase⟩
def baseCurrent : Equation := ⟨"I_base = S_base / V_base", I, .div Sbase Vbase⟩
def perUnitImpedance : Equation := ⟨"Z_pu = Z / Z_base", .div Z Zbase, .const⟩

theorem ohmsLaw_checks : ohmsLaw.checks = true := by decide
theorem realPower_checks : realPower.checks = true := by decide
theorem powerResistive_checks : powerResistive.checks = true := by decide
theorem powerVoltage_checks : powerVoltage.checks = true := by decide
theorem energyFromPower_checks : energyFromPower.checks = true := by decide
theorem faultCurrent_checks : faultCurrent.checks = true := by decide
theorem voltageDrop_checks : voltageDrop.checks = true := by decide
theorem conductorResistance_checks : conductorResistance.checks = true := by decide
theorem surgeImpedance_checks : surgeImpedance.checks = true := by decide
theorem lineCharging_checks : lineCharging.checks = true := by decide
theorem skinDepth_checks : skinDepth.checks = true := by decide
theorem transformerRatio_checks : transformerRatio.checks = true := by decide
theorem baseImpedance_checks : baseImpedance.checks = true := by decide
theorem baseCurrent_checks : baseCurrent.checks = true := by decide
theorem perUnitImpedance_checks : perUnitImpedance.checks = true := by decide

/-- A per-unit impedance is dimensionless, so its numeric value is the same in
every unit system. This is the property the per-unit system exists to provide,
and here it is as a theorem rather than a convention. -/
theorem perUnit_is_unit_invariant (r : Rescale) :
    (Expr.div Z Zbase).scale r = 0 :=
  Expr.scale_eq_zero_of_dimensionless (by decide) r

/-! ## Heat transfer and thermodynamics -/

def sensibleHeat : Equation := ⟨"Q = m c_p ΔT", Qheat, .mul (.mul m cp) ΔT⟩
def conduction : Equation := ⟨"q = k A ΔT / ℓ", qflux, .div (.mul (.mul k A) ΔT) len⟩
def efficiency : Equation := ⟨"η = W / Q", .div W Qheat, .const⟩
def reynolds : Equation := ⟨"Re = ρ v D / μ", Re, .div (.mul (.mul dens vel) D) visc⟩

theorem sensibleHeat_checks : sensibleHeat.checks = true := by decide
theorem conduction_checks : conduction.checks = true := by decide
theorem efficiency_checks : efficiency.checks = true := by decide
theorem reynolds_checks : reynolds.checks = true := by decide

/-- The Reynolds number is dimensionless, which is why it can be compared
against a critical value at all. -/
theorem reynolds_dimensionless :
    (Expr.div (.mul (.mul dens vel) D) visc).infer = some Dimension.one := by decide

/-! ## Formulas the checker rejects -/

def badPower : Equation := ⟨"WRONG: P = V I²", P, .mul V (.pow I 2)⟩
def badBaseImpedance : Equation := ⟨"WRONG: Z_base = V_base / S_base²", Zbase, .div Vbase (.pow Sbase 2)⟩
def badSum : Equation := ⟨"WRONG: P + V", .add P V, P⟩
def badSqrt : Equation := ⟨"WRONG: √V", .sqrt V, V⟩
def badConduction : Equation := ⟨"WRONG: q = k A ΔT ℓ", qflux, .mul (.mul (.mul k A) ΔT) len⟩

theorem badPower_rejected : badPower.checks = false := by decide
theorem badBaseImpedance_rejected : badBaseImpedance.checks = false := by decide
theorem badSum_rejected : badSum.checks = false := by decide
theorem badConduction_rejected : badConduction.checks = false := by decide
theorem badSqrt_rejected : badSqrt.checks = false := by decide

/-- The square root of a voltage is not a dimension in this system, so the
expression has no dimension at all rather than a wrong one. -/
theorem badSqrt_has_no_dimension : (Expr.sqrt V).infer = none := by decide

/-- Adding a power to a voltage fails inference outright. -/
theorem badSum_has_no_dimension : (Expr.add P V).infer = none := by decide

/-! ## The limit of the method -/

/-- Watts plus vars passes every dimensional check, and is still wrong: apparent
power is the quadrature sum, not the arithmetic one. Dimensional consistency is
a necessary condition on a formula, never a sufficient one, and this project
does not pretend otherwise. -/
def apparentPowerSum : Equation := ⟨"WRONG PHYSICS, RIGHT DIMENSIONS: S = P + Q", S, .add P Q⟩

theorem apparentPowerSum_checks : apparentPowerSum.checks = true := by decide

/-- The correct relation, which also checks. The checker cannot tell these two
apart; only a person can. -/
def apparentPower : Equation := ⟨"S = √(P² + Q²)", S, .sqrt (.add (.pow P 2) (.pow Q 2))⟩

theorem apparentPower_checks : apparentPower.checks = true := by decide

end Formulas
end DimCert
