"""El rigor del motor de transitos: direccion, exactitud, angulos y peso.

Todo aqui es calculo puro: sin IA, sin red y sin base de datos.
"""
from datetime import datetime, timezone

from app.services import natal_chart_engine as nce
from app.services import transit_weight as tw

NOW = datetime(2026, 8, 16, tzinfo=timezone.utc)


# ── Direccion del aspecto ────────────────────────────────────────────────────


def test_el_orbe_es_el_valor_absoluto_de_la_distancia_a_la_exactitud():
    # Un aspecto tiene dos exactitudes posibles; se toma la mas cercana, y su
    # magnitud tiene que coincidir con el orbe que ya calcula compute_transits.
    for t_lon, n_lon, angle, orbe in [
        (95, 0, 90, 5), (265, 0, 90, 5),
        (358, 0, 0, 2), (2, 0, 0, 2),      # cruce de 0 grados Aries
        (178, 0, 180, 2), (182, 0, 180, 2),
    ]:
        s = nce._signed_delta_to_aspect(t_lon, n_lon, angle)
        assert round(abs(s), 6) == orbe, (t_lon, n_lon, angle)


def test_un_planeta_directo_que_ya_paso_la_exactitud_es_separativo():
    # 95 grados: cinco pasada la cuadratura. Avanzando, se aleja.
    applying, exact_at = nce._applying_and_exact(95, 0, 90, +1.0, NOW)
    assert applying is False
    assert exact_at is None


def test_un_planeta_retrogrado_vuelve_hacia_la_exactitud():
    # Mismo angulo que el test anterior. Solo cambia el signo de la velocidad,
    # y con el la respuesta: es donde se rompe si se compara por valor absoluto.
    applying, exact_at = nce._applying_and_exact(95, 0, 90, -1.0, NOW)
    assert applying is True
    assert exact_at == "2026-08-21T00:00:00+00:00"  # 5 grados a 1 grado/dia


def test_un_planeta_estacionario_ni_se_aplica_ni_perfecciona():
    assert nce._applying_and_exact(95, 0, 90, 0.0, NOW) == (False, None)


def test_no_se_inventa_una_exactitud_fuera_del_horizonte():
    # 3 grados a 0.003 grados/dia son mil dias. El aspecto SI se esta formando
    # -- eso se dice -- pero la fecha calculada con la velocidad de hoy seria
    # ficcion, asi que no se da.
    applying, exact_at = nce._applying_and_exact(87, 0, 90, 0.003, NOW)
    assert applying is True
    assert exact_at is None


def test_compute_transits_marca_direccion_y_exactitud():
    natal = [{"name": "sun", "longitude": 10.0}]
    datos = nce.compute_transits(natal, NOW)
    for a in datos["aspects_to_natal"]:
        assert "applying" in a and isinstance(a["applying"], bool)
        assert "exact_at" in a
        assert a["max_orb"] > 0


def test_current_positions_conserva_la_velocidad():
    # Sin velocidad no hay aplicativo/separativo: el campo es la dependencia.
    posiciones = nce.current_positions(NOW)
    assert posiciones, "el cielo no puede salir vacio"
    for cuerpo in posiciones.values():
        assert "speed" in cuerpo
        assert cuerpo["retrograde"] == (cuerpo["speed"] < 0)


# ── Los angulos ──────────────────────────────────────────────────────────────


def test_natal_targets_incluye_ascendente_y_medio_cielo():
    chart = {
        "planets": [{"name": "sun", "longitude": 10.0}],
        "ascendant": {"longitude": 200.0, "sign": "libra"},
        "midheaven": {"longitude": 110.0, "sign": "cancer"},
    }
    nombres = [p["name"] for p in nce.natal_targets(chart)]
    assert nombres == ["sun", "ascendant", "midheaven"]


def test_natal_targets_no_revienta_sin_angulos():
    # Cartas viejas cacheadas pueden no traerlos.
    assert nce.natal_targets({"planets": []}) == []
    assert nce.natal_targets({}) == []


def test_un_transito_al_ascendente_se_ve():
    # El Sol del cielo actual, con el Ascendente natal puesto justo encima:
    # conjuncion exacta que hoy seria invisible por no mirar los angulos.
    sol = nce.current_positions(NOW)["sun"]["longitude"]
    chart = {"planets": [], "ascendant": {"longitude": sol}}
    datos = nce.compute_transits(nce.natal_targets(chart), NOW)
    objetivos = {a["natal"] for a in datos["aspects_to_natal"]}
    assert "ascendant" in objetivos


def test_la_firma_vieja_sigue_funcionando():
    # /astral/transits, /overview y oracle_context la llaman asi.
    datos = nce.compute_transits([{"name": "sun", "longitude": 10.0}], NOW)
    assert set(datos) == {"datetime", "transiting", "aspects_to_natal"}


# ── Ponderacion ──────────────────────────────────────────────────────────────


def _asp(transit, natal, aspect="square", orb=1.0, max_orb=3, applying=True):
    return {"transit": transit, "natal": natal, "aspect": aspect,
            "orb": orb, "max_orb": max_orb, "applying": applying}


def test_saturno_aplicativo_al_sol_gana_a_la_luna_separativa_mas_exacta():
    # El caso que justifica toda la ponderacion: el orbe por si solo mentiria.
    saturno = _asp("saturn", "sun", orb=0.2, applying=True)
    luna = _asp("moon", "jupiter", aspect="trine", orb=0.1, applying=False)
    assert tw.weight_of(saturno) > tw.weight_of(luna)


def test_lo_aplicativo_pesa_mas_que_lo_separativo():
    assert tw.weight_of(_asp("mars", "sun", applying=True)) > \
           tw.weight_of(_asp("mars", "sun", applying=False))


def test_mas_cerca_de_la_exactitud_pesa_mas():
    assert tw.weight_of(_asp("mars", "sun", orb=0.1)) > \
           tw.weight_of(_asp("mars", "sun", orb=2.9))


def test_un_transito_a_un_eje_pesa_mas_que_a_un_planeta_lejano():
    assert tw.weight_of(_asp("saturn", "ascendant")) > \
           tw.weight_of(_asp("saturn", "jupiter"))


def test_un_cuerpo_desconocido_ni_se_ignora_ni_se_dispara():
    peso = tw.weight_of(_asp("chiron", "lilith"))
    assert 0 < peso < tw.weight_of(_asp("saturn", "sun"))


def test_el_orden_es_estable_ante_pesos_iguales():
    # Dos llamadas no pueden intercambiar el titular, o el horoscopo cambiaria
    # solo a mitad del dia.
    aspectos = [_asp("venus", "sun"), _asp("mercury", "sun")]
    primero = [(a["transit"], a["natal"]) for a in tw.rank(aspectos)]
    segundo = [(a["transit"], a["natal"]) for a in tw.rank(list(reversed(aspectos)))]
    assert primero == segundo


def test_rank_no_muta_la_entrada():
    aspectos = [_asp("mars", "sun")]
    tw.rank(aspectos)
    assert "weight" not in aspectos[0]


# ── Seleccion ────────────────────────────────────────────────────────────────


def test_sin_aspectos_no_hay_titular():
    elegido = tw.select([])
    assert elegido["primary"] is None
    assert elegido["supporting"] == []


def test_el_titular_es_el_mas_fuerte():
    fuerte = _asp("saturn", "sun", orb=0.1)
    debil = _asp("moon", "saturn", orb=2.9, applying=False)
    assert tw.select([debil, fuerte])["primary"]["transit"] == "saturn"


def test_el_acompanamiento_busca_el_otro_tempo():
    # Si manda Saturno, hace falta una voz rapida al lado: sin ella el horoscopo
    # diria lo mismo durante meses.
    aspectos = [
        _asp("saturn", "sun", orb=0.1),
        _asp("north_node", "moon", orb=2.5),
        _asp("venus", "mercury", orb=1.0),
    ]
    elegido = tw.select(aspectos, supporting=1)
    assert elegido["primary"]["transit"] == "saturn"
    assert elegido["supporting"][0]["tempo"] == tw.FAST


def test_si_no_hay_otro_tempo_se_sigue_por_peso():
    aspectos = [
        _asp("saturn", "sun", orb=0.1),
        _asp("north_node", "moon", orb=2.5),
        _asp("jupiter", "venus", orb=2.9),
    ]
    elegido = tw.select(aspectos, supporting=1)
    assert elegido["supporting"][0]["transit"] == "north_node"


def test_nadie_se_pierde_ni_se_repite():
    aspectos = [_asp("saturn", "sun"), _asp("moon", "venus"),
                _asp("mars", "mercury"), _asp("north_node", "midheaven")]
    elegido = tw.select(aspectos, supporting=2)
    reunidos = [elegido["primary"]] + elegido["supporting"] + elegido["rest"]
    assert len(reunidos) == len(aspectos)
    claves = {(a["transit"], a["natal"]) for a in reunidos}
    assert len(claves) == len(aspectos)
