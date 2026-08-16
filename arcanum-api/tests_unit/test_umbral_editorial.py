"""Adversariales de contenido de la Lectura del Umbral.

El texto no lo escribe un modelo: se compone de un corpus finito. Por eso aqui
no se muestrea, se BARRE. Si una formula prohibida existe en algun sitio del
corpus o en alguna combinacion de factores, estos tests la encuentran.
"""

from datetime import datetime, timedelta, timezone

import pytest

from app.services import natal_chart_engine as nce
from app.services import umbral_editorial as ed
from app.services import umbral_selector as sel

BIRTH = nce.BirthData(
    dt_utc=datetime(1990, 3, 14, 7, 30, tzinfo=timezone.utc),
    lat=6.25,
    lon=-75.56,
)

WINDOW = {
    "timezone": "America/Bogota",
    "local_date": "2026-08-15",
    "starts_at": "2026-08-15T05:00:00+00:00",
    "ends_at": "2026-08-16T05:00:00+00:00",
    "reference_at": "2026-08-15T17:00:00+00:00",
}

# ── Lo que la lectura no puede decir jamas ───────────────────────────────────

PREDICCION_DETERMINISTA = [
    "vas a ", "verás cómo", "te espera", "ocurrirá", "sucederá", "pasará",
    "predice", "sin duda", "seguro que", "será un día", "hoy tendrás",
    "recibirás", "conocerás a", "llegará ",
]

CONSEJO_IMPERATIVO = [
    "debes ", "deberías", "tienes que", "evita ", "no hagas", "aprovecha para",
    "asegúrate", "procura ", "conviene que",
]

MEDICO = [
    "salud", "enfermedad", "síntoma", "medicamento", "medicación", "dolencia",
    "curar", "diagnóstico", "embarazo", "fertilidad", "terapia", "tratamiento",
    "ansiedad", "depresión", "insomnio",
]

LEGAL = [
    "contrato", "demanda", "abogado", "litigio", "notario", "juicio legal",
    "denuncia", "herencia",
]

FINANCIERO = [
    "dinero", "inversión", "invertir", "invierte", "deuda", "ahorro",
    "comprar", "vender", "sueldo", "ganancia", "pérdida económica",
]

VINCULO = [
    "tu pareja", "tu relación", "ruptura", "conquistar", "reconciliación",
    "te dejará", "tu ex",
]

MIEDO_URGENCIA = [
    "peligro", "urgente", "última oportunidad", "no dejes pasar", "amenaza",
    "cuidado con", "riesgo de", "crisis", "antes de que sea tarde",
]

PROHIBIDAS = (
    PREDICCION_DETERMINISTA
    + CONSEJO_IMPERATIVO
    + MEDICO
    + LEGAL
    + FINANCIERO
    + VINCULO
    + MIEDO_URGENCIA
)


@pytest.fixture(scope="module")
def chart():
    return nce.compute_natal_chart(BIRTH)


def _flatten(reading: dict) -> list[str]:
    """Toda cadena que la lectura pone delante de una persona."""
    texts = [reading["headline"], reading["practice"]]
    texts.extend(reading["headlines"])
    texts.extend(reading["observed_sky"])
    texts.extend(reading["symbolic_reading"])
    texts.extend(reading["why_today"])
    texts.extend(reading["limits"])
    texts.extend(source["text"] for source in reading["sources"])
    if reading.get("tension_note"):
        texts.append(reading["tension_note"])
    return texts


def _all_readings(chart):
    """Barrido amplio: dos anos de fechas por cada nivel de precision."""
    start = datetime(2026, 1, 1, 12, 0, tzinfo=timezone.utc)
    for i in range(120):
        reference = start + timedelta(days=6 * i)
        for precision, data in (
            (sel.PRECISION_FULL, chart),
            (sel.PRECISION_NO_TIME, chart),
            (sel.PRECISION_GENERAL, None),
        ):
            factors = sel.select_factors(data, reference, precision)
            yield precision, factors, ed.compose(factors, WINDOW, precision)


# ── Barrido del corpus fijo ──────────────────────────────────────────────────


def test_ninguna_constante_del_corpus_contiene_formula_prohibida():
    for text in ed.all_corpus_strings():
        bajo = text.lower()
        for formula in PROHIBIDAS:
            assert formula not in bajo, f"«{formula}» en: {text}"


# ── Barrido de todo lo generable ─────────────────────────────────────────────


def test_barrido_completo_sin_una_sola_afirmacion_prohibida(chart):
    revisadas = 0
    for _precision, _factors, reading in _all_readings(chart):
        for text in _flatten(reading):
            bajo = text.lower()
            for formula in PROHIBIDAS:
                assert formula not in bajo, f"«{formula}» en: {text}"
            revisadas += 1
    # Un barrido que no barre nada pasaria en verde sin mirar nada.
    assert revisadas > 3000


def test_la_lectura_simbolica_siempre_habla_en_condicional(chart):
    marcas = ("permite observar", "puede invitar", "la tradición lee", "no dice")
    for _precision, _factors, reading in _all_readings(chart):
        texto = " ".join(reading["symbolic_reading"]).lower()
        assert any(marca in texto for marca in marcas), texto


# ── Todo hecho procede del motor ─────────────────────────────────────────────


def test_la_interpretacion_no_lleva_ni_un_numero(chart):
    """Invariante duro: si el texto simbolico no puede contener cifras, no puede
    colar un hecho fabricado. Los numeros viven solo donde los pone el motor."""
    for _precision, _factors, reading in _all_readings(chart):
        for text in reading["symbolic_reading"]:
            assert not any(char.isdigit() for char in text), text
        assert not any(char.isdigit() for char in reading["practice"])


def test_cada_cifra_del_cielo_observado_sale_del_factor(chart):
    for _precision, factors, reading in _all_readings(chart):
        cielo = " ".join(reading["observed_sky"])
        for factor in factors:
            if factor.kind == "lunar_rhythm":
                moon = factor.moon or {}
                assert str(moon["age_days"]) in cielo
                continue
            assert str(factor.angle) in cielo
            assert str(factor.orb) in cielo
        # La ventana local siempre se nombra: sin ella "hoy" no significa nada.
        assert WINDOW["local_date"] in cielo
        assert WINDOW["timezone"] in cielo


# ── Casos declarados ─────────────────────────────────────────────────────────


def test_sin_hora_natal_la_lectura_declara_lo_que_deja_fuera(chart):
    factors = sel.select_factors(
        chart, datetime(2026, 8, 15, 17, 0, tzinfo=timezone.utc), sel.PRECISION_NO_TIME
    )
    reading = ed.compose(factors, WINDOW, sel.PRECISION_NO_TIME)
    limites = " ".join(reading["limits"])
    assert "no nombra casas" in limites
    assert "Luna natal" in limites
    assert "Casa natal receptora" not in " ".join(reading["observed_sky"])


def test_sin_carta_la_lectura_dice_que_no_esta_personalizada(chart):
    factors = sel.select_factors(
        None, datetime(2026, 8, 15, 17, 0, tzinfo=timezone.utc), sel.PRECISION_GENERAL
    )
    reading = ed.compose(factors, WINDOW, sel.PRECISION_GENERAL)
    assert reading["is_personalized"] is False
    assert "No está personalizada" in " ".join(reading["limits"])


def test_la_tension_se_muestra_separada_y_sin_moraleja():
    armonico = sel.Factor(
        kind="transit", label=sel.LABEL_PERSONAL, is_headline=True, score=900,
        valence="harmonic", transit="jupiter", natal="sun", aspect="trine",
        angle=120, orb=0.5, days_to_exact=0.2, applying=True,
        transit_sign_es="Leo", transit_degree=3.0, natal_sign_es="Aries",
    )
    tenso = sel.Factor(
        kind="transit", label=sel.LABEL_PERSONAL, is_headline=True, score=800,
        valence="tense", transit="saturn", natal="venus", aspect="square",
        angle=90, orb=0.8, days_to_exact=-0.4, applying=False,
        transit_sign_es="Piscis", transit_degree=11.0, natal_sign_es="Sagitario",
    )
    reading = ed.compose([armonico, tenso], WINDOW, sel.PRECISION_FULL)

    assert reading["tension"] is True
    assert "no apuntan al mismo sitio" in reading["tension_note"]
    # Dos titulares separados, no uno fundido.
    assert len(reading["headlines"]) == 2
    assert reading["headlines"][0] != reading["headlines"][1]


def test_las_fuentes_separan_astronomia_tradicion_e_interpretacion():
    capas = {source["layer"] for source in ed.SOURCES}
    assert capas == {"astronomía", "tradición", "interpretación ARCANUM"}


def test_los_limites_siempre_dicen_que_la_lectura_no_es_prueba(chart):
    for _precision, _factors, reading in _all_readings(chart):
        assert ed.LIMIT_SCIENCE in reading["limits"]
