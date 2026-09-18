"""The same formula library as DimCert/Formulas.lean, in the same order."""

from __future__ import annotations

from . import units as u
from .expr import Const, Equation, Pow, Sqrt, Sym, add, div, mul

V = Sym("V", u.volt)
I = Sym("I", u.ampere)
R = Sym("R", u.ohm)
X = Sym("X", u.ohm)
Z = Sym("Z", u.ohm)
P = Sym("P", u.watt)
Q = Sym("Q", u.var)
S = Sym("S", u.voltAmpere)
E = Sym("E", u.joule)
t = Sym("t", u.second)
L = Sym("L", u.henry)
C = Sym("C", u.farad)
omega = Sym("ω", u.hertz)
rho = Sym("ρ", u.resistivity)
mu = Sym("μ", u.permeability)
length = Sym("ℓ", u.metre)
A = Sym("A", u.area)
Vbase = Sym("V_base", u.volt)
Sbase = Sym("S_base", u.voltAmpere)
Zbase = Sym("Z_base", u.ohm)
N1 = Sym("N₁", u.dimensionless)
N2 = Sym("N₂", u.dimensionless)
V1 = Sym("V₁", u.volt)
V2 = Sym("V₂", u.volt)
m = Sym("m", u.kilogram)
cp = Sym("c_p", u.specificHeat)
dT = Sym("ΔT", u.kelvin)
Qheat = Sym("Q", u.joule)
k = Sym("k", u.thermalConductivity)
qflux = Sym("q", u.watt)
W = Sym("W", u.joule)
dens = Sym("ρ", u.density)
vel = Sym("v", u.velocity)
D = Sym("D", u.metre)
visc = Sym("μ", u.viscosity)
Re = Sym("Re", u.dimensionless)
two = Const()

LIBRARY = [
    Equation("Ohm's law: V = I R", V, mul(I, R)),
    Equation("real power: P = V I", P, mul(V, I)),
    Equation("P = I² R", P, mul(Pow(I, 2), R)),
    Equation("P = V² / R", P, div(Pow(V, 2), R)),
    Equation("E = P t", E, mul(P, t)),
    Equation("I = V / Z", I, div(V, Z)),
    Equation("ΔV = I (R + X)", V, mul(I, add(R, X))),
    Equation("R = ρ ℓ / A", R, div(mul(rho, length), A)),
    Equation("Z_c = √(L/C)", Z, Sqrt(div(L, C))),
    Equation("Q = V² ω C", Q, mul(mul(Pow(V, 2), omega), C)),
    Equation("δ = √(2ρ / ω μ)", length, Sqrt(div(mul(two, rho), mul(omega, mu)))),
    Equation("V₁/V₂ = N₁/N₂", div(V1, V2), div(N1, N2)),
    Equation("Z_base = V_base² / S_base", Zbase, div(Pow(Vbase, 2), Sbase)),
    Equation("I_base = S_base / V_base", I, div(Sbase, Vbase)),
    Equation("Q = m c_p ΔT", Qheat, mul(mul(m, cp), dT)),
    Equation("q = k A ΔT / ℓ", qflux, div(mul(mul(k, A), dT), length)),
    Equation("η = W / Q", div(W, Qheat), Const()),
    Equation("Re = ρ v D / μ", Re, div(mul(mul(dens, vel), D), visc)),
    Equation("S = √(P² + Q²)", S, Sqrt(add(Pow(P, 2), Pow(Q, 2)))),
    Equation("WRONG PHYSICS, RIGHT DIMENSIONS: S = P + Q", S, add(P, Q)),
    Equation("WRONG: P = V I²", P, mul(V, Pow(I, 2))),
    Equation("WRONG: Z_base = V_base / S_base²", Zbase, div(Vbase, Pow(Sbase, 2))),
    Equation("WRONG: P + V", add(P, V), P),
    Equation("WRONG: q = k A ΔT ℓ", qflux, mul(mul(mul(k, A), dT), length)),
]


def library_report() -> str:
    return "\n".join(q.report() for q in LIBRARY)
