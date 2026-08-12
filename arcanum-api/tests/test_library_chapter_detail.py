"""Detalle de capitulo: el 500 de `GET /library/{obra}/{capitulo}`.

El router leia `chapter.work.slug` sobre una LibraryChapterEntity que nunca
tuvo campo `work`: el repositorio convierte ORM -> entidad y ahi se perdia la
relacion. AttributeError -> 500 en TODOS los capitulos, con el indice cargando
bien, que es justo lo que se vio en produccion con Amara Dulcis.

Se prueba contra el endpoint y no solo contra el repositorio: el fallo vivia en
la costura entre los dos, y un test de repositorio a solas lo habria dejado
pasar.
"""
import uuid

import pytest
from sqlalchemy import event, text

from app.adapters.repositories import LibraryWorkRepository

WORK = "culpeper-complete-herbal"
ADVISORY = "Documento historico: no es consejo medico."
# El primer capitulo real de la obra, el que el indice ofrece arriba del todo.
FIRST = "a-catalogue-of-simples"
# Bastantes capitulos para que cargar la obra entera se note en la cuenta de
# consultas. La cifra real de Culpeper son 423; aqui basta con que sean muchos.
FILLER = 40


@pytest.fixture
def herbal(db_session):
    """Siembra la obra con su indice, sus parrafos y su puente a Materia."""
    conn = db_session.connection()
    work_id = uuid.uuid4()
    conn.execute(
        text("""
            INSERT INTO library_works
                (id, slug, title, author, year, language, license_note, advisory)
            VALUES (:id, :slug, 'The Complete Herbal', 'Nicholas Culpeper', 1653,
                    'en', 'dominio publico', :advisory)
        """),
        {"id": work_id, "slug": WORK, "advisory": ADVISORY},
    )

    def chapter(slug, title, position, meta="{}"):
        cid = uuid.uuid4()
        conn.execute(
            text("""
                INSERT INTO library_chapters
                    (id, work_id, slug, title, kind, position, meta)
                VALUES (:id, :w, :slug, :title, 'herb', :pos, CAST(:meta AS jsonb))
            """),
            {"id": cid, "w": work_id, "slug": slug, "title": title,
             "pos": position, "meta": meta},
        )
        return cid

    def para(cid, position, original, es=None):
        conn.execute(
            text("""
                INSERT INTO library_paragraphs
                    (id, chapter_id, anchor, position, text_original, text_es,
                     translation_status)
                VALUES (:id, :c, :anchor, :pos, :orig, :es, :st)
            """),
            {"id": uuid.uuid4(), "c": cid, "anchor": f"{WORK}.{cid}.{position}",
             "pos": position, "orig": original, "es": es,
             "st": "machine" if es else None},
        )

    first = chapter(FIRST, "A Catalogue of Simples", 1)
    para(first, 1, "The herbs, plants, etc. treated of in this book.")

    amara = chapter(
        "amara-dulcis", "Amara Dulcis", 2,
        '{"materia_slug": "amara-dulcis", "ruling_planets": ["Mercurio"]}',
    )
    para(amara, 1, "Considering divers shires in this nation give divers names.")
    para(amara, 2, "It is under the planet Mercury.", "Esta bajo el planeta Mercurio.")

    for i in range(FILLER):
        relleno = chapter(f"relleno-{i:03d}", f"Relleno {i}", 3 + i)
        para(relleno, 1, f"texto {i}")

    db_session.flush()
    return {"work_id": work_id, "amara": amara, "first": first}


def test_amara_dulcis_responde_200_con_chapter_detail_valido(client, herbal):
    """El capitulo que fallaba en produccion."""
    resp = client.get(f"/library/{WORK}/amara-dulcis")

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["slug"] == "amara-dulcis"
    assert body["title"] == "Amara Dulcis"
    # La cabecera de la obra: lo que el router leia de `chapter.work`.
    assert body["work_slug"] == WORK
    assert body["work_title"] == "The Complete Herbal"
    # El aviso historico viaja con el texto, no solo en la portada.
    assert body["advisory"] == ADVISORY
    assert len(body["paragraphs"]) == 2
    assert body["paragraphs"][0]["position"] == 1
    assert body["paragraphs"][1]["text_es"] == "Esta bajo el planeta Mercurio."


def test_el_primer_capitulo_real_responde_200(client, herbal):
    """El otro sintoma fisico: abrir el primero del indice tambien reventaba."""
    resp = client.get(f"/library/{WORK}/{FIRST}")

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["slug"] == FIRST
    assert body["work_slug"] == WORK
    assert body["work_title"] == "The Complete Herbal"
    assert body["paragraphs"], "un capitulo sin parrafos no prueba nada"


def test_capitulo_inexistente_sigue_dando_404(client, herbal):
    """404 y no 500: el capitulo que no existe es ausencia, no averia."""
    resp = client.get(f"/library/{WORK}/no-existe-esta-hierba")

    assert resp.status_code == 404, resp.text
    assert resp.json()["detail"] == "Capítulo no encontrado."


def test_un_capitulo_de_otra_obra_no_se_cuela(client, herbal, db_session):
    """El slug de obra tiene que filtrar de verdad, no ser decorativo."""
    otra = uuid.uuid4()
    db_session.connection().execute(
        text("""
            INSERT INTO library_works (id, slug, title, author, language, license_note)
            VALUES (:id, 'otra-obra', 'Otra', 'Otro autor', 'en', 'dominio publico')
        """),
        {"id": otra},
    )
    db_session.flush()

    resp = client.get("/library/otra-obra/amara-dulcis")

    assert resp.status_code == 404, resp.text


def test_el_detalle_no_arrastra_la_obra_entera(db_session, herbal):
    """El coste de abrir un capitulo no puede crecer con el tamaño del libro.

    Prohibido resolver la cabecera de la obra cargandola con `get_by_slug()`:
    eso trae los 423 capitulos y sus parrafos para rellenar tres campos. Se
    cuenta el SQL emitido y se comprueba que ningun SELECT toca la tabla de
    capitulos en plural ni la de parrafos de otro capitulo.
    """
    statements = []
    engine = db_session.get_bind()

    @event.listens_for(engine, "before_cursor_execute")
    def record(conn, cursor, statement, parameters, context, executemany):
        statements.append(statement)

    try:
        chapter = LibraryWorkRepository(db_session).get_chapter(WORK, "amara-dulcis")
    finally:
        event.remove(engine, "before_cursor_execute", record)

    assert chapter is not None
    assert chapter.work_slug == WORK
    assert chapter.work_advisory == ADVISORY
    assert len(chapter.paragraphs) == 2

    selects = [s for s in statements if s.lstrip().upper().startswith("SELECT")]
    # Dos y solo dos: el capitulo con su obra en un JOIN, y sus parrafos.
    assert len(selects) == 2, f"{len(selects)} consultas: {selects}"

    # Y ninguna de ellas pide capitulos por work_id, que es la firma exacta de
    # haber cargado el libro entero.
    for sql in selects:
        assert "library_chapters.work_id = " not in sql.replace("\n", " "), sql


def test_el_puente_de_materia_tambien_sirve_la_cabecera(client, herbal):
    """Mismo defecto, misma tabla: /by-materia leia `chapter.work.author`."""
    resp = client.get("/library/by-materia/amara-dulcis")

    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["work_slug"] == WORK
    assert body["work_title"] == "The Complete Herbal"
    assert body["author"] == "Nicholas Culpeper"
    assert body["year"] == 1653
    assert body["chapter_slug"] == "amara-dulcis"
