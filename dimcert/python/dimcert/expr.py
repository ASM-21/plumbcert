"""Expression language, dimension inference and unit-rescaling semantics.

Mirrors DimCert/Expr.lean. `infer` computes a dimension or fails; `scale`
computes how the numeric value moves under a change of base units, structurally.
The Lean side proves these two agree: `scale e r == -infer(e).decade_shift(r)`.
The property tests in this package check the same statement by sampling.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Union

from .dimension import ONE, Dimension, Rescale, separator


@dataclass(frozen=True)
class Sym:
    name: str
    dim: Dimension


@dataclass(frozen=True)
class Const:
    pass


@dataclass(frozen=True)
class BinOp:
    op: str  # mul | div | add | sub
    left: "Expr"
    right: "Expr"


@dataclass(frozen=True)
class Pow:
    base: "Expr"
    n: int


@dataclass(frozen=True)
class Sqrt:
    arg: "Expr"


Expr = Union[Sym, Const, BinOp, Pow, Sqrt]


def mul(a: Expr, b: Expr) -> Expr:
    return BinOp("mul", a, b)


def div(a: Expr, b: Expr) -> Expr:
    return BinOp("div", a, b)


def add(a: Expr, b: Expr) -> Expr:
    return BinOp("add", a, b)


def sub(a: Expr, b: Expr) -> Expr:
    return BinOp("sub", a, b)


def infer(e: Expr) -> Dimension | None:
    if isinstance(e, Sym):
        return e.dim
    if isinstance(e, Const):
        return ONE
    if isinstance(e, Pow):
        x = infer(e.base)
        return None if x is None else x**e.n
    if isinstance(e, Sqrt):
        x = infer(e.arg)
        return None if x is None else x.sqrt()
    x, y = infer(e.left), infer(e.right)
    if x is None or y is None:
        return None
    if e.op == "mul":
        return x * y
    if e.op == "div":
        return x / y
    return x if x == y else None  # add, sub


def scale(e: Expr, r: Rescale) -> int:
    if isinstance(e, Sym):
        return -e.dim.decade_shift(r)
    if isinstance(e, Const):
        return 0
    if isinstance(e, Pow):
        return e.n * scale(e.base, r)
    if isinstance(e, Sqrt):
        inner = scale(e.arg, r)
        return inner // 2 if inner >= 0 else -((-inner) // 2)
    if e.op == "mul":
        return scale(e.left, r) + scale(e.right, r)
    if e.op == "div":
        return scale(e.left, r) - scale(e.right, r)
    return scale(e.left, r)  # add, sub


def render_inferred(d: Dimension | None) -> str:
    return "INCONSISTENT" if d is None else d.render()


@dataclass(frozen=True)
class Equation:
    name: str
    lhs: Expr
    rhs: Expr

    @property
    def checks(self) -> bool:
        a, b = infer(self.lhs), infer(self.rhs)
        return a is not None and b is not None and a == b

    def report(self) -> str:
        verdict = "ok  " if self.checks else "FAIL"
        return (
            f"{verdict}  {self.name}\n"
            f"        lhs: {render_inferred(infer(self.lhs))}\n"
            f"        rhs: {render_inferred(infer(self.rhs))}"
        )

    def counterexample_rescale(self) -> Rescale | None:
        """A change of units that pulls the two sides apart, when one exists."""
        a, b = infer(self.lhs), infer(self.rhs)
        if a is None or b is None or a == b:
            return None
        return separator(a, b)
