/-
# DimCert.Units

SI base and derived dimensions, and the standard identities between them, each
closed by kernel computation.

A note that matters for power work: watt, volt-ampere and var all have the same
dimension. Dimensional analysis cannot tell real power from apparent or reactive
power, and nothing in this library claims otherwise (`watt_eq_voltAmpere` makes
the collision explicit rather than hiding it). Dimensional consistency is a
necessary condition on a formula, never a sufficient one.
-/
import DimCert.Dimension

set_option autoImplicit false

namespace DimCert
namespace Units

open Dimension

/-! ## Base dimensions -/

def dimensionless : Dimension := Dimension.one
def metre   : Dimension := { length := 1 }
def kilogram: Dimension := { mass := 1 }
def second  : Dimension := { time := 1 }
def ampere  : Dimension := { current := 1 }
def kelvin  : Dimension := { temperature := 1 }
def mole    : Dimension := { amount := 1 }
def candela : Dimension := { luminous := 1 }

/-! ## Derived dimensions -/

def hertz   : Dimension := { time := -1 }
def newton  : Dimension := { mass := 1, length := 1, time := -2 }
def pascal  : Dimension := { mass := 1, length := -1, time := -2 }
def joule   : Dimension := { mass := 1, length := 2, time := -2 }
def watt    : Dimension := { mass := 1, length := 2, time := -3 }
def coulomb : Dimension := { current := 1, time := 1 }
def volt    : Dimension := { mass := 1, length := 2, time := -3, current := -1 }
def farad   : Dimension := { mass := -1, length := -2, time := 4, current := 2 }
def ohm     : Dimension := { mass := 1, length := 2, time := -3, current := -2 }
def siemens : Dimension := { mass := -1, length := -2, time := 3, current := 2 }
def weber   : Dimension := { mass := 1, length := 2, time := -2, current := -1 }
def tesla   : Dimension := { mass := 1, time := -2, current := -1 }
def henry   : Dimension := { mass := 1, length := 2, time := -2, current := -2 }

/-- Volt-ampere. Dimensionally identical to the watt; see the module note. -/
def voltAmpere : Dimension := watt
/-- Volt-ampere reactive. Also dimensionally identical to the watt. -/
def var : Dimension := watt

def velocity     : Dimension := { length := 1, time := -1 }
def acceleration : Dimension := { length := 1, time := -2 }
def area         : Dimension := { length := 2 }
def volume       : Dimension := { length := 3 }
def density      : Dimension := { mass := 1, length := -3 }
def viscosity    : Dimension := { mass := 1, length := -1, time := -1 }
def specificHeat : Dimension := { length := 2, time := -2, temperature := -1 }
def thermalConductivity : Dimension := { mass := 1, length := 1, time := -3, temperature := -1 }
def resistivity  : Dimension := { mass := 1, length := 3, time := -3, current := -2 }
def permeability : Dimension := { mass := 1, length := 1, time := -2, current := -2 }

/-! ## Identities between derived dimensions -/

theorem newton_eq : newton = kilogram * metre / second ^ (2 : Int) := by decide
theorem joule_eq : joule = newton * metre := by decide
theorem watt_eq : watt = joule / second := by decide
theorem pascal_eq : pascal = newton / area := by decide
theorem coulomb_eq : coulomb = ampere * second := by decide
theorem volt_eq : volt = watt / ampere := by decide
theorem ohm_eq : ohm = volt / ampere := by decide
theorem watt_eq_volt_ampere : watt = volt * ampere := by decide
theorem farad_eq : farad = coulomb / volt := by decide
theorem henry_eq : henry = weber / ampere := by decide
theorem weber_eq : weber = volt * second := by decide
theorem tesla_eq : tesla = weber / area := by decide
theorem siemens_eq : siemens = ohm⁻¹ := by decide
theorem hertz_eq : hertz = dimensionless / second := by decide

/-- Real, apparent and reactive power are dimensionally indistinguishable. -/
theorem watt_eq_voltAmpere : watt = voltAmpere ∧ watt = var := by decide

/-- Catalytic activity, which is what makes `mole` earn its place. -/
def katal : Dimension := { amount := 1, time := -1 }
/-- Luminous flux. Steradian is dimensionless, so lumen and candela coincide. -/
def lumen : Dimension := candela
/-- Illuminance. -/
def lux : Dimension := { luminous := 1, length := -2 }

theorem katal_eq : katal = mole / second := by decide
theorem lumen_eq : lumen = candela := by decide
theorem lux_eq : lux = lumen / area := by decide
theorem density_eq : density = kilogram / volume := by decide
theorem acceleration_eq : acceleration = velocity / second := by decide
theorem velocity_eq : velocity = metre / second := by decide

/-! ## Identities that need a square root -/

/-- Surge impedance: `Z = sqrt(L/C)` really is an impedance. -/
theorem surge_impedance : sqrt? (henry / farad) = some ohm := by decide

/-- Skin depth `sqrt(2 ρ / (ω μ))` really is a length. -/
theorem skin_depth :
    sqrt? (resistivity / ((dimensionless / second) * permeability)) = some metre := by decide

/-- Natural frequency `sqrt(k/m)` really is a reciprocal time. -/
theorem natural_frequency :
    sqrt? ((newton / metre) / kilogram) = some hertz := by decide

/-! ## Per-unit quantities are dimensionless -/

/-- Base impedance `Z_base = V_base² / S_base` is an impedance. -/
theorem base_impedance : volt ^ (2 : Int) / voltAmpere = ohm := by decide

/-- A per-unit impedance is dimensionless, which is the whole point of the
per-unit system: it survives any change of unit. -/
theorem per_unit_dimensionless : ohm / (volt ^ (2 : Int) / voltAmpere) = dimensionless := by decide

/-- Base current `I_base = S_base / V_base`. -/
theorem base_current : voltAmpere / volt = ampere := by decide

end Units
end DimCert
