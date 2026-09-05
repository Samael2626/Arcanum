"""Entidades de dominio puras — sin rastro de ORM, Pydantic ni infraestructura."""

from __future__ import annotations
from dataclasses import dataclass, field
from datetime import date, datetime
from uuid import UUID


@dataclass
class UserEntity:
    id: UUID
    email: str
    hashed_password: str
    display_name: str | None = None
    birth_date: datetime | None = None
    birth_time: datetime | None = None
    birth_lat: str | None = None
    birth_lon: str | None = None
    birth_city: str | None = None
    birth_timezone: str | None = None
    # Residencia. Vacia = vive donde nacio; ver app/services/user_sky.py.
    current_lat: str | None = None
    current_lon: str | None = None
    current_city: str | None = None
    current_timezone: str | None = None
    subscription_tier: str = "free"
    subscription_expires_at: datetime | None = None
    revenuecat_customer_id: str | None = None
    preferred_tradition: str | None = None
    preferred_house_system: str = "placidus"
    onboarding_completed: bool = False
    created_at: datetime | None = None
    updated_at: datetime | None = None


@dataclass
class RefreshTokenEntity:
    id: UUID
    user_id: UUID
    token_hash: str
    expires_at: datetime
    created_at: datetime | None = None


@dataclass
class TarotCardEntity:
    id: UUID
    slug: str
    arcana: str
    suit: str | None = None
    number: int | None = None
    element: str | None = None
    sephirah: str | None = None
    decan: str | None = None
    zodiac: str | None = None
    title_book_t: str | None = None
    name_es: str | None = None
    hebrew_letter: str | None = None
    gematria_value: int | None = None
    astro_correspondence: str | None = None
    path_number: int | None = None
    path_from: str | None = None
    path_to: str | None = None
    meaning_upright: str = ""
    meaning_reversed: str = ""
    lang: str = "es"
    created_at: datetime | None = None


@dataclass
class TarotReadingEntity:
    id: UUID
    user_id: UUID
    spread_type: str
    question: str | None = None
    cards_drawn: list[dict] | None = None
    moon_phase: str | None = None
    planetary_hour: str | None = None
    created_at: datetime | None = None


@dataclass
class GrimoireEntryEntity:
    id: UUID
    user_id: UUID
    entry_type: str
    title: str
    encrypted_content: str
    content_iv: str
    moon_phase: str | None = None
    moon_sign: str | None = None
    planetary_hour: str | None = None
    day_planet: str | None = None
    tradition: str | None = None
    tags: list[str] | None = None
    entry_date: datetime | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


@dataclass
class MateriaItemEntity:
    id: UUID
    slug: str
    item_type: str
    name: str
    aliases: list[str] | None = None
    planet: str | None = None
    element: str | None = None
    properties: dict | None = None
    language: str = "es"


@dataclass
class NatalChartEntity:
    id: UUID
    user_id: UUID
    chart_data: dict | None = None
    house_system: str = "placidus"
    calculated_at: datetime | None = None


@dataclass
class LibraryWorkEntity:
    id: UUID
    slug: str
    title: str
    author: str
    year: int | None = None
    language: str = "en"
    source_url: str | None = None
    license_note: str = ""
    advisory: str | None = None
    chapters: list[LibraryChapterEntity] | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
    # Conteos del indice, resueltos con agregacion SQL en list_works. Nacen en
    # None a proposito: un 0 por defecto disfrazaria de "obra vacia" cualquier
    # camino que olvide calcularlos, que es justo el fallo que rompio /library.
    chapter_count: int | None = None
    translated_chapters: int | None = None


@dataclass
class LibraryChapterEntity:
    id: UUID
    work_id: UUID
    slug: str
    title: str
    kind: str = "text"
    position: int = 0
    meta: dict | None = None
    paragraphs: list[LibraryParagraphEntity] | None = None
    # Datos de la obra que viajan CON el capitulo. La entidad no expone la
    # relacion ORM `work`: si lo hiciera, cualquiera que leyese
    # `chapter.work.algo` estaria disparando una consulta a espaldas del
    # repositorio, y el router lo hacia contra un atributo inexistente (500 en
    # todo /library/{obra}/{capitulo}). Solo lo minimo que necesitan
    # ChapterDetail y MateriaBridge, nunca la obra entera con sus capitulos.
    #
    # Nacen en None: solo los pueblan las consultas de detalle. Un indice que
    # no los resuelve deja el hueco visible en vez de inventarse una obra.
    work_slug: str | None = None
    work_title: str | None = None
    work_author: str | None = None
    work_year: int | None = None
    work_advisory: str | None = None


@dataclass
class LibraryParagraphEntity:
    id: UUID
    chapter_id: UUID
    anchor: str
    position: int = 0
    text_original: str = ""
    text_es: str | None = None
    translation_status: str | None = None


@dataclass
class DivinationSessionEntity:
    id: UUID
    user_id: UUID
    system: str
    spread_type: str | None = None
    cards_drawn: list[dict] | None = None
    encrypted_question: str | None = None
    question_iv: str | None = None
    moon_phase: str | None = None
    planetary_hour: str | None = None
    session_date: datetime | None = None


@dataclass
class HoroscopeReadingEntity:
    id: UUID
    user_id: UUID
    local_date: date
    text: str
    generated_at: datetime | None = None
    # Puede faltar, y puede venir a medias: las lecturas de antes de que el
    # motor aprendiera la profeccion o los ingresos no los traen.
    sky: dict | None = None


@dataclass
class OracleConversationEntity:
    id: UUID
    user_id: UUID
    messages: list[dict] | None = None
    tradition_context: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


@dataclass
class TraditionEntity:
    id: UUID
    slug: str
    name: str
    category: str
    short_description: str | None = None
    content: dict | None = None
    is_premium: bool = True
    language: str = "es"
    display_order: int = 0


# ── Biblioteca personal ─────────────────────────────────────────────────────


@dataclass(frozen=True)
class ReadingPosition:
    """Posicion estable dentro de una obra.

    Deliberadamente NO existe un campo "pagina": la paginacion depende del
    tamano de letra, del idioma y de la pantalla, asi que guardarla equivaldria
    a guardar una posicion que no significa lo mismo dos veces seguidas. Estas
    cuatro coordenadas sobreviven a un cambio de tipografia, de idioma y de
    dispositivo, y el cliente reconstruye con ellas la pagina visual.

    Es inmutable porque una posicion guardada no se edita: se sustituye.
    """

    work_slug: str
    chapter_slug: str
    paragraph_anchor: str
    fragment_index: int = 0


@dataclass
class ReadingProgressEntity:
    id: UUID
    user_id: UUID
    position: ReadingPosition
    language: str = "es"
    created_at: datetime | None = None
    updated_at: datetime | None = None


@dataclass
class ReadingBookmarkEntity:
    id: UUID
    user_id: UUID
    position: ReadingPosition
    label: str | None = None
    created_at: datetime | None = None


@dataclass
class SavedPassageEntity:
    id: UUID
    user_id: UUID
    position: ReadingPosition
    quote_text: str
    quote_language: str = "es"
    # Nota personal cifrada en el cliente. El servidor no tiene la clave y no
    # existe variante en claro: si algun dia aparece un campo `note` aqui, es
    # que alguien rompio la promesa del Grimorio.
    encrypted_note: str | None = None
    note_iv: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
