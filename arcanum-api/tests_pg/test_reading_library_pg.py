"""Biblioteca personal contra el esquema REAL de Alembic.

`tests/` construye las tablas con `Base.metadata.create_all`, que lee los
modelos. Si la migracion 007 y `app/models/reading.py` se separan, aquella
suite sigue verde y produccion revienta: es exactamente el modo de fallo que ya
tumbo /library una vez. Aqui el esquema lo hace Alembic, como en produccion.
"""
import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import inspect, text
from sqlalchemy.orm import sessionmaker

from app.db.session import get_db
from app.main import app

WORK = "culpeper-complete-herbal"
CHAPTER = "amara-dulcis"
ANCHOR = f"{WORK}.{CHAPTER}.1"
CIPHERTEXT = "bm90YSBjaWZyYWRhIGRlIHBydWViYQ=="
IV = "YWJjZGVmZ2hpamtsbW5vcA=="


@pytest.fixture
def seeded(engine):
    with engine.begin() as c:
        c.execute(text("DELETE FROM library_works"))
        wid, cid = uuid.uuid4(), uuid.uuid4()
        c.execute(text("""
            INSERT INTO library_works (id, slug, title, author, year, language, license_note)
            VALUES (:id, :slug, 'The Complete Herbal', 'Nicholas Culpeper', 1653, 'en', 'dp')
        """), {"id": wid, "slug": WORK})
        c.execute(text("""
            INSERT INTO library_chapters (id, work_id, slug, title, kind, position)
            VALUES (:id, :w, :slug, 'Amara Dulcis', 'herb', 1)
        """), {"id": cid, "w": wid, "slug": CHAPTER})
        c.execute(text("""
            INSERT INTO library_paragraphs (id, chapter_id, anchor, position, text_original)
            VALUES (:id, :c, :anchor, 1, 'It is under the planet Mercury.')
        """), {"id": uuid.uuid4(), "c": cid, "anchor": ANCHOR})
    yield
    with engine.begin() as c:
        c.execute(text("DELETE FROM library_works"))


@pytest.fixture
def client(engine, seeded):
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


def _auth(engine):
    """Usuario real + token firmado, sin pasar por /auth.

    El registro esta limitado a 5 por hora y por IP, y ese contador vive en
    Redis fuera del proceso: pasando por el borde de auth, esta suite empezaria
    a fallar sola a la tercera ejecucion del dia. Lo que se prueba aqui es el
    esquema de Alembic, no el alta de usuarios, que tiene sus propios tests.
    """
    from app.core.security import create_access_token

    uid = uuid.uuid4()
    email = f"{uid}@arcanum.com"
    with engine.begin() as c:
        c.execute(text("""
            INSERT INTO users (id, email, hashed_password, display_name)
            VALUES (:id, :email, 'x', 'Lectora')
        """), {"id": uid, "email": email})
    return {"Authorization": f"Bearer {create_access_token({'sub': email})}"}


def _position():
    return {
        "work_slug": WORK,
        "chapter_slug": CHAPTER,
        "paragraph_anchor": ANCHOR,
        "fragment_index": 0,
    }


def test_el_esquema_de_alembic_trae_las_tres_tablas(engine):
    tablas = set(inspect(engine).get_table_names())
    assert {"reading_progress", "reading_bookmarks", "saved_passages"} <= tablas


def test_las_restricciones_criticas_existen_en_el_esquema_real(engine):
    """Las garantias no pueden vivir solo en los modelos de Python.

    La unicidad del progreso es lo que hace idempotente el upsert, y el par
    nota/IV es lo que impide guardar una nota indescifrable. Si la migracion no
    los creo, produccion no los tiene por mucho que el modelo los declare.
    """
    inspector = inspect(engine)

    unicas = {u["name"] for u in inspector.get_unique_constraints("reading_progress")}
    assert "uq_reading_progress_user_work" in unicas

    for tabla, nombre in [
        ("reading_bookmarks", "uq_reading_bookmark_position"),
        ("saved_passages", "uq_saved_passage_position"),
    ]:
        assert nombre in {u["name"] for u in inspector.get_unique_constraints(tabla)}, tabla

    checks = {c["name"] for c in inspector.get_check_constraints("saved_passages")}
    assert "ck_saved_passage_note_pair" in checks


def test_el_progreso_es_idempotente_contra_la_base_real(client, engine):
    headers = _auth(engine)
    body = {"position": _position(), "language": "es"}

    first = client.put("/reading/progress", json=body, headers=headers)
    second = client.put("/reading/progress", json=body, headers=headers)

    assert first.status_code == 200, first.text
    assert second.status_code == 200, second.text
    # El ON CONFLICT hace su trabajo: dos guardados seguidos no chocan contra
    # la restriccion unica ni crean una segunda fila.
    assert first.json()["id"] == second.json()["id"]
    assert len(client.get("/reading/progress", headers=headers).json()) == 1


def test_la_nota_llega_cifrada_a_la_tabla_real(client, engine):
    headers = _auth(engine)

    creado = client.post(
        "/reading/passages",
        json={"position": _position(), "quote_text": "It is under the planet Mercury.",
              "quote_language": "en", "encrypted_note": CIPHERTEXT, "note_iv": IV},
        headers=headers,
    )
    assert creado.status_code == 201, creado.text

    with engine.connect() as c:
        fila = c.execute(
            text("SELECT encrypted_note, note_iv FROM saved_passages WHERE id = :id"),
            {"id": creado.json()["id"]},
        ).one()
    assert fila.encrypted_note == CIPHERTEXT
    assert fila.note_iv == IV


def test_la_base_rechaza_una_nota_sin_iv(engine):
    """El CHECK es la ultima linea: aunque alguien saltase el schema Pydantic."""
    from sqlalchemy.exc import IntegrityError

    with engine.begin() as c:
        uid = uuid.uuid4()
        c.execute(text("""
            INSERT INTO users (id, email, hashed_password, display_name)
            VALUES (:id, :email, 'x', 'Test')
        """), {"id": uid, "email": f"{uid}@test.local"})

    with pytest.raises(IntegrityError):
        with engine.begin() as c:
            c.execute(text("""
                INSERT INTO saved_passages
                    (user_id, work_slug, chapter_slug, paragraph_anchor, quote_text,
                     encrypted_note, note_iv)
                VALUES (:u, :w, :ch, :a, 'cita', 'cifrado', NULL)
            """), {"u": uid, "w": WORK, "ch": CHAPTER, "a": ANCHOR})
