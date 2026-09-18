"""SI base and derived dimensions, mirroring DimCert/Units.lean.

Note that watt, volt-ampere and var are the same dimension. Dimensional analysis
cannot separate real, apparent and reactive power.
"""

from __future__ import annotations

from .dimension import Dimension

dimensionless = Dimension()
metre = Dimension(length=1)
kilogram = Dimension(mass=1)
second = Dimension(time=1)
ampere = Dimension(current=1)
kelvin = Dimension(temperature=1)
mole = Dimension(amount=1)
candela = Dimension(luminous=1)

hertz = Dimension(time=-1)
newton = Dimension(mass=1, length=1, time=-2)
pascal = Dimension(mass=1, length=-1, time=-2)
joule = Dimension(mass=1, length=2, time=-2)
watt = Dimension(mass=1, length=2, time=-3)
coulomb = Dimension(current=1, time=1)
volt = Dimension(mass=1, length=2, time=-3, current=-1)
farad = Dimension(mass=-1, length=-2, time=4, current=2)
ohm = Dimension(mass=1, length=2, time=-3, current=-2)
siemens = Dimension(mass=-1, length=-2, time=3, current=2)
weber = Dimension(mass=1, length=2, time=-2, current=-1)
tesla = Dimension(mass=1, time=-2, current=-1)
henry = Dimension(mass=1, length=2, time=-2, current=-2)

voltAmpere = watt
var = watt

velocity = Dimension(length=1, time=-1)
acceleration = Dimension(length=1, time=-2)
area = Dimension(length=2)
volume = Dimension(length=3)
density = Dimension(mass=1, length=-3)
viscosity = Dimension(mass=1, length=-1, time=-1)
specificHeat = Dimension(length=2, time=-2, temperature=-1)
thermalConductivity = Dimension(mass=1, length=1, time=-3, temperature=-1)
resistivity = Dimension(mass=1, length=3, time=-3, current=-2)
permeability = Dimension(mass=1, length=1, time=-2, current=-2)

BY_NAME = {
    name: value
    for name, value in list(globals().items())
    if isinstance(value, Dimension)
}
