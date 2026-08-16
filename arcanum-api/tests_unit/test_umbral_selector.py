"""El selector determinista de la Lectura del Umbral."""

from datetime import datetime, timedelta, timezone

import pytest

from app.services import natal_chart_engine as nce
from app.services import umbral_selector as sel

# Carta de prueba: fecha, hora y lugar concretos. No es de nadie real.
BIRTH = nce.BirthData(
    dt_utc=datetime(1990, 3, 14, 7, 30, tzinfo=timezone.utc),
    lat=6.25,
    lon=-75.56,
)
REFERENCE = datetime(2026, 8, 15, 17, 0, tzinfo=timezone.utc)


@pytest.fixture(scope="module")
def chart():
    return nce.compute_natal_chart(BIRTH)


def _sweep_dates(count=120):
    """Un ano largo de referencias, una cada tres dias."""
    start = datetime(2026, 1, 1, 12, 0, tzinfo=timezone.utc)
    return [start + timedelta(days=3 * i) for i in range(count)]


# ── Determinismo ─────────────────────────────────────────────────────────────


def test_cien_corridas_dan_exactamente_la_misma_salida(chart):
    primera = [f.to_dict() for f in sel.select_factors(chart, REFERENCE, sel.PRECISION_FULL)]
    for _ in range(99):
        actual = [f.to_dict() for f in sel.select_factors(chart, REFERENCE, sel.PRECISION_FULL)]
        assert actual == primera


def test_el_orden_no_depende_del_orden_del_diccionario(chart):
    """Empate resuelto por clave alfabetica: reordenar la carta no cambia nada."""
    revuelta = dict(chart)
    revuelta["planets"] = list(reversed(chart["planets"]))
    original = [f.to_dict() for f in sel.select_factors(chart, REFERENCE, sel.PRECISION_FULL)]
    barajada = [f.to_dict() for f in sel.select_factors(revuelta, REFERENCE, sel.PRECISION_FULL)]
    assert barajada == original


# ── Cuantos factores ─────────────────────────────────────────────────────────


def test_nunca_mas_de_dos_factores_ni_menos_de_uno(chart):
    for reference in _sweep_dates():
        for precision in (sel.PRECISION_FULL, sel.PRECISION_NO_TIME):
            factors = sel.select_factors(chart, reference, precision)
            assert 1 <= len(factors) <= 2, (reference, precision, len(factors))


def test_el_segundo_factor_no_repite_planeta_ni_receptor(chart):
    for reference in _sweep_dates():
        factors = sel.select_factors(chart, reference, sel.PRECISION_FULL)
        if len(factors) == 2:
            primero, segundo = factors
            assert primero.transit != segundo.transit
            assert primero.natal != segundo.natal


# ── La Luna no es titular ────────────────────────────────────────────────────


def test_la_luna_en_transito_nunca_entra_al_pool(chart):
    """Hace cinco aspectos exactos al dia: si entrara, no pasaria nada mas."""
    for reference in _sweep_dates():
        for factor in sel.select_factors(chart, reference, sel.PRECISION_FULL):
            if factor.kind == "transit":
                assert factor.transit != "moon"


def test_el_ritmo_lunar_nunca_se_presenta_como_titular(chart):
    for reference in _sweep_dates():
        for factor in sel.select_factors(chart, reference, sel.PRECISION_FULL):
            if factor.kind == "lunar_rhythm":
                assert factor.is_headline is False
                assert factor.label == sel.LABEL_LUNAR


# ── Sin hora natal ───────────────────────────────────────────────────────────


def test_sin_hora_natal_no_aparecen_casas_ascendente_ni_angulos(chart):
    for reference in _sweep_dates():
        for factor in sel.select_factors(chart, reference, sel.PRECISION_NO_TIME):
            assert factor.natal not in ("ascendant", "midheaven")
            assert factor.natal_house is None


def test_sin_hora_natal_la_luna_natal_queda_fuera(chart):
    """Su posicion puede desviarse 6,5 grados: cualquier aspecto suyo seria falso."""
    points = sel.NatalPoints.from_chart(chart, sel.PRECISION_NO_TIME)
    assert "moon" not in points.longitudes
    assert points.cusps is None

    con_hora = sel.NatalPoints.from_chart(chart, sel.PRECISION_FULL)
    assert "moon" in con_hora.longitudes
    assert con_hora.cusps is not None


# ── Sin carta natal ──────────────────────────────────────────────────────────


def test_sin_carta_natal_solo_queda_el_cielo_comun():
    factors = sel.select_factors(None, REFERENCE, sel.PRECISION_GENERAL)
    assert 1 <= len(factors) <= 2
    assert all(f.kind in ("lunar_rhythm", "collective") for f in factors)
    assert all(f.is_headline is False for f in factors)


# ── Aritmetica de "dias a exacto" ────────────────────────────────────────────


def test_dias_a_exacto_es_positivo_cuando_el_aspecto_se_esta_formando():
    # Transito en 8 grados, natal en 10, conjuncion, avanzando a 1 grado/dia.
    assert sel.days_to_exact(8.0, 1.0, 10.0, 0) == pytest.approx(2.0)


def test_dias_a_exacto_es_negativo_cuando_el_aspecto_ya_paso():
    assert sel.days_to_exact(12.0, 1.0, 10.0, 0) == pytest.approx(-2.0)


def test_dias_a_exacto_respeta_la_retrogradacion():
    # Retrogrado (velocidad negativa) acercandose desde delante.
    assert sel.days_to_exact(12.0, -1.0, 10.0, 0) == pytest.approx(2.0)


def test_dias_a_exacto_toma_el_encuentro_mas_cercano_en_el_tiempo():
    """Un aspecto es exacto en +angulo y en -angulo; gana el que llegue antes."""
    assert sel.days_to_exact(100.0, 1.0, 10.0, 90) == pytest.approx(0.0, abs=1e-9)


def test_sin_velocidad_no_hay_dias_a_exacto():
    assert sel.days_to_exact(10.0, 0.0, 10.0, 0) is None


def test_ningun_factor_supera_la_ventana_de_un_dia(chart):
    for reference in _sweep_dates():
        for factor in sel.select_factors(chart, reference, sel.PRECISION_FULL):
            if factor.days_to_exact is not None:
                assert abs(factor.days_to_exact) <= sel.MAX_DAYS_TO_EXACT


# ── Tension ──────────────────────────────────────────────────────────────────


def test_la_tension_solo_se_declara_entre_armonico_y_tenso():
    armonico = sel.Factor(kind="transit", label="x", is_headline=True, score=1, valence="harmonic")
    tenso = sel.Factor(kind="transit", label="x", is_headline=True, score=1, valence="tense")
    neutro = sel.Factor(kind="transit", label="x", is_headline=True, score=1, valence="neutral")

    assert sel.has_tension([armonico, tenso]) is True
    assert sel.has_tension([armonico, neutro]) is False
    assert sel.has_tension([tenso, neutro]) is False
    assert sel.has_tension([tenso]) is False
