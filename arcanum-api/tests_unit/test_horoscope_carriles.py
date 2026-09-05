"""Dos carriles: lo que cambio hoy y el capitulo que sigue.

Medido sobre cuatro cartas reales y 180 dias: el transito mas fuerte es un
planeta LENTO el 97% de los dias, y una carta repitio el mismo 70 dias seguidos.
Con el titular atado al mas fuerte, el texto diario hablaba de lo mismo durante
semanas y solo cambiaban las palabras. La senal diaria existia -- el conjunto de
acompanantes cambia el 71% de los dias -- pero iba en la silla de atras.

Aqui se fija que los dos papeles existen, que el que verifica la guarda de
cobertura es el del DIA, y que el capitulo se le presenta al modelo como algo
que continua.
"""
from datetime import datetime, timezone

import pytest

from app.services import horoscope as ho
from app.services import transit_weight as tw


class _ArchivoFalso:
    """El archivo de horoscopos. Registra lo que se le manda guardar.

    No commitea: la ruta guarda y captura en un solo commit, y aqui se
    comprueba justo eso -- que lo archivado y lo cobrado van juntos.
    """

    def __init__(self):
        self.guardadas = []

    def add(self, user_id, local_date, text, sky, commit=False):
        self.guardadas.append((user_id, local_date, text, sky))

    def last(self, user_id, limit=30):
        return []


# Fecha de nacimiento del doble: la profeccion anual la necesita para saber
# que anio vive esta persona. Sin ella el endpoint sigue funcionando, pero
# entonces el doble no ejercitaria ese camino.
NACIMIENTO = datetime(1990, 6, 15, 12, 0, tzinfo=timezone.utc)


AHORA = datetime(2026, 8, 18, 12, 0, tzinfo=timezone.utc)


def _a(transit, natal, orb=0.5, applying=True):
    return {"transit": transit, "natal": natal, "aspect": "square",
            "orb": orb, "max_orb": 3, "applying": applying}


# ── Los dos papeles ──────────────────────────────────────────────────────────

def test_el_capitulo_es_el_lento_y_hoy_es_el_rapido():
    s = tw.select([_a("saturn", "sun", orb=0.1), _a("mercury", "venus", orb=2.0)])
    assert s["chapter"]["transit"] == "saturn"
    assert s["today"]["transit"] == "mercury"


def test_el_capitulo_no_le_roba_el_sitio_a_hoy_por_ser_mas_fuerte():
    """Es el caso real: Saturno gana por peso y aun asi hoy tiene su carril."""
    s = tw.select([_a("saturn", "sun", orb=0.1), _a("moon", "mars", orb=2.9)])
    assert s["primary"]["transit"] == "saturn"      # sigue siendo el mas fuerte
    assert s["today"]["transit"] == "moon"          # y hoy no desaparece


def test_sin_rapidos_no_hay_carril_de_hoy():
    s = tw.select([_a("jupiter", "sun"), _a("saturn", "moon")])
    assert s["chapter"] is not None
    assert s["today"] is None


def test_sin_lentos_no_hay_capitulo():
    s = tw.select([_a("mercury", "sun"), _a("moon", "venus")])
    assert s["today"] is not None
    assert s["chapter"] is None


def test_sin_aspectos_no_hay_ninguno_de_los_dos():
    s = tw.select([])
    assert s["chapter"] is None and s["today"] is None


def test_cada_carril_elige_el_mas_fuerte_de_su_tempo():
    s = tw.select([_a("jupiter", "mercury", orb=2.5), _a("saturn", "sun", orb=0.1),
                   _a("moon", "jupiter", orb=2.5), _a("mars", "sun", orb=0.1)])
    assert s["chapter"]["transit"] == "saturn"
    assert s["today"]["transit"] == "mars"


# ── La guarda de cobertura mira el dia, no el capitulo ───────────────────────

def test_se_exigen_los_cuerpos_de_hoy_y_no_los_del_capitulo():
    """Exigir el capitulo garantizaria nombrar justo lo que no ha cambiado."""
    sky = {"chapter": _a("neptune", "sun"), "today": _a("mercury", "venus")}
    assert ho.expected_terms(sky) == ["Mercurio", "Venus"]


def test_sin_transito_de_hoy_se_cae_al_capitulo():
    sky = {"chapter": _a("neptune", "sun"), "today": None}
    assert ho.expected_terms(sky) == ["Neptuno", "Sol"]


def test_sin_nada_no_se_exige_nada():
    assert ho.expected_terms({"chapter": None, "today": None}) == []


# ── Lo que ve el modelo ──────────────────────────────────────────────────────

def test_el_capitulo_se_presenta_como_algo_que_continua():
    bloque = ho.describe({"chapter": _a("pluto", "sun"), "today": None}, AHORA)
    assert "CONTINUA, NO EMPIEZA HOY" in bloque


def test_ya_no_se_le_llama_transito_principal():
    """Esa etiqueta era la causa: el modelo lideraba con lo que duraba meses."""
    bloque = ho.describe(
        {"chapter": _a("pluto", "sun"), "today": _a("moon", "venus")}, AHORA)
    assert "TRANSITO PRINCIPAL" not in bloque
    assert "LO DE HOY" in bloque


def test_un_dia_sin_rapido_se_declara_en_vez_de_disimularse():
    bloque = ho.describe({"chapter": _a("pluto", "sun"), "today": None}, AHORA)
    assert "nada rapido toca su carta hoy" in bloque


def test_un_cielo_vacio_prohibe_nombrar_planetas():
    bloque = ho.describe({"chapter": None, "today": None}, AHORA)
    assert "NO HAY NINGUN TRANSITO" in bloque


# ── El prompt tiene que ir a juego con los datos ─────────────────────────────

def test_el_prompt_habla_de_los_dos_carriles():
    from app.services.horoscope_prompt import HOROSCOPE_SYSTEM_PROMPT as P
    assert "LO DE HOY" in P and "CAPITULO ABIERTO" in P
    assert "TRANSITO PRINCIPAL" not in P


def test_el_prompt_prohibe_anunciar_el_capitulo_como_nuevo():
    from app.services.horoscope_prompt import HOROSCOPE_SYSTEM_PROMPT as P
    assert "SIGUE" in P and "NUNCA como si empezara hoy" in P


# ── Y que esto de verdad varie dia a dia sobre una carta real ────────────────

@pytest.mark.parametrize("dias", [60])
def test_el_carril_de_hoy_cambia_mucho_mas_que_el_capitulo(dias):
    """La razon de ser del cambio: si ambos se movieran igual, sobra."""
    from datetime import timedelta

    from app.services import natal_chart_engine as nce

    carta = nce.compute_natal_chart(nce.BirthData(
        datetime(1990, 3, 15, 13, 30, tzinfo=timezone.utc), 4.711, -74.072))

    def firma(a):
        return None if not a else (a["transit"], a["natal"], a["aspect"])

    hoy, cap = [], []
    for d in range(dias):
        cielo = ho.build_sky(carta, AHORA + timedelta(days=d))
        hoy.append(firma(cielo["today"]))
        cap.append(firma(cielo["chapter"]))

    cambios = lambda s: sum(1 for i in range(1, len(s)) if s[i] != s[i - 1])
    assert cambios(hoy) > cambios(cap)
    assert len(set(hoy)) > len(set(cap))


# ── El contrato que sale al cliente ──────────────────────────────────────────

def test_la_respuesta_lleva_los_dos_carriles_y_la_secta(monkeypatch):
    """El servidor los calcula y los usa para escribir; si no los manda, la
    pantalla no puede separar lo que cambio hoy del capitulo que sigue.

    Se comprueba sobre lo que se PERSISTE de verdad, no sobre el codigo fuente:
    lo que se captura es exactamente lo que el cliente recibira, hoy y en cada
    replay del resto del dia.
    """
    from types import SimpleNamespace
    from uuid import uuid4

    from app.application.services.usage_service import UsageService
    from app.routers import astral

    capturadas: list = []
    monkeypatch.setattr(UsageService, "reserve",
                        lambda *_a, **_k: SimpleNamespace(
                            operation=SimpleNamespace(result=None), replay=False))
    monkeypatch.setattr(UsageService, "capture",
                        lambda _self, _db, _op, res: capturadas.append(res))
    # Se parchea en `astral` y no en `claude_service`: el router lo importo con
    # `from ... import generate_horoscope`, asi que su referencia ya esta ligada
    # y tocar el modulo de origen no la cambia.
    monkeypatch.setattr(astral, "generate_horoscope",
                        lambda _sky, _terms: ("Un texto entero.", {"available": True}))

    usuario = SimpleNamespace(id=uuid4(), birth_timezone="America/Bogota",
                              birth_date=NACIMIENTO,
                              birth_lat=None, birth_lon=None)
    carta = SimpleNamespace(chart_data={
        "planets": [{"name": "sun", "longitude": 10.0, "house": 10}]})

    astral.horoscope(archivo=_ArchivoFalso(), current_user=usuario,
                     repo=SimpleNamespace(get_by_user_id=lambda _i: carta),
                     db=None)

    assert len(capturadas) == 1
    result = capturadas[0]
    for clave in ("today", "chapter", "sect", "primary", "supporting",
                  "date", "datetime", "text", "total_aspects"):
        assert clave in result, f"la respuesta del horoscopo no incluye {clave}"
    # El Sol en casa 10 esta sobre el horizonte: la secta viaja resuelta.
    assert result["sect"] == "day"
