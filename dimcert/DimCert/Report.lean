/-
# DimCert.Report

Rendering. The same functions the theorems are stated about produce the printed
output, so the report cannot disagree with what was proved.
-/
import DimCert.Formulas

set_option autoImplicit false

namespace DimCert

open Dimension

/-- SI base symbol with an exponent, omitting exponent 1 and empty factors. -/
private def factor (sym : String) (n : Int) : String :=
  if n == 0 then "" else if n == 1 then sym else s!"{sym}^{n}"

/-- Render a dimension in SI base symbols, e.g. `kg m^2 s^-3 A^-1`. -/
def Dimension.render (d : Dimension) : String :=
  let parts := [factor "kg" d.mass, factor "m" d.length, factor "s" d.time,
                factor "A" d.current, factor "K" d.temperature,
                factor "mol" d.amount, factor "cd" d.luminous].filter (· != "")
  if parts.isEmpty then "1 (dimensionless)" else String.intercalate " " parts

def renderInferred : Option Dimension → String
  | some d => d.render
  | none => "INCONSISTENT"

/-- One line per formula: name, both sides' dimensions, verdict. -/
def Equation.report (q : Equation) : String :=
  let l := renderInferred q.lhs.infer
  let r := renderInferred q.rhs.infer
  let verdict := if q.checks then "ok  " else "FAIL"
  s!"{verdict}  {q.name}\n        lhs: {l}\n        rhs: {r}"

/-- The full formula library, checked and rendered. -/
def library : List Equation :=
  open Formulas in
  [ohmsLaw, realPower, powerResistive, powerVoltage, energyFromPower, faultCurrent,
   voltageDrop, conductorResistance, surgeImpedance, lineCharging, skinDepth,
   transformerRatio, baseImpedance, baseCurrent, sensibleHeat, conduction,
   efficiency, reynolds, apparentPower, apparentPowerSum,
   badPower, badBaseImpedance, badSum, badConduction]

def libraryReport : String :=
  String.intercalate "\n" (library.map Equation.report)

end DimCert
