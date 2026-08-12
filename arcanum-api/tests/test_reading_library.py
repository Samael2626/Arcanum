"""Biblioteca personal: progreso, marcadores y pasajes guardados.

Dos invariantes mandan aqui y por eso casi todos los tests las rozan:

1. La posicion NUNCA es un numero de pagina. Se guarda (obra, capitulo, ancla,
   fragmento), que sobrevive a un cambio de tipografia, de idioma y de pantalla.
2. Las notas personales viajan y se guardan CIFRADAS. Se comprueba mirando la
   fila real en la base de datos, no fiandose de lo que devuelve la API.
"""
import uuid

import pytest
from sqlalchemy import text

WORK = "culpeper-complete-herbal"
CHAPTER = "amara-dulcis"
OTHER_CHAPTER = "all-heal"

_USER_A = {"email": "lectora@arcanum.com", "password": "lectorapass123"}
_USER_B = {"email": "intruso@arcanum.com", "password": "intrusopass123"}


def _auth(client, payload):
    client.post("/auth/register", json=payload)
    tok = client.post(
        "/auth/login",
        data={"username": payload["email"], "password": payload["password"]},
    ).json()
    return {"Authorization": f"Bearer {tok['access_token']}"}


@pytest.fixture
def herbal(db_session):
    """Una obra minima con dos capitulos y anclas reales."""
    conn = db_session.connection()
    work_id = uuid.uuid4()
    conn.execute(
        text("""
            INSERT INTO library_works (id, slug, title, author, year, language, license_note)
            VALUES (:id, :slug, 'The Complete Herbal', 'Nicholas Culpeper', 1653,
                    'en', 'dominio publico')
        """),
        {"id": work_id, "slug": WORK},
    )

    anchors = {}
    for pos, (slug, title) in enumerate(
        [(CHAPTER, "Amara Dulcis"), (OTHER_CHAPTER, "All-Heal")], start=1
    ):
        cid = uuid.uuid4()
        conn.execute(
            text("""
                INSERT INTO library_chapters (id, work_id, slug, title, kind, position)
                VALUES (:id, :w, :slug, :title, 'herb', :pos)
            """),
            {"id": cid, "w": work_id, "slug": slug, "title": title, "pos": pos},
        )
        for p in (1, 2, 3):
            anchor = f"{WORK}.{slug}.{p}"
            anchors[anchor] = cid
            conn.execute(
                text("""
                    INSERT INTO library_paragraphs
                        (id, chapter_id, anchor, position, text_original, text_es)
                    VALUES (:id, :c, :anchor, :pos, :orig, :es)
                """),
                {"id": uuid.uuid4(), "c": cid, "anchor": anchor, "pos": p,
                 "orig": f"original {slug} {p}", "es": f"traduccion {slug} {p}"},
            )
    db_session.flush()
    return anchors


def _position(chapter=CHAPTER, para=2, fragment=0):
    return {
        "work_slug": WORK,
        "chapter_slug": chapter,
        "paragraph_anchor": f"{WORK}.{chapter}.{para}",
        "fragment_index": fragment,
    }


# ── Progreso ────────────────────────────────────────────────────────────────


def test_progreso_se_crea_y_se_actualiza_sin_duplicar(client, herbal):
    headers = _auth(client, _USER_A)

    first = client.put(
        "/reading/progress",
        json={"position": _position(para=1), "language": "es"},
        headers=headers,
    )
    assert first.status_code == 200, first.text
    assert first.json()["position"]["paragraph_anchor"] == f"{WORK}.{CHAPTER}.1"

    second = client.put(
        "/reading/progress",
        json={"position": _position(chapter=OTHER_CHAPTER, para=3), "language": "en"},
        headers=headers,
    )
    assert second.status_code == 200, second.text

    # Misma fila: una obra tiene UNA posicion viva, no un historial.
    assert second.json()["id"] == first.json()["id"]
    assert second.json()["position"]["chapter_slug"] == OTHER_CHAPTER
    assert second.json()["language"] == "en"

    assert len(client.get("/reading/progress", headers=headers).json()) == 1


def test_reanudar_devuelve_la_posicion_exacta(client, herbal):
    """Lo que necesita el boton "Reanudar lectura"."""
    headers = _auth(client, _USER_A)
    saved = _position(chapter=OTHER_CHAPTER, para=3, fragment=2)
    client.put("/reading/progress", json={"position": saved, "language": "en"}, headers=headers)

    resp = client.get(f"/reading/progress/{WORK}", headers=headers)

    assert resp.status_code == 200, resp.text
    got = resp.json()["position"]
    for campo, esperado in saved.items():
        assert got[campo] == esperado, campo
    assert resp.json()["language"] == "en"
    # Los titulos viajan resueltos: sin ellos el cliente tendria que pedir la
    # obra entera solo para pintar "Reanudar en All-Heal".
    assert got["work_title"] == "The Complete Herbal"
    assert got["chapter_title"] == "All-Heal"


def test_la_posicion_no_guarda_numero_de_pagina(client, herbal):
    """Blindaje del contrato: si alguien anade "page", este test lo caza."""
    headers = _auth(client, _USER_A)
    client.put("/reading/progress", json={"position": _position()}, headers=headers)

    devuelto = client.get(f"/reading/progress/{WORK}", headers=headers).json()

    assert "page" not in devuelto["position"]
    assert "page_number" not in devuelto["position"]
    assert set(devuelto["position"]) == {
        "work_slug", "chapter_slug", "paragraph_anchor", "fragment_index",
        "work_title", "chapter_title",
    }


def test_sin_progreso_la_obra_responde_404(client, herbal):
    """404 es la senal de "Comenzar lectura", no una averia."""
    headers = _auth(client, _USER_A)
    assert client.get(f"/reading/progress/{WORK}", headers=headers).status_code == 404


def test_el_progreso_de_otro_usuario_no_se_ve(client, herbal):
    a = _auth(client, _USER_A)
    client.put("/reading/progress", json={"position": _position(para=3)}, headers=a)

    b = _auth(client, _USER_B)
    assert client.get(f"/reading/progress/{WORK}", headers=b).status_code == 404
    assert client.get("/reading/progress", headers=b).json() == []


def test_progreso_exige_autenticacion(client, herbal):
    assert client.put("/reading/progress", json={"position": _position()}).status_code == 401


# ── Validacion de posiciones ────────────────────────────────────────────────


def test_ancla_inexistente_da_404(client, herbal):
    headers = _auth(client, _USER_A)
    mala = _position()
    mala["paragraph_anchor"] = f"{WORK}.{CHAPTER}.999"

    resp = client.put("/reading/progress", json={"position": mala}, headers=headers)

    assert resp.status_code == 404, resp.text
    assert "no existe" in resp.json()["detail"]


def test_ancla_real_con_capitulo_equivocado_da_404(client, herbal):
    """Coherencia, no solo existencia: el ancla existe pero no en ese capitulo."""
    headers = _auth(client, _USER_A)
    incoherente = _position(chapter=OTHER_CHAPTER)
    incoherente["paragraph_anchor"] = f"{WORK}.{CHAPTER}.2"   # es del OTRO capitulo

    resp = client.put("/reading/progress", json={"position": incoherente}, headers=headers)

    assert resp.status_code == 404, resp.text


def test_obra_inexistente_da_404(client, herbal):
    headers = _auth(client, _USER_A)
    mala = _position()
    mala["work_slug"] = "obra-que-no-existe"

    assert client.put(
        "/reading/progress", json={"position": mala}, headers=headers
    ).status_code == 404


def test_fragmento_negativo_lo_rechaza_el_schema(client, herbal):
    headers = _auth(client, _USER_A)
    resp = client.put(
        "/reading/progress", json={"position": _position(fragment=-1)}, headers=headers
    )
    assert resp.status_code == 422, resp.text


# ── Marcadores ──────────────────────────────────────────────────────────────


def test_marcadores_crear_listar_borrar(client, herbal):
    headers = _auth(client, _USER_A)

    uno = client.post(
        "/reading/bookmarks",
        json={"position": _position(para=1), "label": "Regencia"},
        headers=headers,
    )
    assert uno.status_code == 201, uno.text
    dos = client.post(
        "/reading/bookmarks",
        json={"position": _position(chapter=OTHER_CHAPTER, para=2)},
        headers=headers,
    )
    assert dos.status_code == 201, dos.text

    # Varios por obra, con lo necesario para abrir el lector exacto.
    listado = client.get("/reading/bookmarks", headers=headers).json()
    assert len(listado) == 2
    assert {b["position"]["chapter_title"] for b in listado} == {"Amara Dulcis", "All-Heal"}
    assert any(b["label"] == "Regencia" for b in listado)

    assert client.delete(f"/reading/bookmarks/{uno.json()['id']}", headers=headers).status_code == 204
    assert len(client.get("/reading/bookmarks", headers=headers).json()) == 1


def test_marcar_dos_veces_el_mismo_punto_no_duplica(client, herbal):
    headers = _auth(client, _USER_A)
    client.post("/reading/bookmarks", json={"position": _position()}, headers=headers)

    repetido = client.post("/reading/bookmarks", json={"position": _position()}, headers=headers)

    assert repetido.status_code == 409, repetido.text
    assert len(client.get("/reading/bookmarks", headers=headers).json()) == 1


def test_un_usuario_no_borra_ni_ve_marcadores_ajenos(client, herbal):
    a = _auth(client, _USER_A)
    ajeno = client.post("/reading/bookmarks", json={"position": _position()}, headers=a).json()

    b = _auth(client, _USER_B)
    assert client.get("/reading/bookmarks", headers=b).json() == []
    # 404 y no 403: distinguirlos confirmaria a un desconocido que ese id existe.
    assert client.delete(f"/reading/bookmarks/{ajeno['id']}", headers=b).status_code == 404

    # Y sigue vivo para su duenno.
    assert len(client.get("/reading/bookmarks", headers=a).json()) == 1


def test_el_marcador_no_mueve_el_progreso(client, herbal):
    """Marcar es un gesto deliberado; el progreso es automatico. No se pisan."""
    headers = _auth(client, _USER_A)
    client.put("/reading/progress", json={"position": _position(para=1)}, headers=headers)

    client.post(
        "/reading/bookmarks",
        json={"position": _position(chapter=OTHER_CHAPTER, para=3)},
        headers=headers,
    )

    progreso = client.get(f"/reading/progress/{WORK}", headers=headers).json()
    assert progreso["position"]["chapter_slug"] == CHAPTER
    assert progreso["position"]["paragraph_anchor"] == f"{WORK}.{CHAPTER}.1"


# ── Pasajes guardados ───────────────────────────────────────────────────────


CIPHERTEXT = "8J+Ygc3J0ZXh0IGNpZnJhZG8gZGUgcHJ1ZWJh"     # base64 opaco
IV = "YWJjZGVmZ2hpamtsbW5vcA=="
SECRETO = "esto es lo que el usuario escribio en privado"


def test_pasaje_con_nota_cifrada_no_deja_texto_en_claro_en_la_base(client, herbal, db_session):
    headers = _auth(client, _USER_A)

    creado = client.post(
        "/reading/passages",
        json={
            "position": _position(para=2),
            "quote_text": "It is under the planet Mercury.",
            "quote_language": "en",
            "encrypted_note": CIPHERTEXT,
            "note_iv": IV,
        },
        headers=headers,
    )
    assert creado.status_code == 201, creado.text
    assert creado.json()["encrypted_note"] == CIPHERTEXT

    # La prueba de verdad: mirar la fila, no fiarse de la respuesta.
    fila = db_session.connection().execute(
        text("SELECT encrypted_note, note_iv FROM saved_passages WHERE id = :id"),
        {"id": creado.json()["id"]},
    ).one()
    assert fila.encrypted_note == CIPHERTEXT
    assert fila.note_iv == IV

    # Y en ninguna columna de la tabla asoma el texto en claro.
    columnas = db_session.connection().execute(
        text("SELECT * FROM saved_passages WHERE id = :id"), {"id": creado.json()["id"]}
    ).mappings().one()
    for nombre, valor in columnas.items():
        assert SECRETO not in str(valor), f"texto en claro en la columna {nombre}"


def test_el_contrato_no_admite_notas_en_claro(client, herbal):
    """Si alguien anade un campo `note` sin cifrar, este test lo caza.

    Pydantic ignora los extras por defecto, asi que se comprueba que el campo
    NO acaba persistido ni devuelto: la nota en claro no existe en el modelo.
    """
    headers = _auth(client, _USER_A)
    resp = client.post(
        "/reading/passages",
        json={
            "position": _position(),
            "quote_text": "cita",
            "note": SECRETO,
        },
        headers=headers,
    )
    assert resp.status_code == 201, resp.text
    assert "note" not in resp.json()
    assert resp.json()["encrypted_note"] is None


def test_ciphertext_sin_iv_se_rechaza(client, herbal):
    """Una nota cifrada sin su IV es irrecuperable: mejor 422 que basura."""
    headers = _auth(client, _USER_A)
    resp = client.post(
        "/reading/passages",
        json={"position": _position(), "quote_text": "cita", "encrypted_note": CIPHERTEXT},
        headers=headers,
    )
    assert resp.status_code == 422, resp.text


def test_editar_y_borrar_la_nota_de_un_pasaje(client, herbal):
    headers = _auth(client, _USER_A)
    passage = client.post(
        "/reading/passages",
        json={"position": _position(), "quote_text": "cita", "encrypted_note": CIPHERTEXT,
              "note_iv": IV},
        headers=headers,
    ).json()

    otro = "bnVldmEgbm90YSBjaWZyYWRh"
    editado = client.patch(
        f"/reading/passages/{passage['id']}",
        json={"encrypted_note": otro, "note_iv": IV},
        headers=headers,
    )
    assert editado.status_code == 200, editado.text
    assert editado.json()["encrypted_note"] == otro

    # Mandar ambos en null borra la nota pero conserva el pasaje.
    borrada = client.patch(
        f"/reading/passages/{passage['id']}",
        json={"encrypted_note": None, "note_iv": None},
        headers=headers,
    )
    assert borrada.status_code == 200, borrada.text
    assert borrada.json()["encrypted_note"] is None
    assert borrada.json()["quote_text"] == "cita"


def test_borrar_un_pasaje(client, herbal):
    headers = _auth(client, _USER_A)
    passage = client.post(
        "/reading/passages",
        json={"position": _position(), "quote_text": "cita"},
        headers=headers,
    ).json()

    assert client.delete(f"/reading/passages/{passage['id']}", headers=headers).status_code == 204
    assert client.get("/reading/passages", headers=headers).json() == []


def test_los_pasajes_ajenos_no_se_listan_ni_se_editan(client, herbal):
    a = _auth(client, _USER_A)
    ajeno = client.post(
        "/reading/passages",
        json={"position": _position(), "quote_text": "cita privada",
              "encrypted_note": CIPHERTEXT, "note_iv": IV},
        headers=a,
    ).json()

    b = _auth(client, _USER_B)
    assert client.get("/reading/passages", headers=b).json() == []
    assert client.patch(
        f"/reading/passages/{ajeno['id']}",
        json={"encrypted_note": "bWlh", "note_iv": IV},
        headers=b,
    ).status_code == 404
    assert client.delete(f"/reading/passages/{ajeno['id']}", headers=b).status_code == 404

    # Intacto para su duenno.
    suyos = client.get("/reading/passages", headers=a).json()
    assert len(suyos) == 1
    assert suyos[0]["encrypted_note"] == CIPHERTEXT


def test_los_pasajes_se_listan_para_el_grimorio(client, herbal):
    """"Grimorio -> Pasajes guardados": cronologico y con obra y capitulo."""
    headers = _auth(client, _USER_A)
    for chapter, para in [(CHAPTER, 1), (OTHER_CHAPTER, 2)]:
        client.post(
            "/reading/passages",
            json={"position": _position(chapter=chapter, para=para),
                  "quote_text": f"cita de {chapter}"},
            headers=headers,
        )

    listado = client.get("/reading/passages", headers=headers).json()

    assert len(listado) == 2
    for item in listado:
        assert item["position"]["work_title"] == "The Complete Herbal"
        assert item["position"]["chapter_title"] in {"Amara Dulcis", "All-Heal"}
        assert item["position"]["paragraph_anchor"].startswith(WORK)

    filtrado = client.get("/reading/passages", params={"work_slug": WORK}, headers=headers).json()
    assert len(filtrado) == 2
    assert client.get(
        "/reading/passages", params={"work_slug": "otra"}, headers=headers
    ).json() == []


def test_guardar_dos_veces_el_mismo_pasaje_no_duplica(client, herbal):
    headers = _auth(client, _USER_A)
    cuerpo = {"position": _position(), "quote_text": "cita"}
    client.post("/reading/passages", json=cuerpo, headers=headers)

    repetido = client.post("/reading/passages", json=cuerpo, headers=headers)

    assert repetido.status_code == 409, repetido.text
    assert len(client.get("/reading/passages", headers=headers).json()) == 1


def test_pasaje_en_posicion_inexistente_da_404(client, herbal):
    headers = _auth(client, _USER_A)
    mala = _position()
    mala["paragraph_anchor"] = "inventado.del.todo"

    resp = client.post(
        "/reading/passages", json={"position": mala, "quote_text": "cita"}, headers=headers
    )

    assert resp.status_code == 404, resp.text
