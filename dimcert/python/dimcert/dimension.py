"""Physical dimensions as integer exponent vectors, mirroring DimCert/Dimension.lean."""

from __future__ import annotations

from dataclasses import dataclass, replace

BASES = ("mass", "length", "time", "current", "temperature", "amount", "luminous")
SYMBOLS = {
    "mass": "kg",
    "length": "m",
    "time": "s",
    "current": "A",
    "temperature": "K",
    "amount": "mol",
    "luminous": "cd",
}


@dataclass(frozen=True)
class Dimension:
    mass: int = 0
    length: int = 0
    time: int = 0
    current: int = 0
    temperature: int = 0
    amount: int = 0
    luminous: int = 0

    def __mul__(self, other: "Dimension") -> "Dimension":
        return Dimension(*(getattr(self, b) + getattr(other, b) for b in BASES))

    def __truediv__(self, other: "Dimension") -> "Dimension":
        return Dimension(*(getattr(self, b) - getattr(other, b) for b in BASES))

    def inv(self) -> "Dimension":
        return Dimension(*(-getattr(self, b) for b in BASES))

    def __pow__(self, n: int) -> "Dimension":
        return Dimension(*(n * getattr(self, b) for b in BASES))

    @property
    def is_square(self) -> bool:
        return all(getattr(self, b) % 2 == 0 for b in BASES)

    def sqrt(self) -> "Dimension | None":
        """Defined exactly when every exponent is even, as in Lean's `sqrt?`."""
        if not self.is_square:
            return None
        return Dimension(*(getattr(self, b) // 2 for b in BASES))

    def decade_shift(self, r: "Rescale") -> int:
        """Decades the numeric value moves when the base units are rescaled."""
        return sum(getattr(self, b) * getattr(r, b) for b in BASES)

    def render(self) -> str:
        parts = []
        for b in ("mass", "length", "time", "current", "temperature", "amount", "luminous"):
            n = getattr(self, b)
            if n == 0:
                continue
            parts.append(SYMBOLS[b] if n == 1 else f"{SYMBOLS[b]}^{n}")
        return " ".join(parts) if parts else "1 (dimensionless)"

    def to_lean(self) -> str:
        fields = [f"{b} := {getattr(self, b)}" for b in BASES if getattr(self, b) != 0]
        return "{ " + ", ".join(fields) + " }" if fields else "{}"


ONE = Dimension()


@dataclass(frozen=True)
class Rescale:
    """A change of unit system: decades moved per base dimension."""

    mass: int = 0
    length: int = 0
    time: int = 0
    current: int = 0
    temperature: int = 0
    amount: int = 0
    luminous: int = 0


def separator(a: Dimension, b: Dimension) -> Rescale:
    """A unit change that separates two different dimensions, as in Lean."""
    for base in ("length", "mass", "time", "current", "temperature", "amount"):
        if getattr(a, base) != getattr(b, base):
            return replace(Rescale(), **{base: 1})
    return Rescale(luminous=1)
