"""Servicio de Tarot: catálogo + sorteos.

NO reimplementa interpretaciones — viven en la BD (tarot_cards, campo
meaning_upright / meaning_reversed). Aquí solo sorteamos y resolvemos la
carta con su significado correspondiente según orientación y spread.

Mantiene retrocompatibilidad con el endpoint ya existente en routers/oracle.py
(`/oracle/tarot/draw`) para no romper al frontend mientras se migra.
"""
from __future__ import annotations

import random
from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session

from app.models.tarot import TarotCard, TarotReading
from app.schemas.tarot import TarotCardInDeck, TarotReadingResponse


# ── Spreads soportados ────────────────────────────────────────────────────────

SPREAD_POSITIONS: Dict[str, List[str]] = {
    "one_card": ["Mensaje"],
    "three_card": ["Pasado", "Presente", "Futuro"],
    "celtic_cross": [
        "Situación actual", "El desafío", "Fundamento (raíz)", "Pasado reciente",
        "Lo que corona (posible futuro)", "Futuro inmediato", "Tu actitud",
        "Entorno e influencias", "Esperanzas y miedos", "Resultado",
    ],
}


# ── API pública ──────────────────────────────────────────────────────────────


def list_cards(db: Session, *, arcana: Optional[str] = None,
               suit: Optional[str] = None) -> List[TarotCard]:
    """Catálogo: lista todas las cartas, opcionalmente filtradas."""
    q = db.query(TarotCard)
    if arcana:
        q = q.filter(TarotCard.arcana == arcana)
    if suit:
        q = q.filter(TarotCard.suit == suit)
    return q.order_by(TarotCard.arcana, TarotCard.number).all()


def get_card(db: Session, slug: str) -> Optional[TarotCard]:
    return db.query(TarotCard).filter(TarotCard.slug == slug).first()


def get_tarot_deck(db: Optional[Session] = None) -> List[TarotCard]:
    """Compat: devuelve la baraja completa desde la BD si hay sesión; si no,
    cae a una fuente de dataset estático (deprecated path).

    Mantiene retrocompatibilidad con oracle.py mientras el catálogo BD se
    siembra. Cuando la BD está poblada (caso normal), la consulta es la fuente.
    """
    if db is not None:
        cards = list_cards(db)
        if cards:
            return cards
    # Fallback: dataset estático legacy para tests / entornos sin BD sembrada.
    return _LEGACY_STATIC_DECK


# ── Compat legacy (TAROT_DECK en memoria, usado por tests / fallback) ──────


_LEGACY_STATIC_DECK: List[dict] = [
    {"slug": "el-loco", "name": "El Loco",
     "meaning_upright": "Nuevos comienzos, espontaneidad, fe en lo desconocido.",
     "meaning_reversed": "Imprudencia, riesgo necio, miedo a dar el salto.",
     "number": 0, "id": 0},
    {"slug": "el-mago", "name": "El Mago",
     "meaning_upright": "Manifestación, poder, voluntad de crear.",
     "meaning_reversed": "Manipulación, talento desperdiciado, engaño.",
     "number": 1, "id": 1},
    {"slug": "la-sacerdotisa", "name": "La Sacerdotisa",
     "meaning_upright": "Intuición, misterio, conocimiento oculto.",
     "meaning_reversed": "Secretos, desconexión de la voz interior.",
     "number": 2, "id": 2},
    {"slug": "la-emperatriz", "name": "La Emperatriz",
     "meaning_upright": "Abundancia, fertilidad, creatividad, cuidado.",
     "meaning_reversed": "Dependencia, bloqueo creativo, descuido.",
     "number": 3, "id": 3},
    {"slug": "el-emperador", "name": "El Emperador",
     "meaning_upright": "Autoridad, estructura, control, estabilidad.",
     "meaning_reversed": "Tiranía, rigidez, autoridad mal usada.",
     "number": 4, "id": 4},
    {"slug": "el-hierofante", "name": "El Hierofante",
     "meaning_upright": "Tradición, enseñanza, guía espiritual.",
     "meaning_reversed": "Dogma, rebeldía, romper convenciones.",
     "number": 5, "id": 5},
    {"slug": "los-enamorados", "name": "Los Enamorados",
     "meaning_upright": "Amor, unión, elección desde el corazón.",
     "meaning_reversed": "Desarmonía, conflicto de valores, mala elección.",
     "number": 6, "id": 6},
    {"slug": "el-carro", "name": "El Carro",
     "meaning_upright": "Voluntad, victoria, avance con control.",
     "meaning_reversed": "Descontrol, rumbo perdido, derrota.",
     "number": 7, "id": 7},
    {"slug": "la-fuerza", "name": "La Fuerza",
     "meaning_upright": "Coraje, dominio interior, compasión.",
     "meaning_reversed": "Duda, debilidad, fuerza mal dirigida.",
     "number": 8, "id": 8},
    {"slug": "el-ermitano", "name": "El Ermitaño",
     "meaning_upright": "Introspección, búsqueda de verdad, guía interior.",
     "meaning_reversed": "Aislamiento, evasión, soledad estéril.",
     "number": 9, "id": 9},
    {"slug": "la-rueda", "name": "La Rueda de la Fortuna",
     "meaning_upright": "Ciclos, destino, cambio de suerte.",
     "meaning_reversed": "Mala racha, resistencia al cambio.",
     "number": 10, "id": 10},
    {"slug": "la-justicia", "name": "La Justicia",
     "meaning_upright": "Verdad, equidad, causa y efecto.",
     "meaning_reversed": "Injusticia, deshonestidad, evadir la responsabilidad.",
     "number": 11, "id": 11},
    {"slug": "el-colgado", "name": "El Colgado",
     "meaning_upright": "Nueva perspectiva, entrega, pausa fértil.",
     "meaning_reversed": "Estancamiento, sacrificio inútil, resistencia.",
     "number": 12, "id": 12},
    {"slug": "la-muerte", "name": "La Muerte",
     "meaning_upright": "Transformación, fin de un ciclo, renacimiento.",
     "meaning_reversed": "Aferrarse, miedo al cambio, estancamiento.",
     "number": 13, "id": 13},
    {"slug": "la-templanza", "name": "La Templanza",
     "meaning_upright": "Equilibrio, moderación, alquimia interior.",
     "meaning_reversed": "Desequilibrio, exceso, impaciencia.",
     "number": 14, "id": 14},
    {"slug": "el-diablo", "name": "El Diablo",
     "meaning_upright": "Apego, sombra, materialismo, atadura.",
     "meaning_reversed": "Liberación, romper cadenas, recuperar el poder.",
     "number": 15, "id": 15},
    {"slug": "la-torre", "name": "La Torre",
     "meaning_upright": "Ruptura súbita, revelación, derrumbe de lo falso.",
     "meaning_reversed": "Evitar el desastre, miedo al colapso.",
     "number": 16, "id": 16},
    {"slug": "la-estrella", "name": "La Estrella",
     "meaning_upright": "Esperanza, inspiración, sanación, fe.",
     "meaning_reversed": "Desánimo, fe perdida, desconexión.",
     "number": 17, "id": 17},
    {"slug": "la-luna", "name": "La Luna",
     "meaning_upright": "Intuición, inconsciente, ilusión, miedo.",
     "meaning_reversed": "La confusión se disipa, verdad que emerge.",
     "number": 18, "id": 18},
    {"slug": "el-sol", "name": "El Sol",
     "meaning_upright": "Éxito, vitalidad, alegría, claridad.",
     "meaning_reversed": "Negatividad pasajera, ego, brillo opacado.",
     "number": 19, "id": 19},
    {"slug": "el-juicio", "name": "El Juicio",
     "meaning_upright": "Despertar, llamado interior, renovación, perdón.",
     "meaning_reversed": "Autocrítica, duda, ignorar el llamado.",
     "number": 20, "id": 20},
    {"slug": "el-mundo", "name": "El Mundo",
     "meaning_upright": "Culminación, plenitud, integración, logro.",
     "meaning_reversed": "Cierre pendiente, meta a medio camino.",
     "number": 21, "id": 21},
]


def _attr(card: Any, key: str, default: Any = None) -> Any:
    """Accede a un campo de card ya sea dict o modelo SQLAlchemy."""
    if isinstance(card, dict):
        return card.get(key, default)
    return getattr(card, key, default)


def draw_cards(deck: List[Any], *, count: int = 3,
               spread_type: str = "three_card") -> List[Dict[str, Any]]:
    """Sorteo genérico que devuelve el JSON sin guardar (compat con oracle.py).

    Mantiene exactamente la misma forma de salida que el servicio legacy
    (`TAROT_DECK`) para no romper consumidores antiguos.
    Acepta tanto dicts (deck estático legacy) como modelos SQLAlchemy.
    """
    positions = SPREAD_POSITIONS.get(spread_type)
    if positions is not None:
        count = len(positions)
    count = min(count, len(deck))

    chosen = random.sample(deck, count)
    result: List[Dict[str, Any]] = []
    for i, card in enumerate(chosen):
        upright = random.choice([True, False])
        meaning_upright = _attr(card, "meaning_upright", "")
        meaning_reversed = _attr(card, "meaning_reversed", "")
        meaning = meaning_upright if upright else meaning_reversed
        slug = _attr(card, "slug", "")
        number = _attr(card, "number", 0)
        title = _attr(card, "title_book_t") or slug.replace("-", " ").title()
        result.append({
            "id": number or 0,
            "slug": slug,
            "name": title,
            "position": positions[i] if positions else None,
            "drawn_upright": upright,
            "meaning_upright": meaning_upright,
            "meaning_reversed": meaning_reversed,
            "meaning": meaning,
        })
    return result


def draw_one(db: Session, *, reversed_chance: float = 0.5) -> TarotCardInDeck:
    """Sorteo de una sola carta del catálogo vivo (BD)."""
    card = random.choice(list_cards(db))
    reversed_ = random.random() < reversed_chance
    return _hydrate(card, position=None, reversed_=reversed_)


def draw_spread(db: Session, *, spread_type: str,
                reversed_chance: float = 0.5) -> List[TarotCardInDeck]:
    """Sorteo completo de un spread. La BD es la fuente de verdad; no
    necesita barajado externo porque la lista se vuelve a barajar cada vez.
    """
    if spread_type not in SPREAD_POSITIONS:
        raise ValueError(f"spread_type no soportado: {spread_type}")

    positions = SPREAD_POSITIONS[spread_type]
    pool = list_cards(db)
    chosen = random.sample(pool, len(positions))
    cards: List[TarotCardInDeck] = []
    for card, position in zip(chosen, positions):
        reversed_ = random.random() < reversed_chance
        cards.append(_hydrate(card, position=position, reversed_=reversed_))
    return cards


def save_reading(db: Session, *, user_id, spread_type: str, question: Optional[str],
                 cards: List[TarotCardInDeck], moon_phase: Optional[str] = None,
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
    """Construye el objeto resoluble a partir de la fila del catálogo."""
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
        position=position,
        reversed=reversed_,
        meaning=card.meaning_reversed if reversed_ else card.meaning_upright,
    )


def _card_id(card: TarotCard) -> int:
    """Identificador numérico estable para cards. Para menores usamos el
    campo legacy (22+wands...), pero el slug es la identidad hoy. Devuelve
    un ID sintético incremental: arcana, number si lo tiene, sino 0.
    """
    if card.number:
        return card.number
    return 0


def _display_name(card: TarotCard) -> str:
    """Nombre legible: si viniéramos con uno canónico lo usamos; si no,
    derivamos del slug."""
    # Reutilizamos title_book_t como segunda opción legible.
    return card.title_book_t or card.slug.replace("-", " ").title()
