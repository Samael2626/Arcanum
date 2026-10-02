"""Servicio de la mesa de tarot: sesiones de sorteo, interpretacion de Tradicion y lecturas.

El dominio (`TarotSession`) decide el orden y las invertidas; aqui se carga y se
guarda la sesion, se valida lo que pide el cliente y se arma la interpretacion.
El cupo NO se toca aqui: lo reserva la ruta de interpretar (decision D1).
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Callable, Optional, TypeVar
from uuid import UUID

from app.application.ports.repositories import (
    TarotCardRepository,
    TarotReadingRepository,
    TarotTableRepository,
)
from app.application.services.tarot_service import TarotService
from app.data.deck_data import derive_name_es
from app.domain.decks import Deck, get_deck, list_decks
from app.domain.entities import TarotCardEntity, TarotReadingEntity, TarotTableEntity
from app.domain.spreads import get_spread
from app.domain.tarot_session import SessionError, TarotSession
from app.schemas.tarot import TarotReadingResponse

# Una mesa sin tocar durante este tiempo se da por abandonada
SESSION_TTL = timedelta(hours=12)
# Aclaratorias por hueco; mas que eso ya no aclara nada
MAX_CLARIFIERS_PER_SLOT = 3
# Cuanto guarda el servidor el mazo de antes del ultimo gesto. La app ofrece
# deshacer 5 s; el margen es para la red.
UNDO_WINDOW = timedelta(seconds=30)
# Lectura sin tirada elegida: cartas sueltas sobre el paño
FREE_SPREAD = "free"

# Orden de fabrica: mayores 0-21 y despues los palos
_SUIT_ORDER = {"wands": 0, "bastos": 0, "cups": 1, "copas": 1, "swords": 2, "espadas": 2,
               "pentacles": 3, "disks": 3, "oros": 3}

T = TypeVar("T")


class TableNotFound(LookupError):
    """No hay mesa activa con ese id para este usuario (o caduco)."""


class TableConflict(RuntimeError):
    """La mesa existe pero su estado no admite la operacion."""


@dataclass(frozen=True)
class Placement:
    slug: str
    slot: Optional[int] = None       # hueco de la tirada
    clarifies: Optional[int] = None  # hueco al que aclara (aclaratoria)
    turned: bool = False             # el lector la giro 180 grados en la mesa


def _factory_key(card: TarotCardEntity) -> tuple:
    return (card.arcana != "major", _SUIT_ORDER.get(card.suit or "", 9), card.number or 0, card.slug)


def card_view(card: TarotCardEntity, reversed_: bool) -> dict:
    """Lo que el cliente necesita para pintar la cara de una carta ya sacada."""
    return {
        "slug": card.slug, "name": TarotService._display_name(card), "name_es": derive_name_es(card),
        "arcana": card.arcana, "suit": card.suit, "number": card.number, "reversed": reversed_,
    }


class TarotTableService:
    def __init__(self, card_repo: TarotCardRepository, table_repo: TarotTableRepository,
                 reading_repo: TarotReadingRepository,
                 clock: Callable[[], datetime] = lambda: datetime.now(timezone.utc)) -> None:
        self._cards = card_repo
        self._tables = table_repo
        self._readings = reading_repo
        self._now = clock

    # ---------- catalogos ----------
    def decks(self) -> list[tuple[Deck, int]]:
        pool = self._cards.deck()
        return [(d, sum(d.includes(c.arcana) for c in pool)) for d in list_decks()]

    # ---------- ciclo de la sesion ----------
    def open(self, user_id: UUID, deck_slug: str, from_reading: Optional[UUID] = None) -> TarotTableEntity:
        """Abre una mesa. Con `from_reading`, continua esa lectura: sus cartas salen
        del mazo con el sentido con que se leyeron y el resto queda para seguir."""
        deck = get_deck(deck_slug)
        if deck is None:
            raise SessionError(f"Mazo desconocido: {deck_slug}.")
        cards = [c.slug for c in sorted((c for c in self._cards.deck() if deck.includes(c.arcana)), key=_factory_key)]
        if from_reading is None:
            session = TarotSession.open(deck, cards)
        else:
            reading = self._readings.get_owned(from_reading, user_id)
            if reading is None:
                raise TableNotFound("Lectura no encontrada.")
            drawn = [(c["slug"], bool(c.get("reversed"))) for c in reading.cards_drawn or []]
            session = TarotSession.resume(deck, cards, drawn)
        previous = self._tables.active(user_id, lock=True)
        if previous is not None:
            # abrir otra mesa abandona la anterior: una activa por usuario
            previous.status = "abandoned"
            self._tables.save(previous, commit=False)
        return self._tables.create(user_id, deck.slug, session.to_dict(), self._now() + SESSION_TTL)

    def current(self, user_id: UUID) -> Optional[TarotTableEntity]:
        table = self._tables.active(user_id)
        if table is not None and self._expired(table):
            return None
        return table

    def _expired(self, table: TarotTableEntity) -> bool:
        if table.expires_at > self._now():
            return False
        table.status = "abandoned"
        self._tables.save(table)
        return True

    def _load(self, session_id: UUID, user_id: UUID) -> TarotTableEntity:
        table = self._tables.get_owned(session_id, user_id, lock=True)
        if table is None or table.status == "abandoned" or (table.active and self._expired(table)):
            raise TableNotFound("La mesa no existe o ya caducó.")
        if not table.active:
            raise TableConflict("La mesa ya está cerrada.")
        return table

    def _operate(self, session_id: UUID, user_id: UUID, op: Callable[[TarotSession], T],
                 checkpoint: bool = True) -> tuple[TarotTableEntity, T]:
        """Aplica una operacion al mazo. Con `checkpoint`, el mazo de antes queda
        guardado para deshacer; sin el, se conserva el punto anterior: asi un gesto
        de varias operaciones (unir y recoger, por ejemplo) se deshace entero."""
        table = self._load(session_id, user_id)
        session = TarotSession.from_dict(table.state)
        result = op(session)
        if checkpoint:
            table.previous_state = table.state
            table.previous_until = self._now() + UNDO_WINDOW
        table.state = session.to_dict()
        table.expires_at = self._now() + SESSION_TTL
        self._tables.save(table)
        return table, result

    # ---------- operaciones libres (sin cupo) ----------
    def shuffle(self, session_id: UUID, user_id: UUID, pile: str, style: str,
                checkpoint: bool = True) -> TarotTableEntity:
        return self._operate(session_id, user_id, lambda s: s.shuffle(pile, style=style), checkpoint)[0]

    def cut(self, session_id: UUID, user_id: UUID, pile: str, n: int,
            checkpoint: bool = True) -> tuple[TarotTableEntity, str]:
        return self._operate(session_id, user_id, lambda s: s.cut(pile, n), checkpoint)

    def merge(self, session_id: UUID, user_id: UUID, piles: list[str], into: str,
              checkpoint: bool = True) -> TarotTableEntity:
        return self._operate(session_id, user_id, lambda s: s.merge(piles, into), checkpoint)[0]

    def take(self, session_id: UUID, user_id: UUID, pile: str, position: int,
             checkpoint: bool = True) -> tuple[TarotTableEntity, dict]:
        table, (slug, reversed_) = self._operate(session_id, user_id, lambda s: s.take(pile, position), checkpoint)
        card = self._cards.get_by_slug(slug)
        if card is None:
            raise SessionError(f"La carta {slug} no está en el catálogo.")
        return table, card_view(card, reversed_)

    def give_back(self, session_id: UUID, user_id: UUID, slug: str, pile: str,
                  checkpoint: bool = True) -> TarotTableEntity:
        return self._operate(session_id, user_id, lambda s: s.give_back(slug, pile), checkpoint)[0]

    def gather(self, session_id: UUID, user_id: UUID, pile: str, checkpoint: bool = True) -> TarotTableEntity:
        return self._operate(session_id, user_id, lambda s: s.gather(pile), checkpoint)[0]

    def undo(self, session_id: UUID, user_id: UUID) -> TarotTableEntity:
        """Vuelve el mazo a como estaba antes del ultimo gesto. Una sola vez."""
        table = self._load(session_id, user_id)
        if table.previous_state is None or table.previous_until is None or table.previous_until <= self._now():
            raise TableConflict("Ya no se puede deshacer.")
        table.state = table.previous_state
        table.previous_state = table.previous_until = None
        self._tables.save(table)
        return table

    # ---------- interpretar (la ruta reserva el cupo) ----------
    def build_interpretation(self, session_id: UUID, user_id: UUID, spread_slug: str,
                             question: Optional[str], placements: list[Placement],
                             moon_phase: Optional[str], planetary_hour: Optional[str]) -> dict:
        """Valida la tirada contra el mazo del servidor y arma la lectura de Tradicion.

        No escribe nada: la ruta decide cuando cobrar y guardar. Las invertidas las
        pone el servidor; el cliente solo dice que carta va en que hueco.
        """
        table = self._load(session_id, user_id)
        name, cards = self._lay_out(TarotSession.from_dict(table.state), spread_slug, placements, complete=True)
        return {
            "session_id": str(table.id), "spread": spread_slug, "spread_name": name,
            "question": question, "moon_phase": moon_phase, "planetary_hour": planetary_hour,
            "cards": cards,
        }

    def _lay_out(self, session: TarotSession, spread_slug: Optional[str], placements: list[Placement],
                 *, complete: bool) -> tuple[str, list[dict]]:
        """Valida donde esta cada carta contra el mazo del servidor y arma su lectura.

        `complete`: interpretar exige todos los huecos llenos; cerrar el circulo sin
        interpretar admite una tirada a medias. Sin tirada (`None`), las cartas son
        una lectura libre. Las invertidas las pone el servidor; girar una carta en
        la mesa la invierte (salvo en un mazo sin invertidas).
        """
        slugs = [p.slug for p in placements]
        if not slugs:
            raise SessionError("No hay cartas que leer.")
        if len(set(slugs)) != len(slugs):
            raise SessionError("Una carta no puede estar en dos sitios.")
        if any(s not in session.drawn for s in slugs):
            raise SessionError("Solo se leen cartas sacadas del mazo.")
        catalog = self._cards.by_slugs(slugs)
        if len(catalog) != len(slugs):
            raise SessionError("Hay cartas que no están en el catálogo.")

        def read(p: Placement, position: str, meaning: Optional[str]) -> dict:
            card = catalog[p.slug]
            rev = session.allow_reversed and session.reversed_.get(p.slug, False) != p.turned
            return {
                **card_view(card, rev), "slot": p.slot, "clarifies": p.clarifies,
                "position": position, "position_meaning": meaning,
                "meaning": card.meaning_reversed if rev else card.meaning_upright,
            }

        if spread_slug is None:
            if any(p.slot is not None or p.clarifies is not None for p in placements):
                raise SessionError("Sin tirada no hay huecos.")
            return "Lectura libre", [read(p, "Libre", None) for p in placements]

        spread = get_spread(spread_slug)
        if spread is None:
            raise SessionError(f"Tirada desconocida: {spread_slug}.")
        n = spread.card_count
        main = [p for p in placements if p.clarifies is None]
        extra = [p for p in placements if p.clarifies is not None]
        if any(p.slot is not None for p in extra) or any(p.slot is None for p in main):
            raise SessionError("Cada carta va en un hueco o aclara uno, no las dos cosas.")
        slots = sorted(p.slot for p in main)
        if len(set(slots)) != len(slots) or any(not 0 <= i < n for i in slots):
            raise SessionError(f"La tirada {spread.name} tiene {n} huecos, una carta en cada uno.")
        if complete and slots != list(range(n)):
            raise SessionError(f"La tirada {spread.name} necesita sus {n} huecos llenos, una carta en cada uno.")
        for p in extra:
            if p.clarifies not in slots:
                raise SessionError("Una aclaratoria aclara a una carta que está en su hueco.")
            if sum(q.clarifies == p.clarifies for q in extra) > MAX_CLARIFIERS_PER_SLOT:
                raise SessionError(f"Como mucho {MAX_CLARIFIERS_PER_SLOT} aclaratorias por hueco.")
        cards = [
            read(p, spread.positions[p.slot], spread.slots[p.slot].meaning if spread.slots else None)
            for p in sorted(main, key=lambda q: q.slot)
        ] + [read(p, f"Aclara: {spread.positions[p.clarifies]}", None) for p in extra]
        return spread.name, cards

    def stored_interpretation(self, session_id: UUID, user_id: UUID) -> Optional[dict]:
        """La interpretacion ya pagada de esta mesa, o None si aun no se interpreto."""
        table = self._tables.get_owned(session_id, user_id)
        if table is None or table.status != "interpreted":
            return None
        return table.interpretation

    def store_interpretation(self, session_id: UUID, user_id: UUID, interpretation: dict) -> None:
        """Deja la lectura en la mesa sin commit: la ruta captura el cupo en la misma transaccion."""
        table = self._load(session_id, user_id)
        table.interpretation = interpretation
        table.status = "interpreted"
        # lo interpretado ya no se deshace: la lectura se quedaria sin sus cartas
        table.previous_state = table.previous_until = None
        table.expires_at = self._now() + SESSION_TTL
        self._tables.save(table, commit=False)

    # ---------- cerrar el circulo ----------
    def close(self, session_id: UUID, user_id: UUID, table_snapshot: Optional[dict], *,
              spread_slug: Optional[str] = None, question: Optional[str] = None,
              placements: Optional[list[Placement]] = None,
              moon_phase: Optional[str] = None, planetary_hour: Optional[str] = None) -> TarotReadingResponse:
        """Cierra el circulo y guarda la lectura. Repetirlo devuelve la misma lectura.

        Interpretada, se guarda lo interpretado. Sin interpretar (decision de
        Samuel, 30-sep) tambien se puede: se guarda gratis lo que hay en la mesa,
        tirada completa, a medias o libre, con el sentido que decidio el servidor.
        """
        table = self._tables.get_owned(session_id, user_id, lock=True)
        if table is None:
            raise TableNotFound("La mesa no existe.")
        if table.status == "closed" and table.reading_id is not None:
            reading = self._readings.get_owned(table.reading_id, user_id)
            if reading is not None:
                return self.reading_response(reading)
        if table.status == "interpreted" and table.interpretation:
            it = table.interpretation
        elif table.status == "open":
            name, cards = self._lay_out(
                TarotSession.from_dict(table.state), spread_slug, placements or [], complete=False,
            )
            it = {"spread": spread_slug or FREE_SPREAD, "spread_name": name, "question": question,
                  "moon_phase": moon_phase, "planetary_hour": planetary_hour, "cards": cards}
        else:
            raise TableConflict("Esta mesa no se puede cerrar.")
        entity = self._readings.create(
            user_id=user_id, spread_type=it["spread"], question=it.get("question"),
            cards=[{k: c[k] for k in ("slug", "position", "reversed", "slot", "clarifies")} for c in it["cards"]],
            moon_phase=it.get("moon_phase"), planetary_hour=it.get("planetary_hour"),
            table_snapshot=table_snapshot, commit=False,
        )
        table.status, table.reading_id = "closed", entity.id
        table.previous_state = table.previous_until = None
        self._tables.save(table)
        return self.reading_response(entity)

    # ---------- lecturas guardadas ----------
    def readings(self, user_id: UUID, limit: int) -> list[TarotReadingResponse]:
        return [self.reading_response(r, resolve=False) for r in self._readings.list_by_user(user_id, limit=limit)]

    def reading(self, user_id: UUID, reading_id: UUID) -> Optional[TarotReadingResponse]:
        entity = self._readings.get_owned(reading_id, user_id)
        return self.reading_response(entity) if entity else None

    def reading_response(self, entity: TarotReadingEntity, *, resolve: bool = True) -> TarotReadingResponse:
        drawn = list(entity.cards_drawn or [])
        resolved = []
        if resolve:
            catalog = self._cards.by_slugs([c["slug"] for c in drawn])
            resolved = [TarotService._hydrate(catalog[c["slug"]], position=c.get("position"),
                                              reversed_=bool(c.get("reversed")))
                        for c in drawn if c["slug"] in catalog]
        return TarotReadingResponse(
            id=entity.id, user_id=entity.user_id, spread_type=entity.spread_type,
            question=entity.question, cards_drawn=drawn, moon_phase=entity.moon_phase,
            planetary_hour=entity.planetary_hour, created_at=entity.created_at,
            table_snapshot=entity.table_snapshot, resolved=resolved,
        )
