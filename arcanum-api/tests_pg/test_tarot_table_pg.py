"""Mesa de tarot contra PostgreSQL real (esquema de Alembic hasta la 016).

Rutas de sesion, cupo al interpretar (D1), idempotencia, permisos entre
usuarios, caducidad y que el orden del mazo nunca salga hacia el cliente.
"""
import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.core.security import get_current_user
from app.db.session import get_db
from app.domain.entities import UserEntity
from app.main import app

SUITS = ("wands", "cups", "swords", "pentacles")
MAJORS = [f"mayor-{n}" for n in range(22)]
MINORS = [f"{n}-de-{s}" for s in SUITS for n in range(1, 15)]


@pytest.fixture(autouse=True)
def deck(engine):
    with engine.begin() as c:
        c.execute(text("DELETE FROM tarot_cards"))
        rows = [(s, "major", None, n) for n, s in enumerate(MAJORS)]
        rows += [(f"{n}-de-{s}", "minor", s, n) for s in SUITS for n in range(1, 15)]
        for slug, arcana, suit, n in rows:
            c.execute(text("""
                INSERT INTO tarot_cards (id, slug, arcana, suit, number, meaning_upright, meaning_reversed, lang)
                VALUES (:i, :s, :a, :su, :n, 'derecha', 'invertida', 'es')
            """), {"i": uuid.uuid4(), "s": slug, "a": arcana, "su": suit, "n": n})
    yield
    with engine.begin() as c:
        c.execute(text("DELETE FROM tarot_cards"))


def _user(engine, credits=0):
    uid = uuid.uuid4()
    with engine.begin() as c:
        c.execute(text("""
            INSERT INTO users (id, email, hashed_password, display_name, subscription_tier, credits_balance)
            VALUES (:id, :email, 'x', 'Test', 'free', :cr)
        """), {"id": uid, "email": f"{uid}@test.local", "cr": credits})
    return uid


@pytest.fixture
def who(engine):
    """Usuario en nombre del que se hacen las peticiones; se puede cambiar a mitad de test."""
    return {"id": _user(engine)}


@pytest.fixture
def client(engine, who, monkeypatch):
    Session = sessionmaker(bind=engine)

    def override_db():
        db = Session()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_db
    app.dependency_overrides[get_current_user] = lambda: UserEntity(
        id=who["id"], email="t@test.local", hashed_password="x",
        display_name="Test", subscription_tier="free",
    )
    monkeypatch.setattr(settings, "TAROT_FREE_DAILY", 1)
    yield TestClient(app, raise_server_exceptions=False)
    app.dependency_overrides.clear()


def _one(engine, sql, **kw):
    with engine.begin() as c:
        return c.execute(text(sql), kw).scalar()


def _open(client, deck="rws"):
    r = client.post("/tarot/sessions", json={"deck": deck})
    assert r.status_code == 201, r.text
    return r.json()


def _post(client, sid, op, body, **kw):
    return client.post(f"/tarot/sessions/{sid}/{op}", json=body, **kw)


def _take(client, sid, positions, pile="p0"):
    return [_post(client, sid, "take", {"pile": pile, "position": p}).json()["card"] for p in positions]


def _interpret(client, sid, placements, spread="three_card", key=None, question=None):
    return _post(client, sid, "interpret", {"spread": spread, "question": question, "placements": placements},
                 headers={"Idempotency-Key": key or str(uuid.uuid4())})


def _three(client):
    """Mesa barajada con tres cartas fuera, lista para una tirada de tres."""
    sid = _open(client)["id"]
    assert _post(client, sid, "shuffle", {"pile": "p0"}).status_code == 200
    cards = _take(client, sid, [5, 17, 40])
    return sid, cards, [{"slug": c["slug"], "slot": i} for i, c in enumerate(cards)]


# ---------- catalogos ----------
def test_catalogos_de_mazos_y_tiradas(client):
    decks = {d["slug"]: d["card_count"] for d in client.get("/tarot/decks").json()}
    assert decks == {"rws": 78, "mayores": 22}
    spreads = {s["slug"]: s for s in client.get("/tarot/spreads").json()}
    assert len(spreads) == 7
    assert [sl["name"] for sl in spreads["three_card"]["slots"]] == ["Pasado", "Presente", "Futuro"]
    assert spreads["celtic_cross"]["slots"][1]["rotation"] == 90


# ---------- sesion ----------
def test_abrir_muestra_el_mazo_sin_revelar_el_orden(client):
    assert client.get("/tarot/sessions/current").status_code == 404
    view = _open(client)
    assert view["total"] == 78 and view["piles"]["p0"]["positions"] == list(range(78))
    assert view["status"] == "open" and view["drawn"] == []
    shuffled = _post(client, view["id"], "shuffle", {"pile": "p0", "style": "por_encima"})
    texto = shuffled.text
    assert not any(s in texto for s in MAJORS + MINORS)   # ninguna carta del mazo sale
    assert client.get("/tarot/sessions/current").json()["id"] == view["id"]


def test_el_mazo_de_mayores_solo_tiene_22(client):
    sid = _open(client, "mayores")["id"]
    _post(client, sid, "shuffle", {"pile": "p0"})
    cards = _take(client, sid, range(22))
    assert {c["slug"] for c in cards} == set(MAJORS)


def test_abrir_otra_mesa_abandona_la_anterior(client, engine, who):
    first = _open(client)["id"]
    second = _open(client)["id"]
    assert _post(client, first, "shuffle", {"pile": "p0"}).status_code == 404
    assert _one(engine, "SELECT count(*) FROM tarot_sessions WHERE user_id=:u AND status IN ('open','interpreted')",
                u=who["id"]) == 1
    assert client.get("/tarot/sessions/current").json()["id"] == second


def test_cortar_unir_sacar_devolver_y_recoger(client):
    sid = _open(client)["id"]
    r = _post(client, sid, "cut", {"pile": "p0", "n": 30}).json()
    assert r["pile"] == "p1" and r["table"]["piles"]["p1"]["count"] == 30
    _post(client, sid, "merge", {"piles": ["p0", "p1"], "into": "p0"})
    card = _take(client, sid, [0])[0]
    assert card["slug"] == "9-de-wands" and card["reversed"] is False   # 22 mayores + 8 bastos pasaron abajo
    view = _post(client, sid, "return", {"slug": card["slug"], "pile": "p0"}).json()
    assert view["total"] == 78 and view["drawn"] == []
    _take(client, sid, [3, 4])
    assert _post(client, sid, "gather", {"pile": "p0"}).json()["total"] == 78


def test_no_se_saca_dos_veces_la_misma_posicion(client):
    sid = _open(client)["id"]
    _take(client, sid, [7])
    r = _post(client, sid, "take", {"pile": "p0", "position": 7})
    assert r.status_code == 400
    assert _post(client, sid, "take", {"pile": "p9", "position": 0}).status_code == 400
    assert _post(client, sid, "take", {"pile": "hack", "position": 0}).status_code == 422


def test_una_mesa_caducada_no_se_puede_tocar(client, engine):
    sid = _open(client)["id"]
    with engine.begin() as c:
        c.execute(text("UPDATE tarot_sessions SET expires_at = now() - interval '1 minute' WHERE id=:i"), {"i": sid})
    assert client.get("/tarot/sessions/current").status_code == 404
    assert _post(client, sid, "shuffle", {"pile": "p0"}).status_code == 404
    assert _one(engine, "SELECT status FROM tarot_sessions WHERE id=:i", i=sid) == "abandoned"


# ---------- permisos ----------
def test_un_usuario_no_toca_la_mesa_ni_las_lecturas_de_otro(client, engine, who):
    sid, _, placements = _three(client)
    _interpret(client, sid, placements)
    reading = _post(client, sid, "close", {}).json()["id"]
    who["id"] = _user(engine)
    assert _post(client, sid, "shuffle", {"pile": "p0"}).status_code == 404
    assert _post(client, sid, "close", {}).status_code == 404
    assert client.get(f"/tarot/readings/{reading}").status_code == 404
    assert client.get("/tarot/readings").json() == []


# ---------- interpretar: cupo, validacion, idempotencia ----------
def test_interpretar_gasta_el_cupo_y_usa_las_invertidas_del_servidor(client, engine, who):
    sid, cards, placements = _three(client)
    assert _one(engine, "SELECT count(*) FROM usage_operations WHERE user_id=:u", u=who["id"]) == 0
    r = _interpret(client, sid, placements, question="  ¿Qué viene?  ")
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["question"] == "¿Qué viene?"
    assert [c["position"] for c in body["cards"]] == ["Pasado", "Presente", "Futuro"]
    for got, drawn in zip(body["cards"], cards):
        assert got["slug"] == drawn["slug"] and got["reversed"] == drawn["reversed"]
        assert got["meaning"] == ("invertida" if drawn["reversed"] else "derecha")
    assert _one(engine, "SELECT count(*) FROM usage_operations WHERE user_id=:u AND state='captured' AND action='tarot'",
                u=who["id"]) == 1
    assert client.get("/tarot/sessions/current").json()["status"] == "interpreted"


def test_las_operaciones_de_mesa_no_gastan_cupo(client, engine, who):
    sid = _open(client)["id"]
    for _ in range(5):
        _post(client, sid, "shuffle", {"pile": "p0"})
    _take(client, sid, range(10))
    assert _one(engine, "SELECT count(*) FROM usage_operations WHERE user_id=:u", u=who["id"]) == 0


@pytest.mark.parametrize("placements", [
    [{"slug": "X", "slot": 0}],                                   # carta que no se saco
    "faltan",                                                     # dos huecos para tres
    "repetida",                                                   # la misma carta dos veces
    "hueco_y_aclara",                                             # hueco y aclaratoria a la vez
])
def test_una_tirada_mal_formada_no_gasta_cupo(client, engine, who, placements):
    sid, cards, good = _three(client)
    bad = {
        "faltan": good[:2],
        "repetida": good[:2] + [{"slug": cards[0]["slug"], "slot": 2}],
        "hueco_y_aclara": good[:2] + [{"slug": cards[2]["slug"], "slot": 2, "clarifies": 0}],
    }.get(placements) if isinstance(placements, str) else placements
    assert _interpret(client, sid, bad).status_code == 400
    assert _one(engine, "SELECT count(*) FROM usage_operations WHERE user_id=:u", u=who["id"]) == 0


def test_misma_clave_repite_la_respuesta_sin_cobrar_dos_veces(client, engine, who):
    sid, _, placements = _three(client)
    key = str(uuid.uuid4())
    a = _interpret(client, sid, placements, key=key)
    b = _interpret(client, sid, placements, key=key)
    assert a.status_code == b.status_code == 200 and a.json() == b.json()
    assert _one(engine, "SELECT count(*) FROM usage_operations WHERE user_id=:u", u=who["id"]) == 1


def test_sin_cupo_ni_creditos_devuelve_402_y_la_mesa_sigue_abierta(client, engine, who):
    sid, _, placements = _three(client)
    assert _interpret(client, sid, placements).status_code == 200          # el cupo del dia
    r = _interpret(client, sid, placements)
    assert r.status_code == 402
    assert _one(engine, "SELECT count(*) FROM usage_operations WHERE user_id=:u", u=who["id"]) == 1
    assert client.get("/tarot/sessions/current").status_code == 200


def test_girar_una_carta_invierte_su_sentido(client):
    sid, cards, placements = _three(client)
    placements[1]["turned"] = True
    body = _interpret(client, sid, placements).json()
    assert [c["reversed"] for c in body["cards"]] == [
        cards[0]["reversed"], not cards[1]["reversed"], cards[2]["reversed"],
    ]
    assert body["cards"][1]["meaning"] == ("invertida" if not cards[1]["reversed"] else "derecha")


def test_aclaratorias(client):
    sid = _open(client)["id"]
    _post(client, sid, "shuffle", {"pile": "p0"})
    main, extra = _take(client, sid, [0, 1])
    r = _interpret(client, sid, [{"slug": main["slug"], "slot": 0}, {"slug": extra["slug"], "clarifies": 0}],
                   spread="one_card")
    assert r.status_code == 200, r.text
    cards = r.json()["cards"]
    assert cards[1]["clarifies"] == 0 and cards[1]["position"] == "Aclara: Mensaje"


# ---------- cerrar el circulo y lecturas ----------
def test_cerrar_guarda_la_lectura_con_la_foto_y_es_idempotente(client, engine):
    sid, cards, placements = _three(client)
    assert _post(client, sid, "close", {}).status_code == 400               # sin cartas no hay lectura
    _interpret(client, sid, placements)
    foto = {"camera": {"yaw": 12}, "cards": [{"slug": c["slug"], "x": 1} for c in cards]}
    r = _post(client, sid, "close", {"table": foto})
    assert r.status_code == 200, r.text
    reading = r.json()
    assert reading["spread_type"] == "three_card" and reading["table_snapshot"] == foto
    assert [c["slot"] for c in reading["cards_drawn"]] == [0, 1, 2]
    assert _post(client, sid, "close", {"table": foto}).json()["id"] == reading["id"]
    assert _one(engine, "SELECT count(*) FROM tarot_readings WHERE id=:i", i=reading["id"]) == 1
    assert _post(client, sid, "shuffle", {"pile": "p0"}).status_code == 409
    assert client.get("/tarot/sessions/current").status_code == 404

    listed = client.get("/tarot/readings").json()
    assert [x["id"] for x in listed] == [reading["id"]]
    detail = client.get(f"/tarot/readings/{reading['id']}").json()
    assert [c["slug"] for c in detail["resolved"]] == [c["slug"] for c in cards]


def test_la_foto_de_la_mesa_tiene_limite(client):
    sid, _, placements = _three(client)
    _interpret(client, sid, placements)
    r = _post(client, sid, "close", {"table": {"x": "a" * (70 * 1024)}})
    assert r.status_code == 422


# ---------- concurrencia y esquema ----------
def test_dos_toques_a_la_vez_no_sacan_la_misma_carta(client):
    """La fila de la mesa se bloquea: de ocho peticiones por la misma posicion gana una."""
    from concurrent.futures import ThreadPoolExecutor

    sid = _open(client)["id"]
    with ThreadPoolExecutor(8) as pool:
        codes = list(pool.map(lambda _: _post(client, sid, "take", {"pile": "p0", "position": 3}).status_code,
                              range(8)))
    assert sorted(codes) == [200] + [400] * 7
    assert client.get("/tarot/sessions/current").json()["total"] == 77


def test_la_base_impide_dos_mesas_activas(engine, who):
    from sqlalchemy.exc import IntegrityError

    insert = text("""
        INSERT INTO tarot_sessions (user_id, deck, state, status, expires_at)
        VALUES (:u, 'rws', '{}'::jsonb, :s, now() + interval '1 hour')
    """)
    with engine.begin() as c:
        c.execute(insert, {"u": who["id"], "s": "open"})
        c.execute(insert, {"u": who["id"], "s": "closed"})      # las cerradas no cuentan
    with pytest.raises(IntegrityError):
        with engine.begin() as c:
            c.execute(insert, {"u": who["id"], "s": "interpreted"})



# ---------- cerrar el circulo sin interpretar (decision del 30-sep) ----------
def test_cerrar_sin_interpretar_guarda_lo_que_hay_y_no_gasta_cupo(client, engine, who):
    sid, cards, placements = _three(client)
    r = _post(client, sid, "close", {
        "spread": "three_card", "question": " ¿Y ahora? ", "placements": placements[:2],
        "table": {"camera": {"yaw": 3}},
    })
    assert r.status_code == 200, r.text
    reading = r.json()
    assert reading["spread_type"] == "three_card" and reading["question"] == "¿Y ahora?"
    assert [c["slug"] for c in reading["cards_drawn"]] == [c["slug"] for c in cards[:2]]   # tirada a medias
    assert [c["reversed"] for c in reading["cards_drawn"]] == [c["reversed"] for c in cards[:2]]
    assert _one(engine, "SELECT count(*) FROM usage_operations WHERE user_id=:u", u=who["id"]) == 0
    assert client.get("/tarot/sessions/current").status_code == 404


def test_lectura_libre_sin_tirada(client):
    sid, cards, _ = _three(client)
    r = _post(client, sid, "close", {"placements": [{"slug": c["slug"]} for c in cards]})
    assert r.status_code == 200, r.text
    assert r.json()["spread_type"] == "free"
    assert {c["position"] for c in r.json()["cards_drawn"]} == {"Libre"}


def test_cerrar_sin_interpretar_valida_las_cartas(client):
    sid, cards, placements = _three(client)
    assert _post(client, sid, "close", {"placements": [{"slug": "no-sacada"}]}).status_code == 400
    assert _post(client, sid, "close", {"spread": "three_card", "placements": [
        {"slug": cards[0]["slug"], "slot": 0}, {"slug": cards[1]["slug"], "slot": 0},
    ]}).status_code == 400                                                  # dos cartas en el mismo hueco
    assert _post(client, sid, "close", {"placements": [{"slug": cards[0]["slug"], "slot": 0}]}).status_code == 400


# ---------- deshacer en el servidor (decision del 30-sep) ----------
def test_deshacer_un_corte_devuelve_el_mazo_de_antes(client):
    sid = _open(client)["id"]
    before = _post(client, sid, "shuffle", {"pile": "p0"}).json()
    _post(client, sid, "cut", {"pile": "p0", "n": 20})
    undone = _post(client, sid, "undo", {})
    assert undone.status_code == 200, undone.text
    assert undone.json()["piles"] == before["piles"]
    assert _post(client, sid, "undo", {}).status_code == 409                # una sola vez
    # el orden tambien vuelve: la primera carta es la misma que antes de cortar
    a = _take(client, sid, [0])[0]
    assert _post(client, sid, "undo", {}).status_code == 200
    assert _take(client, sid, [0])[0]["slug"] == a["slug"]


def test_un_gesto_de_varias_operaciones_se_deshace_entero(client):
    sid = _open(client)["id"]
    top = _post(client, sid, "cut", {"pile": "p0", "n": 30}).json()["pile"]
    base = client.get("/tarot/sessions/current").json()
    _post(client, sid, "merge", {"piles": ["p0", top], "into": "p0"})
    _take(client, sid, [0])
    assert _post(client, sid, "take", {"pile": "p0", "position": 1, "checkpoint": False}).status_code == 200
    back = _post(client, sid, "undo", {}).json()
    # la primera saca marco el punto y la segunda no: son un gesto y se deshacen
    # las dos juntas, no solo la ultima
    assert back["total"] == 78 and back["drawn"] == []
    assert list(back["piles"]) == ["p0"] and base["piles"] != back["piles"]


def test_deshacer_caduca(client, engine):
    sid = _open(client)["id"]
    _post(client, sid, "cut", {"pile": "p0", "n": 10})
    with engine.begin() as c:
        c.execute(text("UPDATE tarot_sessions SET previous_until = now() - interval '1 second' WHERE id=:i"),
                  {"i": sid})
    assert _post(client, sid, "undo", {}).status_code == 409


def test_lo_interpretado_no_se_deshace(client):
    sid, _, placements = _three(client)
    assert _interpret(client, sid, placements).status_code == 200
    assert _post(client, sid, "undo", {}).status_code == 409


# ---------- continuar una lectura guardada (decision del 30-sep) ----------
def test_continuar_coloca_las_mismas_cartas_con_su_sentido(client, who, engine):
    sid, cards, placements = _three(client)
    placements[1]["turned"] = True
    reading = _post(client, sid, "close", {"spread": "three_card", "placements": placements}).json()
    r = client.post("/tarot/sessions", json={"deck": "rws", "from_reading": reading["id"]})
    assert r.status_code == 201, r.text
    view = r.json()
    assert view["state"] == "continuada" and view["total"] == 75
    got = {d["slug"]: d["reversed"] for d in view["drawn"]}
    saved = {c["slug"]: c["reversed"] for c in reading["cards_drawn"]}
    assert got == saved
    assert saved[cards[1]["slug"]] is (not cards[1]["reversed"])            # el giro quedo guardado


def test_no_se_continua_la_lectura_de_otro(client, who, engine):
    sid, cards, placements = _three(client)
    reading = _post(client, sid, "close", {"spread": "three_card", "placements": placements}).json()
    who["id"] = _user(engine)
    r = client.post("/tarot/sessions", json={"deck": "rws", "from_reading": reading["id"]})
    assert r.status_code == 404
