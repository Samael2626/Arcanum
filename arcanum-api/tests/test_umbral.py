"""Endpoint de la Lectura del Umbral y la zona local de /astral/today."""

_BASE = {
    "password": "umbralpass123",
    "display_name": "Umbral User",
    "birth_date": "1990-03-14T00:00:00",
    "birth_lat": "6.25",
    "birth_lon": "-75.56",
    "birth_timezone": "America/Bogota",
}


def _auth(client, email, **extra):
    payload = {**_BASE, "email": email, **extra}
    client.post("/auth/register", json=payload)
    token = client.post(
        "/auth/login",
        data={"username": email, "password": payload["password"]},
    ).json()
    return {"Authorization": f"Bearer {token['access_token']}"}


# ── /astral/today ────────────────────────────────────────────────────────────


def test_today_sin_zona_no_afirma_una_fecha_local(client):
    data = client.get("/astral/today", params={"lat": 6.25, "lon": -75.56}).json()
    assert data["local_date"] is None
    assert data["timezone"] is None
    assert "zona horaria confirmada" in data["degraded_reason"]


def test_today_con_zona_resuelve_la_fecha_ahi(client):
    bogota = client.get(
        "/astral/today", params={"lat": 6.25, "lon": -75.56, "tz": "America/Bogota"}
    ).json()
    tokio = client.get(
        "/astral/today", params={"lat": 6.25, "lon": -75.56, "tz": "Asia/Tokyo"}
    ).json()

    assert bogota["timezone"] == "America/Bogota"
    assert tokio["timezone"] == "Asia/Tokyo"
    assert bogota["day_window"]["starts_at"] != tokio["day_window"]["starts_at"]
    assert bogota["degraded_reason"] is None


def test_today_con_zona_rota_falla_visible(client):
    res = client.get(
        "/astral/today",
        params={"lat": 6.25, "lon": -75.56, "tz": "America/Ciudad_Inventada"},
    )
    assert res.status_code == 422


# ── /astral/umbral ───────────────────────────────────────────────────────────


def test_umbral_requiere_auth(client):
    assert client.get("/astral/umbral").status_code == 401


def test_umbral_sin_carta_natal_devuelve_lectura_general(client):
    headers = _auth(client, "umbral-general@arcanum.com", birth_time="1990-03-14T07:30:00")
    data = client.get("/astral/umbral", headers=headers).json()

    assert data["contract_version"] == "horoscope_daily/1"
    assert data["precision"] == "general"
    assert data["reading"]["is_personalized"] is False
    assert "carta natal calculada" in data["degraded_reason"]
    assert all(f["is_headline"] is False for f in data["factors"])


def test_umbral_con_carta_es_personalizado_y_versionado(client):
    headers = _auth(client, "umbral-full@arcanum.com", birth_time="1990-03-14T07:30:00")
    assert client.post("/astral/natal-chart", headers=headers).status_code == 201

    data = client.get("/astral/umbral", headers=headers).json()

    assert data["precision"] == "full"
    assert data["selector_version"] == "umbral-selector-1.0.0"
    assert data["editorial_version"] == "umbral-editorial-1.0.0"
    assert data["ephemeris"] == "swisseph/moshier"
    assert data["window"]["timezone"] == "America/Bogota"
    assert 1 <= len(data["factors"]) <= 2

    reading = data["reading"]
    assert reading["headline"]
    assert reading["observed_sky"]
    assert reading["symbolic_reading"]
    assert reading["practice"]
    assert reading["why_today"]
    assert reading["sources"]
    assert reading["limits"]


def test_umbral_es_estable_dentro_del_mismo_dia_local(client):
    headers = _auth(client, "umbral-estable@arcanum.com", birth_time="1990-03-14T07:30:00")
    client.post("/astral/natal-chart", headers=headers)

    primera = client.get("/astral/umbral", headers=headers).json()
    segunda = client.get("/astral/umbral", headers=headers).json()

    assert primera["factors"] == segunda["factors"]
    assert primera["reading"] == segunda["reading"]
    assert primera["window"] == segunda["window"]


def test_umbral_sin_zona_declara_que_no_puede_nombrar_el_dia(client):
    headers = _auth(
        client,
        "umbral-sinzona@arcanum.com",
        birth_time="1990-03-14T07:30:00",
        birth_timezone=None,
    )
    data = client.get("/astral/umbral", headers=headers).json()

    assert data["precision"] == "unavailable"
    assert data["window"] is None
    assert data["reading"] is None
    assert data["factors"] == []
    assert "zona horaria confirmada" in data["degraded_reason"]


def test_umbral_acepta_la_zona_del_cliente_por_encima_de_la_del_perfil(client):
    headers = _auth(client, "umbral-tz@arcanum.com", birth_time="1990-03-14T07:30:00")
    data = client.get(
        "/astral/umbral", params={"tz": "Asia/Tokyo"}, headers=headers
    ).json()
    assert data["window"]["timezone"] == "Asia/Tokyo"


def test_umbral_con_zona_rota_falla_visible(client):
    headers = _auth(client, "umbral-tzrota@arcanum.com", birth_time="1990-03-14T07:30:00")
    res = client.get(
        "/astral/umbral", params={"tz": "Marte/Olympus"}, headers=headers
    )
    assert res.status_code == 422


def test_umbral_sin_hora_de_nacimiento_no_nombra_casas_ni_angulos(client):
    """Sin hora no hay carta calculable, asi que la lectura cae a general y
    lo declara. Lo que nunca ocurre es que aparezca una casa inventada."""
    headers = _auth(client, "umbral-sinhora@arcanum.com")
    data = client.get("/astral/umbral", headers=headers).json()

    assert data["precision"] in ("general", "no_time")
    for factor in data["factors"]:
        assert "natal_house" not in factor
        assert factor.get("natal") not in ("ascendant", "midheaven")
