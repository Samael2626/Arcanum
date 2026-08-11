"""GET /library contra PostgreSQL real: conteos correctos y sin N+1.

Regresion del 500 en produccion: `WorkSummary` exige `chapter_count` y
`translated_chapters`, y `list_works()` devolvia la entidad sin ellos.
"""
import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import event, text

from app.adapters.repositories import LibraryWorkRepository
from app.db.session import get_db
from app.main import app


@pytest.fixture
def seeded(engine):
    """Tres obras que cubren los casos de la semantica de traduccion.

    - completa:  2 capitulos, todos los parrafos con text_es      -> 2 de 2
    - a-medias:  1 capitulo traducido entero + 1 capitulo parcial -> 1 de 2
    - vacia:     sin capitulos                                    -> 0 de 0
    """
    ids = {}
    with engine.begin() as c:
        c.execute(text("DELETE FROM library_works"))

        def work(slug, title, author, year):
            wid = uuid.uuid4()
            c.execute(text("""
                INSERT INTO library_works (id, slug, title, author, year, language, license_note)
                VALUES (:id, :slug, :title, :author, :year, 'en', 'dominio publico')
            """), {"id": wid, "slug": slug, "title": title, "author": author, "year": year})
            ids[slug] = wid
            return wid

        def chapter(wid, slug, position):
            cid = uuid.uuid4()
            c.execute(text("""
                INSERT INTO library_chapters (id, work_id, slug, title, kind, position)
                VALUES (:id, :w, :slug, :title, 'herb', :pos)
            """), {"id": cid, "w": wid, "slug": slug, "title": slug, "pos": position})
            return cid

        def para(cid, position, es):
            c.execute(text("""
                INSERT INTO library_paragraphs
                    (id, chapter_id, anchor, position, text_original, text_es, translation_status)
                VALUES (:id, :c, :anchor, :pos, 'original text', :es, :st)
            """), {"id": uuid.uuid4(), "c": cid, "anchor": str(uuid.uuid4()),
                   "pos": position, "es": es, "st": "machine" if es else None})

        w1 = work("completa", "Obra completa", "Autor A", 1653)
        for ch_i in (1, 2):
            cid = chapter(w1, f"cap-{ch_i}", ch_i)
            for p in (1, 2):
                para(cid, p, "traducido")

        w2 = work("a-medias", "Obra a medias", "Autor B", 1621)
        cid_full = chapter(w2, "cap-entero", 1)
        para(cid_full, 1, "traducido")
        cid_partial = chapter(w2, "cap-parcial", 2)
        para(cid_partial, 1, "traducido")
        para(cid_partial, 2, None)          # sin traducir
        para(cid_partial, 3, "   ")         # en blanco: tampoco cuenta

        work("vacia", "Obra sin capitulos", "Autor C", None)

    yield ids

    with engine.begin() as c:
        c.execute(text("DELETE FROM library_works"))


@pytest.fixture
def client(engine, seeded):
    from sqlalchemy.orm import sessionmaker

    Session = sessionmaker(bind=engine)

    def override():
        db = Session()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override
    yield TestClient(app)
    app.dependency_overrides.pop(get_db, None)


def test_get_library_responde_200_con_ambos_enteros(client):
    resp = client.get("/library")
    assert resp.status_code == 200, resp.text
    works = {w["slug"]: w for w in resp.json()}
    assert set(works) == {"completa", "a-medias", "vacia"}
    for slug, w in works.items():
        assert isinstance(w["chapter_count"], int), slug
        assert isinstance(w["translated_chapters"], int), slug


def test_los_conteos_son_reales_y_lo_parcial_no_cuenta(client):
    works = {w["slug"]: w for w in client.get("/library").json()}

    assert works["completa"]["chapter_count"] == 2
    assert works["completa"]["translated_chapters"] == 2

    # El capitulo con un parrafo sin traducir y otro en blanco NO cuenta:
    # anunciarlo como traducido seria una promesa falsa al lector.
    assert works["a-medias"]["chapter_count"] == 2
    assert works["a-medias"]["translated_chapters"] == 1

    # Sin capitulos no hay nada traducido, y el cero aqui es real, no un relleno.
    assert works["vacia"]["chapter_count"] == 0
    assert works["vacia"]["translated_chapters"] == 0


def test_el_indice_va_en_una_sola_consulta(db, seeded):
    """Sin N+1: el coste no crece con obras, capitulos ni parrafos."""
    statements = []
    engine = db.get_bind()

    @event.listens_for(engine, "before_cursor_execute")
    def record(conn, cursor, statement, parameters, context, executemany):
        statements.append(statement)

    try:
        works = LibraryWorkRepository(db).list_works()
    finally:
        event.remove(engine, "before_cursor_execute", record)

    assert len(works) == 3
    selects = [s for s in statements if s.lstrip().upper().startswith("SELECT")]
    assert len(selects) == 1, f"{len(selects)} consultas: {selects}"


def test_la_entidad_no_finge_ceros_si_nadie_calcula_los_conteos():
    """Un camino que olvide los conteos debe romper, no mentir con 0."""
    from app.domain.entities import LibraryWorkEntity

    bare = LibraryWorkEntity(id=uuid.uuid4(), slug="x", title="t", author="a")
    assert bare.chapter_count is None
    assert bare.translated_chapters is None
