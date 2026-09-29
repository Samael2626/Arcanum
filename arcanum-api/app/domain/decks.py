"""Mazos de la mesa de tarot: arte + contenido.

Un mazo dice que cartas entran (por arcano) y si admite cartas invertidas. El arte
lo resuelve la app con `art`. Anadir un mazo nuevo es anadir una entrada aqui, sin
tocar el motor de sesiones.
"""

from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class Deck:
    slug: str
    name: str
    description: str
    arcana: tuple[str, ...]          # valores de TarotCard.arcana que entran en el mazo
    allow_reversed: bool = True
    art: str = "rws"

    def includes(self, arcana: str) -> bool:
        return arcana in self.arcana


_DECKS: dict[str, Deck] = {
    d.slug: d for d in (
        Deck("rws", "Rider–Waite–Smith", "78 cartas", ("major", "minor")),
        Deck("mayores", "Arcanos Mayores", "22 triunfos", ("major",)),
    )
}


def get_deck(slug: str) -> Optional[Deck]:
    return _DECKS.get(slug)


def list_decks() -> list[Deck]:
    return list(_DECKS.values())
