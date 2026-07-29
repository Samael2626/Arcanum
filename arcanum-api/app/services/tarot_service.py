"""Servicio de Tarot: catálogo + sorteos.

NO reimplementa interpretaciones — viven en la BD (tarot_cards, campo
meaning_upright / meaning_reversed). Aquí solo sorteamos y resolvemos la
carta con su significado correspondiente según orientación y spread.
"""
from __future__ import annotations

import random
from typing import Optional

from sqlalchemy.orm import Session

from app.data.deck_data import LEGACY_STATIC_DECK, attr, derive_name_es
from app.domain.spreads import get_spread, list_spreads
from app.models.tarot import TarotCard, TarotReading
from app.schemas.tarot import TarotCardInDeck, TarotReadingResponse


# ── API pública ──────────────────────────────────────────────────────────────


def list_cards(db: Session, *, arcana: Optional[str] = None,
               suit: Optional[str] = None) -> list[TarotCard]:
    q = db.query(TarotCard)
    if arcana:
        q = q.filter(TarotCard.arcana == arcana)
    if suit:
        q = q.filter(TarotCard.suit == suit)
    return q.order_by(TarotCard.arcana, TarotCard.number).all()


def get_card(db: Session, slug: str) -> Optional[TarotCard]:
    return db.query(TarotCard).filter(TarotCard.slug == slug).first()


def get_tarot_deck(db: Optional[Session] = None) -> list:
    """Compat: devuelve la baraja completa desde la BD si hay sesión; si no,
    cae a fuente estática legacy (tests / entornos sin BD sembrada)."""
    if db is not None:
        cards = list_cards(db)
        if cards:
            return cards
    return LEGACY_STATIC_DECK


def draw_cards(deck: list, *, count: int = 3,
               spread_type: str = "three_card") -> list[dict]:
    """Sorteo genérico que devuelve el JSON sin guardar (compat con oracle.py).

    Acepta tanto dicts (deck estático legacy) como modelos SQLAlchemy.
    """
    spread = get_spread(spread_type)
    if spread is not None:
        count = spread.card_count
    count = min(count, len(deck))

    chosen = random.sample(deck, count)
    result: list[dict] = []
    for i, card in enumerate(chosen):
        upright = random.choice([True, False])
        meaning_upright = attr(card, "meaning_upright", "")
        meaning_reversed = attr(card, "meaning_reversed", "")
        meaning = meaning_upright if upright else meaning_reversed
        slug = attr(card, "slug", "")
        number = attr(card, "number", 0)
        title = attr(card, "title_book_t") or slug.replace("-", " ").title()
        result.append({
            "id": number or 0,
            "slug": slug,
            "name": title,
            "position": spread.positions[i] if spread else None,
            "drawn_upright": upright,
            "meaning_upright": meaning_upright,
            "meaning_reversed": meaning_reversed,
            "meaning": meaning,
            "arcana": attr(card, "arcana"),
            "suit": attr(card, "suit"),
            "number": number,
            "element": attr(card, "element"),
            "hebrew_letter": attr(card, "hebrew_letter"),
            "astro_correspondence": attr(card, "astro_correspondence"),
            "decan": attr(card, "decan"),
            "zodiac": attr(card, "zodiac"),
            "name_es": derive_name_es(card),
        })
    return result


def draw_one(db: Session, *, reversed_chance: float = 0.5) -> TarotCardInDeck:
    card = random.choice(list_cards(db))
    reversed_ = random.random() < reversed_chance
    return _hydrate(card, position=None, reversed_=reversed_)


def draw_spread(db: Session, *, spread_type: str,
                reversed_chance: float = 0.5) -> list[TarotCardInDeck]:
    spread = get_spread(spread_type)
    if spread is None:
        raise ValueError(f"spread_type no soportado: {spread_type}")

    pool = list_cards(db)
    chosen = random.sample(pool, spread.card_count)
    cards: list[TarotCardInDeck] = []
    for card, position in zip(chosen, spread.positions):
        reversed_ = random.random() < reversed_chance
        cards.append(_hydrate(card, position=position, reversed_=reversed_))
    return cards


def save_reading(db: Session, *, user_id, spread_type: str, question: Optional[str],
                 cards: list[TarotCardInDeck], moon_phase: Optional[str] = None,
                 planetary_hour: Optional[str] = None) -> TarotReadingResponse:
    """Persiste la lectura (sin interpretations en JSON — solo lo sorteado) y
    devuelve la respuesta con las cartas ya resueltas.
    """
    cards_payload = [
        {"slug": c.slug, "position": c.position, "reversed": bool(c.reversed)}
        for c in cards
    ]
    reading = TarotReading(
        user_id=user_id,
        spread_type=spread_type,
        question=question,
        cards_drawn=cards_payload,
        moon_phase=moon_phase,
        planetary_hour=planetary_hour,
    )
    db.add(reading)
    db.commit()
    db.refresh(reading)

    return TarotReadingResponse(
        id=reading.id,
        user_id=reading.user_id,
        spread_type=reading.spread_type,
        question=reading.question,
        cards_drawn=list(reading.cards_drawn or []),
        moon_phase=reading.moon_phase,
        planetary_hour=reading.planetary_hour,
        created_at=reading.created_at,
        resolved=cards,
    )


# ── Helpers ──────────────────────────────────────────────────────────────────


def _hydrate(card: TarotCard, *, position: Optional[str],
             reversed_: Optional[bool] = None) -> TarotCardInDeck:
    if reversed_ is None:
        reversed_ = False
    return TarotCardInDeck(
        slug=card.slug,
        name=_display_name(card),
        arcana=card.arcana,
        suit=card.suit,
        number=card.number,
        element=card.element,
        sephirah=card.sephirah,
        decan=card.decan,
        zodiac=card.zodiac,
        title_book_t=card.title_book_t,
        name_es=derive_name_es(card),
        position=position,
        reversed=reversed_,
        meaning=card.meaning_reversed if reversed_ else card.meaning_upright,
    )


def _card_id(card: TarotCard) -> int:
    if card.number:
        return card.number
    return 0


def _display_name(card: TarotCard) -> str:
    return card.title_book_t or card.slug.replace("-", " ").title()
