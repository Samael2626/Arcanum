"""Value objects para spreads de Tarot: definiciones y registro."""

from dataclasses import dataclass, field
from enum import Enum
from typing import Optional


class SpreadType(str, Enum):
    ONE_CARD = "one_card"
    THREE_CARD = "three_card"
    CELTIC_CROSS = "celtic_cross"


@dataclass(frozen=True)
class Spread:
    slug: str
    name: str
    positions: list[str] = field(default_factory=list)

    @property
    def card_count(self) -> int:
        return len(self.positions)

    @classmethod
    def one_card(cls) -> "Spread":
        return cls(slug="one_card", name="Una carta", positions=["Mensaje"])

    @classmethod
    def three_card(cls) -> "Spread":
        return cls(slug="three_card", name="Tres cartas", positions=["Pasado", "Presente", "Futuro"])

    @classmethod
    def celtic_cross(cls) -> "Spread":
        return cls(
            slug="celtic_cross",
            name="Cruz Celta",
            positions=[
                "Situación actual", "El desafío", "Fundamento (raíz)", "Pasado reciente",
                "Lo que corona (posible futuro)", "Futuro inmediato", "Tu actitud",
                "Entorno e influencias", "Esperanzas y miedos", "Resultado",
            ],
        )


_SPREAD_REGISTRY: dict[str, Spread] = {
    "one_card": Spread.one_card(),
    "three_card": Spread.three_card(),
    "celtic_cross": Spread.celtic_cross(),
}


def get_spread(slug: str) -> Optional[Spread]:
    return _SPREAD_REGISTRY.get(slug)


def list_spreads() -> list[Spread]:
    return list(_SPREAD_REGISTRY.values())
