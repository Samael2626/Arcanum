"""Sesion de sorteo de la mesa de tarot: el servidor baraja y decide; el cliente elige posiciones.

El mazo vive como uno o varios montones. Cada monton es una lista de slugs donde
`None` marca una carta ya sacada: asi las posiciones no se mueven mientras el
abanico esta abierto y el cliente puede pedir "la carta 17" con seguridad.

El orden de los montones nunca sale hacia el cliente (ver `public_view`): solo
cuantas cartas quedan y en que posiciones. Las invertidas se deciden al barajar.

Es dominio puro: sin base de datos ni HTTP. El azar es inyectable para testear;
por defecto es `secrets.SystemRandom`, que no se puede predecir desde fuera.
"""

from __future__ import annotations

import random
import secrets
from dataclasses import dataclass, field
from typing import Optional, Sequence

from app.domain.decks import Deck

_SECURE = secrets.SystemRandom()


class SessionError(ValueError):
    """Operacion invalida sobre la sesion (monton inexistente, posicion vacia...)."""


@dataclass
class TarotSession:
    deck: str
    allow_reversed: bool
    piles: dict[str, list[Optional[str]]]
    reversed_: dict[str, bool] = field(default_factory=dict)
    drawn: list[str] = field(default_factory=list)
    seq: int = 0
    state: str = "sin barajar"

    # ---------- apertura y consulta ----------
    @classmethod
    def open(cls, deck: Deck, cards: Sequence[str]) -> "TarotSession":
        if not cards:
            raise SessionError("El mazo no tiene cartas.")
        if len(set(cards)) != len(cards):
            raise SessionError("El mazo tiene cartas repetidas.")
        return cls(deck=deck.slug, allow_reversed=deck.allow_reversed, piles={"p0": list(cards)})

    @classmethod
    def resume(cls, deck: Deck, cards: Sequence[str], drawn: Sequence[tuple[str, bool]]) -> "TarotSession":
        """Mesa nueva con unas cartas ya fuera del mazo: continuar una lectura guardada.

        Las sacadas conservan el sentido con el que se leyeron; el resto queda
        en un monton en orden de fabrica, listo para barajar y seguir.
        """
        session = cls.open(deck, cards)
        out = [slug for slug, _ in drawn]
        if len(set(out)) != len(out):
            raise SessionError("La lectura repite una carta.")
        missing = set(out) - set(cards)
        if missing:
            raise SessionError("La lectura tiene cartas que no están en este mazo.")
        session.piles["p0"] = [s for s in cards if s not in set(out)]
        session.drawn = list(out)
        session.reversed_ = {slug: deck.allow_reversed and rev for slug, rev in drawn}
        session.state = "continuada"
        return session

    def _pile(self, pid: str) -> list[Optional[str]]:
        if pid not in self.piles:
            raise SessionError(f"No existe el montón {pid}.")
        return self.piles[pid]

    def live(self, pid: str) -> list[str]:
        return [s for s in self._pile(pid) if s is not None]

    def count(self, pid: str) -> int:
        return len(self.live(pid))

    def total(self) -> int:
        return sum(self.count(p) for p in self.piles)

    def top(self, pid: str) -> Optional[int]:
        """Posicion de la carta de arriba del monton, o None si esta vacio."""
        return next((i for i, s in enumerate(self._pile(pid)) if s is not None), None)

    # ---------- operaciones ----------
    def shuffle(self, pid: str, rng: Optional[random.Random] = None, style: str = "cascada") -> None:
        rng = rng or _SECURE
        cards = self.live(pid)
        rng.shuffle(cards)
        self.piles[pid] = cards
        for s in cards:
            self.reversed_[s] = self.allow_reversed and rng.random() < .5
        self.state = f"barajado · {style}"

    def cut(self, pid: str, n: int) -> str:
        """Las n cartas de arriba pasan a un monton nuevo, cuyo id se devuelve."""
        cards = self.live(pid)
        if not 0 < n < len(cards):
            raise SessionError(f"Corte imposible: {n} de {len(cards)} cartas.")
        self.seq += 1
        new = f"p{self.seq}"
        self.piles[new] = cards[:n]
        self.piles[pid] = cards[n:]
        self.state = "cortado"
        return new

    def merge(self, top_first: Sequence[str], into: str) -> None:
        """Apila los montones dados (el primero queda arriba) en `into`."""
        if len(set(top_first)) != len(top_first) or len(top_first) < 2:
            raise SessionError("Para unir hacen falta al menos dos montones distintos.")
        if into not in top_first:
            raise SessionError("El montón resultante tiene que ser uno de los que se unen.")
        cards = [s for pid in top_first for s in self.live(pid)]
        for pid in top_first:
            del self.piles[pid]
        self.piles[into] = cards

    def take(self, pid: str, pos: int) -> tuple[str, bool]:
        """Saca la carta de la posicion dada. Devuelve (slug, invertida)."""
        pile = self._pile(pid)
        if not 0 <= pos < len(pile) or pile[pos] is None:
            raise SessionError(f"No hay carta en la posición {pos} del montón {pid}.")
        slug, pile[pos] = pile[pos], None
        self.drawn.append(slug)
        return slug, self.reversed_.get(slug, False)

    def give_back(self, slug: str, pid: str) -> None:
        """Devuelve una carta sacada al fondo del monton."""
        pile = self._pile(pid)
        if slug not in self.drawn:
            raise SessionError(f"La carta {slug} no está fuera del mazo.")
        self.drawn.remove(slug)
        pile.append(slug)

    def hide(self, seen: set[str], rng: Optional[random.Random] = None) -> None:
        """Las cartas `seen` (ya vistas por el cliente y devueltas al mazo) pasan a
        un sitio al azar de su monton y su sentido se sortea de nuevo.

        Sin esto, sacar y deshacer servia para espiar: la carta volvia a su
        posicion con su sentido (revision de codigo del 06-oct). Los huecos del
        abanico (`None`) no se mueven. O(n) por monton.
        """
        rng = rng or _SECURE
        for pid, pile in self.piles.items():
            live = [i for i, s in enumerate(pile) if s is not None]
            for i in [i for i in live if pile[i] in seen]:
                j = rng.choice([k for k in live if k != i] or [i])
                pile[i], pile[j] = pile[j], pile[i]
        for s in seen:
            self.reversed_[s] = self.allow_reversed and rng.random() < .5

    def gather(self, pid: str) -> None:
        """Todas las cartas sacadas vuelven al fondo del monton."""
        self.piles[pid] = self.live(pid) + self.drawn
        self.drawn = []
        self.state = "recogido · sin barajar"

    # ---------- lo que ve el cliente ----------
    def public_view(self) -> dict:
        """Estado sin revelar el orden: cuantas quedan, en que posiciones, y las ya sacadas."""
        return {
            "deck": self.deck,
            "state": self.state,
            "total": self.total(),
            "piles": {
                pid: {"count": self.count(pid), "positions": [i for i, s in enumerate(pile) if s is not None]}
                for pid, pile in self.piles.items()
            },
            "drawn": [{"slug": s, "reversed": self.reversed_.get(s, False)} for s in self.drawn],
        }

    # ---------- persistencia (JSONB) ----------
    def to_dict(self) -> dict:
        return {
            "deck": self.deck, "allow_reversed": self.allow_reversed,
            "piles": {pid: list(pile) for pid, pile in self.piles.items()},
            "reversed": dict(self.reversed_), "drawn": list(self.drawn),
            "seq": self.seq, "state": self.state,
        }

    @classmethod
    def from_dict(cls, data: dict) -> "TarotSession":
        return cls(
            deck=data["deck"], allow_reversed=data["allow_reversed"],
            piles={pid: list(pile) for pid, pile in data["piles"].items()},
            reversed_=dict(data.get("reversed", {})), drawn=list(data.get("drawn", [])),
            seq=data.get("seq", 0), state=data.get("state", "sin barajar"),
        )
