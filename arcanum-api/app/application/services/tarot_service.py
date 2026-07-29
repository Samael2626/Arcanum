import random
from typing import Optional

from app.data.deck_data import LEGACY_STATIC_DECK, attr, derive_name_es
from app.domain.entities import TarotCardEntity, TarotReadingEntity
from app.domain.spreads import get_spread, list_spreads
from app.schemas.tarot import TarotCardInDeck, TarotReadingResponse
from app.application.ports.repositories import TarotCardRepository, TarotReadingRepository


class TarotService:
    def __init__(self, card_repo: TarotCardRepository, reading_repo: TarotReadingRepository) -> None:
        self._card_repo = card_repo
        self._reading_repo = reading_repo

    def list_cards(self, *, arcana: Optional[str] = None,
                   suit: Optional[str] = None) -> list[TarotCardEntity]:
        return self._card_repo.list(arcana=arcana, suit=suit)

    def get_card(self, slug: str) -> Optional[TarotCardEntity]:
        return self._card_repo.get_by_slug(slug)

    def get_tarot_deck(self) -> list:
        cards = self._card_repo.deck()
        return cards if cards else LEGACY_STATIC_DECK

    def draw_one(self, *, reversed_chance: float = 0.5) -> TarotCardInDeck:
        pool = self._card_repo.deck()
        card = random.choice(pool) if pool else random.choice(LEGACY_STATIC_DECK)
        reversed_ = random.random() < reversed_chance
        return self._hydrate(card, position=None, reversed_=reversed_)

    def draw_spread(self, *, spread_type: str,
                    reversed_chance: float = 0.5) -> list[TarotCardInDeck]:
        spread = get_spread(spread_type)
        if spread is None:
            raise ValueError(f"spread_type no soportado: {spread_type}")
        pool = self._card_repo.deck()
        chosen = random.sample(pool, spread.card_count)
        cards: list[TarotCardInDeck] = []
        for card, position in zip(chosen, spread.positions):
            reversed_ = random.random() < reversed_chance
            cards.append(self._hydrate(card, position=position, reversed_=reversed_))
        return cards

    def save_reading(self, *, user_id, spread_type: str, question: Optional[str],
                     cards: list[TarotCardInDeck], moon_phase: Optional[str] = None,
                     planetary_hour: Optional[str] = None) -> TarotReadingResponse:
        cards_payload = [
            {"slug": c.slug, "position": c.position, "reversed": bool(c.reversed)}
            for c in cards
        ]
        entity = self._reading_repo.create(
            user_id=user_id, spread_type=spread_type, question=question,
            cards=cards_payload, moon_phase=moon_phase, planetary_hour=planetary_hour,
        )
        return TarotReadingResponse(
            id=entity.id,
            user_id=entity.user_id,
            spread_type=entity.spread_type,
            question=entity.question,
            cards_drawn=list(entity.cards_drawn or []),
            moon_phase=entity.moon_phase,
            planetary_hour=entity.planetary_hour,
            created_at=entity.created_at,
            resolved=cards,
        )

    @staticmethod
    def draw_cards(deck: list, *, count: int = 3,
                   spread_type: str = "three_card") -> list[dict]:
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

    @staticmethod
    def _hydrate(card, *, position: Optional[str],
                 reversed_: Optional[bool] = None) -> TarotCardInDeck:
        if reversed_ is None:
            reversed_ = False
        return TarotCardInDeck(
            slug=getattr(card, "slug", ""),
            name=TarotService._display_name(card),
            arcana=getattr(card, "arcana", None),
            suit=getattr(card, "suit", None),
            number=getattr(card, "number", None),
            element=getattr(card, "element", None),
            sephirah=getattr(card, "sephirah", None),
            decan=getattr(card, "decan", None),
            zodiac=getattr(card, "zodiac", None),
            title_book_t=getattr(card, "title_book_t", None),
            name_es=derive_name_es(card),
            position=position,
            reversed=reversed_,
            meaning=getattr(card, "meaning_reversed" if reversed_ else "meaning_upright", ""),
        )

    @staticmethod
    def _display_name(card) -> str:
        title = getattr(card, "title_book_t", None)
        slug = getattr(card, "slug", "")
        return title or slug.replace("-", " ").title()


# Module-level alias for backward compat (oracle.py, tests)
draw_cards = TarotService.draw_cards
