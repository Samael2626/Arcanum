"""Adaptadores SQLAlchemy para los puertos de aplicacion.

Cada repositorio recibe Session en el constructor, hace queries contra
modelos ORM y convierte los resultados a entidades de dominio puras.
"""

from __future__ import annotations

import hashlib
from dataclasses import fields
from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.orm import Session, contains_eager, noload, selectinload

from app.core.config import settings
from app.core.security import create_access_token, create_refresh_token, get_password_hash, verify_password
from app.domain.entities import (
    DivinationSessionEntity,
    GrimoireEntryEntity,
    LibraryChapterEntity,
    LibraryParagraphEntity,
    LibraryWorkEntity,
    MateriaItemEntity,
    NatalChartEntity,
    OracleConversationEntity,
    ReadingBookmarkEntity,
    ReadingPosition,
    ReadingProgressEntity,
    RefreshTokenEntity,
    SavedPassageEntity,
    TarotCardEntity,
    TarotReadingEntity,
    TraditionEntity,
    UserEntity,
)
from app.models.divination_session import DivinationSession
from app.models.grimoire_entry import GrimoireEntry
from app.models.library import LibraryChapter, LibraryParagraph, LibraryWork
from app.models.materia_item import MateriaItem
from app.models.natal_chart import NatalChart
from app.models.oracle_conversation import OracleConversation
from app.models.reading import ReadingBookmark, ReadingProgress, SavedPassage
from app.models.refresh_token import RefreshToken
from app.models.tarot import TarotCard, TarotReading
from app.models.tradition import Tradition
from app.models.user import User
from app.schemas.refresh_token import TokenPair


# ── Helpers de conversion ─────────────────────────────────────────────────


def _to_entity(entity_cls, orm_row):
    """Mapea fila ORM → entidad de dominio por nombres de campo coincidentes."""
    if orm_row is None:
        return None
    kwargs = {}
    for f in fields(entity_cls):
        if hasattr(orm_row, f.name):
            kwargs[f.name] = getattr(orm_row, f.name)
    return entity_cls(**kwargs)


def _apply_to_orm(entity, orm_row):
    """Copia campos de entidad a fila ORM para atributos coincidentes."""
    for f in fields(entity):
        if hasattr(orm_row, f.name):
            setattr(orm_row, f.name, getattr(entity, f.name))
    return orm_row


_T = type | None


def _list_to_entities(entity_cls, orm_rows):
    return [_to_entity(entity_cls, r) for r in orm_rows]


# ── Auth ────────────────────────────────────────────────────────────────────


class UserRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_by_id(self, user_id: UUID) -> UserEntity | None:
        row = self._db.query(User).filter(User.id == user_id).first()
        return _to_entity(UserEntity, row)

    def get_by_email(self, email: str) -> UserEntity | None:
        row = self._db.query(User).filter(User.email == email).first()
        return _to_entity(UserEntity, row)

    def create(self, email: str, hashed_password: str, **kwargs) -> UserEntity:
        row = User(email=email, hashed_password=hashed_password, **kwargs)
        self._db.add(row)
        self._db.commit()
        self._db.refresh(row)
        return _to_entity(UserEntity, row)

    def save(self, user: UserEntity) -> UserEntity:
        row = self._db.query(User).filter(User.id == user.id).first()
        if not row:
            raise ValueError(f"User {user.id} not found")
        _apply_to_orm(user, row)
        self._db.commit()
        self._db.refresh(row)
        return _to_entity(UserEntity, row)

    def delete(self, user: UserEntity) -> None:
        row = self._db.query(User).filter(User.id == user.id).first()
        if row:
            self._db.delete(row)
            self._db.commit()


class RefreshTokenRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    @staticmethod
    def _hash(token: str) -> str:
        return hashlib.sha256(token.encode()).hexdigest()

    def create(self, user_id: UUID, token_hash: str, expires_at) -> RefreshTokenEntity:
        row = RefreshToken(user_id=user_id, token_hash=token_hash, expires_at=expires_at)
        self._db.add(row)
        self._db.commit()
        return _to_entity(RefreshTokenEntity, row)

    def get_by_hash(self, token_hash: str) -> RefreshTokenEntity | None:
        row = self._db.query(RefreshToken).filter(RefreshToken.token_hash == token_hash).first()
        return _to_entity(RefreshTokenEntity, row)

    def delete(self, token: RefreshTokenEntity) -> None:
        row = self._db.query(RefreshToken).filter(RefreshToken.id == token.id).first()
        if row:
            self._db.delete(row)
            self._db.commit()

    def delete_all_for_user(self, user_id: UUID) -> int:
        count = self._db.query(RefreshToken).filter(RefreshToken.user_id == user_id).delete()
        self._db.commit()
        return count


# ── Tarot ───────────────────────────────────────────────────────────────────


class TarotCardRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list(self, *, arcana: str | None = None, suit: str | None = None) -> list[TarotCardEntity]:
        q = self._db.query(TarotCard)
        if arcana:
            q = q.filter(TarotCard.arcana == arcana)
        if suit:
            q = q.filter(TarotCard.suit == suit)
        return _list_to_entities(TarotCardEntity, q.order_by(TarotCard.number, TarotCard.id).all())

    def get_by_slug(self, slug: str) -> TarotCardEntity | None:
        row = self._db.query(TarotCard).filter(TarotCard.slug == slug).first()
        return _to_entity(TarotCardEntity, row)

    def deck(self) -> list[TarotCardEntity]:
        return _list_to_entities(
            TarotCardEntity, self._db.query(TarotCard).order_by(TarotCard.number, TarotCard.id).all()
        )


class TarotReadingRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def create(
        self,
        user_id: UUID,
        spread_type: str,
        question: str | None,
        cards: list[dict],
        moon_phase: str | None = None,
        planetary_hour: str | None = None,
        commit: bool = True,
    ) -> TarotReadingEntity:
        """`commit=False` deja la escritura dentro de la transaccion del
        llamador: la ruta persiste el contenido y captura el consumo en un
        solo commit, de modo que un fallo posterior revierte ambos.
        """
        row = TarotReading(
            user_id=user_id,
            spread_type=spread_type,
            question=question,
            cards_drawn=cards,
            moon_phase=moon_phase,
            planetary_hour=planetary_hour,
        )
        self._db.add(row)
        if commit:
            self._db.commit()
        else:
            self._db.flush()
        self._db.refresh(row)
        return _to_entity(TarotReadingEntity, row)

    def list_by_user(self, user_id: UUID, *, limit: int = 20) -> list[TarotReadingEntity]:
        return _list_to_entities(
            TarotReadingEntity,
            self._db.query(TarotReading)
            .filter(TarotReading.user_id == user_id)
            .order_by(TarotReading.created_at.desc())
            .limit(limit)
            .all(),
        )


# ── Grimorio ────────────────────────────────────────────────────────────────


class GrimoireEntryRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list_by_user(self, user_id: UUID) -> list[GrimoireEntryEntity]:
        return _list_to_entities(
            GrimoireEntryEntity,
            self._db.query(GrimoireEntry)
            .filter(GrimoireEntry.user_id == user_id)
            .order_by(GrimoireEntry.entry_date.desc())
            .all(),
        )

    def get_owned(self, entry_id: UUID, user_id: UUID) -> GrimoireEntryEntity | None:
        row = (
            self._db.query(GrimoireEntry)
            .filter(GrimoireEntry.id == entry_id, GrimoireEntry.user_id == user_id)
            .first()
        )
        return _to_entity(GrimoireEntryEntity, row)

    def create(self, user_id: UUID, **data) -> GrimoireEntryEntity:
        row = GrimoireEntry(user_id=user_id, **data)
        self._db.add(row)
        self._db.commit()
        self._db.refresh(row)
        return _to_entity(GrimoireEntryEntity, row)

    def save(self, entry: GrimoireEntryEntity) -> GrimoireEntryEntity:
        row = self._db.query(GrimoireEntry).filter(GrimoireEntry.id == entry.id).first()
        if not row:
            raise ValueError(f"GrimoireEntry {entry.id} not found")
        _apply_to_orm(entry, row)
        self._db.commit()
        self._db.refresh(row)
        return _to_entity(GrimoireEntryEntity, row)

    def delete(self, entry: GrimoireEntryEntity) -> None:
        row = self._db.query(GrimoireEntry).filter(GrimoireEntry.id == entry.id).first()
        if row:
            self._db.delete(row)
            self._db.commit()


# ── Materia ─────────────────────────────────────────────────────────────────


class MateriaItemRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list(
        self,
        *,
        item_type: str | None = None,
        planet: str | None = None,
        element: str | None = None,
        name: str | None = None,
    ) -> list[MateriaItemEntity]:
        q = self._db.query(MateriaItem)
        if item_type:
            q = q.filter(MateriaItem.item_type == item_type)
        if planet:
            q = q.filter(MateriaItem.planet == planet)
        if element:
            q = q.filter(MateriaItem.element == element)
        if name:
            q = q.filter(MateriaItem.name.ilike(f"%{name}%"))
        return _list_to_entities(MateriaItemEntity, q.order_by(MateriaItem.name).all())

    def get_by_slug(self, slug: str) -> MateriaItemEntity | None:
        row = self._db.query(MateriaItem).filter(MateriaItem.slug == slug).first()
        return _to_entity(MateriaItemEntity, row)

    def create(self, **data) -> MateriaItemEntity:
        row = MateriaItem(**data)
        self._db.add(row)
        self._db.commit()
        self._db.refresh(row)
        return _to_entity(MateriaItemEntity, row)

    def update(self, item: MateriaItemEntity, **data) -> MateriaItemEntity:
        row = self._db.query(MateriaItem).filter(MateriaItem.id == item.id).first()
        if not row:
            raise ValueError(f"MateriaItem {item.id} not found")
        for field, value in data.items():
            setattr(row, field, value)
        self._db.commit()
        self._db.refresh(row)
        return _to_entity(MateriaItemEntity, row)

    def delete(self, item: MateriaItemEntity) -> None:
        row = self._db.query(MateriaItem).filter(MateriaItem.id == item.id).first()
        if row:
            self._db.delete(row)
            self._db.commit()


# ── Astral ──────────────────────────────────────────────────────────────────


class NatalChartRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_by_user_id(self, user_id: UUID) -> NatalChartEntity | None:
        row = self._db.query(NatalChart).filter(NatalChart.user_id == user_id).first()
        return _to_entity(NatalChartEntity, row)

    def create_or_update(self, user_id: UUID, chart_data: dict, house_system: str) -> NatalChartEntity:
        row = self._db.query(NatalChart).filter(NatalChart.user_id == user_id).first()
        if row:
            row.chart_data = chart_data
            row.house_system = house_system
        else:
            # calculated_at es NOT NULL sin default en la tabla: sin fijarlo
            # aqui, crear la primera carta natal revienta con NotNullViolation.
            row = NatalChart(
                user_id=user_id, chart_data=chart_data, house_system=house_system,
                calculated_at=datetime.now(timezone.utc),
            )
            self._db.add(row)
        self._db.commit()
        self._db.refresh(row)
        return _to_entity(NatalChartEntity, row)


# ── Biblioteca ──────────────────────────────────────────────────────────────


class LibraryWorkRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list_works(self) -> list[LibraryWorkEntity]:
        """Indice de obras con sus conteos, en UNA sola consulta.

        Los conteos salen agregados en SQL, no recorriendo capitulos y parrafos
        en Python: el indice es la primera pantalla de Lecturas y cargar el
        texto entero de Culpeper para contarlo seria absurdo.

        `translated_chapters` cuenta capitulos COMPLETAMENTE traducidos: uno con
        parrafos a medias no cuenta. Un capitulo a medias abierto desde el
        indice enseña huecos en castellano, y prometerlo como traducido es peor
        que no anunciarlo. Un capitulo sin parrafos tampoco cuenta: no hay nada
        traducido en el.
        """
        translated = func.count(LibraryParagraph.id).filter(
            LibraryParagraph.text_es.isnot(None),
            func.btrim(LibraryParagraph.text_es) != "",
        )
        per_chapter = (
            select(
                LibraryChapter.id.label("chapter_id"),
                LibraryChapter.work_id.label("work_id"),
                func.count(LibraryParagraph.id).label("total"),
                translated.label("translated"),
            )
            .select_from(LibraryChapter)
            .outerjoin(LibraryParagraph, LibraryParagraph.chapter_id == LibraryChapter.id)
            .group_by(LibraryChapter.id, LibraryChapter.work_id)
            .subquery()
        )
        rows = self._db.execute(
            select(
                LibraryWork,
                func.count(per_chapter.c.chapter_id).label("chapter_count"),
                func.count(per_chapter.c.chapter_id)
                .filter(
                    per_chapter.c.total > 0,
                    per_chapter.c.total == per_chapter.c.translated,
                )
                .label("translated_chapters"),
            )
            .outerjoin(per_chapter, per_chapter.c.work_id == LibraryWork.id)
            .group_by(LibraryWork.id)
            .order_by(LibraryWork.author, LibraryWork.title)
            # Sin esto el mapeo a entidad lee `row.chapters` y dispara un SELECT
            # de capitulos por obra: el N+1 clasico, invisible hasta que la
            # biblioteca crece. El indice no muestra capitulos.
            .options(noload(LibraryWork.chapters))
        ).all()

        works: list[LibraryWorkEntity] = []
        for row, chapter_count, translated_chapters in rows:
            work = _to_entity(LibraryWorkEntity, row)
            work.chapter_count = chapter_count
            work.translated_chapters = translated_chapters
            works.append(work)
        return works

    def get_by_slug(self, slug: str) -> LibraryWorkEntity | None:
        row = (
            self._db.query(LibraryWork)
            .options(selectinload(LibraryWork.chapters).selectinload(LibraryChapter.paragraphs))
            .filter(LibraryWork.slug == slug)
            .first()
        )
        if row is None:
            return None
        work = _to_entity(LibraryWorkEntity, row)
        work.chapters = [_to_entity(LibraryChapterEntity, ch) for ch in row.chapters]
        for ch_entity, ch_row in zip(work.chapters, row.chapters):
            ch_entity.paragraphs = _list_to_entities(LibraryParagraphEntity, ch_row.paragraphs)
        return work

    # Solo la cabecera de la obra viaja con el capitulo. Se declara aparte para
    # que get_chapter y get_bridge_chapter no puedan divergir: las dos rutas
    # sirven la misma cabecera y un campo nuevo se añade en un unico sitio.
    _WORK_HEADER = (
        # contains_eager aprovecha el JOIN que la consulta ya hace: la obra
        # llega en la MISMA fila, sin consulta extra. noload sobre chapters
        # cierra la puerta al N+1: nadie que toque row.work.chapters va a
        # arrastrar los 423 capitulos de Culpeper detras de un solo capitulo.
        contains_eager(LibraryChapter.work).noload(LibraryWork.chapters),
        selectinload(LibraryChapter.paragraphs),
    )

    @staticmethod
    def _chapter_with_work(row) -> LibraryChapterEntity:
        """Fila ORM → entidad, con parrafos y cabecera de obra ya resueltos."""
        ch = _to_entity(LibraryChapterEntity, row)
        ch.paragraphs = _list_to_entities(LibraryParagraphEntity, row.paragraphs)
        work = row.work
        ch.work_slug = work.slug
        ch.work_title = work.title
        ch.work_author = work.author
        ch.work_year = work.year
        ch.work_advisory = work.advisory
        return ch

    def get_chapter(self, work_slug: str, chapter_slug: str) -> LibraryChapterEntity | None:
        row = (
            self._db.query(LibraryChapter)
            .join(LibraryChapter.work)
            .options(*self._WORK_HEADER)
            .filter(LibraryWork.slug == work_slug, LibraryChapter.slug == chapter_slug)
            .first()
        )
        if row is None:
            return None
        return self._chapter_with_work(row)

    def get_chapters(self, work_slug: str, kind: str | None = None) -> list[LibraryChapterEntity]:
        query = (
            self._db.query(LibraryChapter)
            .join(LibraryWork)
            .options(selectinload(LibraryChapter.paragraphs))
            .filter(LibraryWork.slug == work_slug)
            .order_by(LibraryChapter.position)
        )
        if kind:
            query = query.filter(LibraryChapter.kind == kind)
        return _list_to_entities(LibraryChapterEntity, query.all())

    def get_bridge_chapter(self, materia_slug: str) -> LibraryChapterEntity | None:
        row = (
            self._db.query(LibraryChapter)
            .join(LibraryChapter.work)
            .options(*self._WORK_HEADER)
            .filter(LibraryChapter.meta["materia_slug"].as_string() == materia_slug)
            .first()
        )
        if row is None:
            return None
        return self._chapter_with_work(row)


# ── Oracle ──────────────────────────────────────────────────────────────────


class DivinationSessionRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_owned(self, session_id: UUID, user_id: UUID) -> DivinationSessionEntity | None:
        row = (
            self._db.query(DivinationSession)
            .filter(DivinationSession.id == session_id, DivinationSession.user_id == user_id)
            .first()
        )
        return _to_entity(DivinationSessionEntity, row)

    def create(self, user_id: UUID, commit: bool = True, **data) -> DivinationSessionEntity:
        """`commit=False` deja la escritura dentro de la transaccion del
        llamador: la ruta persiste el contenido y captura el consumo en un
        solo commit, de modo que un fallo posterior revierte ambos.
        """
        row = DivinationSession(user_id=user_id, **data)
        self._db.add(row)
        if commit:
            self._db.commit()
        else:
            self._db.flush()
        self._db.refresh(row)
        return _to_entity(DivinationSessionEntity, row)


class OracleConversationRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_by_user_id(self, user_id: UUID) -> OracleConversationEntity | None:
        row = (
            self._db.query(OracleConversation)
            .filter(OracleConversation.user_id == user_id)
            .order_by(OracleConversation.created_at.desc())
            .first()
        )
        return _to_entity(OracleConversationEntity, row)

    def create_or_update(
        self, user_id: UUID, messages: list[dict], tradition_context: str | None,
        commit: bool = True,
    ) -> OracleConversationEntity:
        """`commit=False` deja la escritura dentro de la transaccion del
        llamador: la ruta persiste el contenido y captura el consumo en un
        solo commit, de modo que un fallo posterior revierte ambos.
        """
        row = OracleConversation(
            user_id=user_id,
            messages=messages,
            tradition_context=tradition_context,
        )
        self._db.add(row)
        if commit:
            self._db.commit()
        else:
            self._db.flush()
        self._db.refresh(row)
        return _to_entity(OracleConversationEntity, row)


# ── Tradiciones ─────────────────────────────────────────────────────────────


class TraditionRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list(self, *, category: str | None = None, language: str = "es") -> list[TraditionEntity]:
        q = self._db.query(Tradition)
        if category:
            q = q.filter(Tradition.category == category)
        if language:
            q = q.filter(Tradition.language == language)
        return _list_to_entities(TraditionEntity, q.order_by(Tradition.display_order).all())

    def get_by_slug(self, slug: str) -> TraditionEntity | None:
        row = self._db.query(Tradition).filter(Tradition.slug == slug).first()
        return _to_entity(TraditionEntity, row)


# ── Biblioteca personal ─────────────────────────────────────────────────────


def _position_of(row) -> ReadingPosition:
    return ReadingPosition(
        work_slug=row.work_slug,
        chapter_slug=row.chapter_slug,
        paragraph_anchor=row.paragraph_anchor,
        fragment_index=row.fragment_index,
    )


class ReadingProgressRepository:
    """Donde se quedo el usuario en cada obra."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def get(self, user_id: UUID, work_slug: str) -> ReadingProgressEntity | None:
        row = (
            self._db.query(ReadingProgress)
            .filter(ReadingProgress.user_id == user_id, ReadingProgress.work_slug == work_slug)
            .first()
        )
        return None if row is None else self._to_entity(row)

    def list_by_user(self, user_id: UUID) -> list[ReadingProgressEntity]:
        rows = (
            self._db.query(ReadingProgress)
            .filter(ReadingProgress.user_id == user_id)
            .order_by(ReadingProgress.updated_at.desc())
            .all()
        )
        return [self._to_entity(r) for r in rows]

    def upsert(
        self, user_id: UUID, position: ReadingPosition, language: str
    ) -> ReadingProgressEntity:
        """Guarda la posicion viva, creandola o pisando la anterior.

        Se hace con ON CONFLICT y no con "buscar y decidir": el lector guarda
        en cada cambio de pagina, y dos peticiones cercanas (pasar pagina y
        salir de la app) pueden solaparse. Un SELECT seguido de INSERT dejaria
        una ventana en la que las dos creen que no hay fila y la segunda
        reventaria contra la restriccion unica. Aqui el conflicto es el camino
        normal, no un error.
        """
        stmt = (
            pg_insert(ReadingProgress)
            .values(
                user_id=user_id,
                work_slug=position.work_slug,
                chapter_slug=position.chapter_slug,
                paragraph_anchor=position.paragraph_anchor,
                fragment_index=position.fragment_index,
                language=language,
            )
            .on_conflict_do_update(
                constraint="uq_reading_progress_user_work",
                set_={
                    "chapter_slug": position.chapter_slug,
                    "paragraph_anchor": position.paragraph_anchor,
                    "fragment_index": position.fragment_index,
                    "language": language,
                    "updated_at": func.now(),
                },
            )
            .returning(ReadingProgress)
        )
        row = self._db.execute(stmt).scalar_one()
        self._db.commit()
        return self._to_entity(row)

    @staticmethod
    def _to_entity(row) -> ReadingProgressEntity:
        return ReadingProgressEntity(
            id=row.id,
            user_id=row.user_id,
            position=_position_of(row),
            language=row.language,
            created_at=row.created_at,
            updated_at=row.updated_at,
        )


class ReadingBookmarkRepository:
    """Marcadores manuales. No tocan el progreso automatico."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def list_by_user(
        self, user_id: UUID, work_slug: str | None = None
    ) -> list[ReadingBookmarkEntity]:
        q = self._db.query(ReadingBookmark).filter(ReadingBookmark.user_id == user_id)
        if work_slug:
            q = q.filter(ReadingBookmark.work_slug == work_slug)
        rows = q.order_by(ReadingBookmark.created_at.desc()).all()
        return [self._to_entity(r) for r in rows]

    def get_owned(self, bookmark_id: UUID, user_id: UUID) -> ReadingBookmarkEntity | None:
        """Filtra por duenno EN LA CONSULTA.

        Nunca "buscar por id y comparar despues": ese patron acaba filtrando
        filas ajenas el dia que alguien olvide el if.
        """
        row = (
            self._db.query(ReadingBookmark)
            .filter(ReadingBookmark.id == bookmark_id, ReadingBookmark.user_id == user_id)
            .first()
        )
        return None if row is None else self._to_entity(row)

    def create(
        self, user_id: UUID, position: ReadingPosition, label: str | None
    ) -> ReadingBookmarkEntity | None:
        """Devuelve None si ya existe un marcador en esa posicion."""
        if self._at_position(user_id, position) is not None:
            return None
        row = ReadingBookmark(
            user_id=user_id,
            work_slug=position.work_slug,
            chapter_slug=position.chapter_slug,
            paragraph_anchor=position.paragraph_anchor,
            fragment_index=position.fragment_index,
            label=label,
        )
        self._db.add(row)
        self._db.commit()
        self._db.refresh(row)
        return self._to_entity(row)

    def delete(self, bookmark_id: UUID, user_id: UUID) -> bool:
        deleted = (
            self._db.query(ReadingBookmark)
            .filter(ReadingBookmark.id == bookmark_id, ReadingBookmark.user_id == user_id)
            .delete()
        )
        self._db.commit()
        return bool(deleted)

    def _at_position(self, user_id: UUID, position: ReadingPosition):
        return (
            self._db.query(ReadingBookmark)
            .filter(
                ReadingBookmark.user_id == user_id,
                ReadingBookmark.work_slug == position.work_slug,
                ReadingBookmark.chapter_slug == position.chapter_slug,
                ReadingBookmark.paragraph_anchor == position.paragraph_anchor,
                ReadingBookmark.fragment_index == position.fragment_index,
            )
            .first()
        )

    @staticmethod
    def _to_entity(row) -> ReadingBookmarkEntity:
        return ReadingBookmarkEntity(
            id=row.id,
            user_id=row.user_id,
            position=_position_of(row),
            label=row.label,
            created_at=row.created_at,
        )


class SavedPassageRepository:
    """Pasajes guardados con nota cifrada. Es lo que lista el Grimorio."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def list_by_user(self, user_id: UUID, work_slug: str | None = None) -> list[SavedPassageEntity]:
        q = self._db.query(SavedPassage).filter(SavedPassage.user_id == user_id)
        if work_slug:
            q = q.filter(SavedPassage.work_slug == work_slug)
        rows = q.order_by(SavedPassage.created_at.desc()).all()
        return [self._to_entity(r) for r in rows]

    def get_owned(self, passage_id: UUID, user_id: UUID) -> SavedPassageEntity | None:
        row = self._row_owned(passage_id, user_id)
        return None if row is None else self._to_entity(row)

    def create(
        self,
        user_id: UUID,
        position: ReadingPosition,
        quote_text: str,
        quote_language: str,
        encrypted_note: str | None,
        note_iv: str | None,
    ) -> SavedPassageEntity | None:
        """Devuelve None si ese pasaje ya estaba guardado."""
        if self._at_position(user_id, position) is not None:
            return None
        row = SavedPassage(
            user_id=user_id,
            work_slug=position.work_slug,
            chapter_slug=position.chapter_slug,
            paragraph_anchor=position.paragraph_anchor,
            fragment_index=position.fragment_index,
            quote_text=quote_text,
            quote_language=quote_language,
            encrypted_note=encrypted_note,
            note_iv=note_iv,
        )
        self._db.add(row)
        self._db.commit()
        self._db.refresh(row)
        return self._to_entity(row)

    def set_note(
        self, passage_id: UUID, user_id: UUID, encrypted_note: str | None, note_iv: str | None
    ) -> SavedPassageEntity | None:
        """Sustituye la nota cifrada. Ambos en None la borra."""
        row = self._row_owned(passage_id, user_id)
        if row is None:
            return None
        row.encrypted_note = encrypted_note
        row.note_iv = note_iv
        row.updated_at = datetime.now(timezone.utc)
        self._db.commit()
        self._db.refresh(row)
        return self._to_entity(row)

    def delete(self, passage_id: UUID, user_id: UUID) -> bool:
        deleted = (
            self._db.query(SavedPassage)
            .filter(SavedPassage.id == passage_id, SavedPassage.user_id == user_id)
            .delete()
        )
        self._db.commit()
        return bool(deleted)

    def _at_position(self, user_id: UUID, position: ReadingPosition):
        return (
            self._db.query(SavedPassage)
            .filter(
                SavedPassage.user_id == user_id,
                SavedPassage.work_slug == position.work_slug,
                SavedPassage.chapter_slug == position.chapter_slug,
                SavedPassage.paragraph_anchor == position.paragraph_anchor,
                SavedPassage.fragment_index == position.fragment_index,
            )
            .first()
        )

    def _row_owned(self, passage_id: UUID, user_id: UUID):
        return (
            self._db.query(SavedPassage)
            .filter(SavedPassage.id == passage_id, SavedPassage.user_id == user_id)
            .first()
        )

    @staticmethod
    def _to_entity(row) -> SavedPassageEntity:
        return SavedPassageEntity(
            id=row.id,
            user_id=row.user_id,
            position=_position_of(row),
            quote_text=row.quote_text,
            quote_language=row.quote_language,
            encrypted_note=row.encrypted_note,
            note_iv=row.note_iv,
            created_at=row.created_at,
            updated_at=row.updated_at,
        )
