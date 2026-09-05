# -*- coding: utf-8 -*-
"""La ventana de generacion por plan: premium a diario, gratis cada dos dias.

Lo que se fija:
  - que la ventana la decide el PLAN y no otra cosa
  - que el segundo dia del plan gratuito es un replay, no una generacion
  - que ese replay se declara como lo que es (`is_previous`), en vez de pasar
    por lectura de hoy
  - que quien estrena el segundo dia de su ventana recibe el cielo de HOY
  - que el sello (`/sky-today`) no cambia por plan: es calculo y es gratis
"""
from datetime import date, datetime, timedelta, timezone
from types import SimpleNamespace
from uuid import uuid4

import pytest

from app.application.services.usage_service import UsageService
from app.core.config import settings
from app.routers import astral
from app.services import horoscope as ho

AHORA = datetime(2026, 9, 5, 12, 0, tzinfo=timezone.utc)
NACIMIENTO = datetime(1990, 6, 15, 12, tzinfo=timezone.utc)


class _ArchivoFalso:
    def __init__(self):
        self.guardadas = []

    def add(self, user_id, local_date, text, sky, commit=False):
        self.guardadas.append((local_date, text))

    def last(self, user_id, limit=30):
        return []


class _Repo:
    def __init__(self, chart):
        self._chart = chart

    def get_by_user_id(self, _uid):
        return SimpleNamespace(chart_data=self._chart)


def _chart():
    return {
        "planets": [{"name": "sun", "longitude": 10.0, "house": 10},
                    {"name": "moon", "longitude": 130.0, "house": 3}],
        "ascendant": {"longitude": 200.0, "sign": "libra"},
        "midheaven": {"longitude": 110.0},
        "houses": [{"house": i + 1, "longitude": (200 + 30 * i) % 360}
                   for i in range(12)],
    }


def _user(tier="free", tz="America/Bogota"):
    return SimpleNamespace(id=uuid4(), birth_timezone=tz, subscription_tier=tier,
                           birth_date=NACIMIENTO, birth_lat=None, birth_lon=None)


# ── La funcion de ventana, sola ───────────────────────────────────────────────

def test_con_ventana_de_un_dia_la_clave_es_el_dia():
    for d in (date(2026, 9, 4), date(2026, 9, 5), date(2026, 9, 6)):
        assert ho.clave_del_periodo(d, 1) == d


def test_los_dias_se_agrupan_de_dos_en_dos():
    """El invariante, no una pareja elegida a mano.

    Que pareja concreta forman el 4 y el 5 depende de la paridad del dia
    juliano, y fijar eso en un test seria fijar un detalle de calendario en vez
    de la regla. Lo que importa es que cada clave gobierne EXACTAMENTE dos
    dias seguidos.
    """
    dias = [date(2026, 9, 3) + timedelta(days=i) for i in range(10)]
    claves = [ho.clave_del_periodo(d, 2) for d in dias]

    from collections import Counter
    cuenta = Counter(claves)
    # las de los extremos pueden salir cortadas por el borde de la muestra
    completas = [n for c, n in cuenta.items() if c != claves[0] and c != claves[-1]]
    assert completas and all(n == 2 for n in completas)


def test_cada_clave_es_el_primer_dia_de_su_pareja():
    for i in range(10):
        d = date(2026, 9, 3) + timedelta(days=i)
        clave = ho.clave_del_periodo(d, 2)
        assert clave in (d, d - timedelta(days=1))


def test_la_ventana_se_ancla_al_calendario_y_es_pura():
    """Misma entrada, misma salida, sin depender de cuando se pregunte."""
    d = date(2026, 9, 5)
    assert ho.clave_del_periodo(d, 2) == ho.clave_del_periodo(d, 2)
    assert ho.clave_del_periodo(d, 2) <= d


@pytest.mark.parametrize("cada", [0, 1, -3])
def test_una_ventana_absurda_no_agrupa_nada(cada):
    d = date(2026, 9, 5)
    assert ho.clave_del_periodo(d, cada) == d


# ── El endpoint: que clave se usa segun el plan ───────────────────────────────

def _claves(monkeypatch, tier, dias):
    """Las claves de idempotencia con las que se reserva en `dias` dias."""
    vistas = []

    def falsa_reserve(_self, _db, _uid, action, key, _payload, _limite):
        vistas.append(key)
        return SimpleNamespace(
            operation=SimpleNamespace(result={"date": "x", "text": "t"}),
            replay=False)

    monkeypatch.setattr(UsageService, "reserve", falsa_reserve)
    monkeypatch.setattr(UsageService, "capture", lambda *a, **k: None)
    monkeypatch.setattr(astral, "generate_horoscope",
                        lambda *a, **k: ("texto", {"available": True}))
    usuario = _user(tier)
    for d in dias:
        monkeypatch.setattr(astral, "datetime",
                            SimpleNamespace(now=lambda _tz=None, _d=d: _d))
        astral.horoscope(archivo=_ArchivoFalso(), current_user=usuario,
                         repo=_Repo(_chart()), db=None)
    return vistas


DIA_A = datetime(2026, 9, 4, 18, tzinfo=timezone.utc)   # 4-sep en Bogota
DIA_B = datetime(2026, 9, 5, 18, tzinfo=timezone.utc)   # 5-sep en Bogota


def test_premium_estrena_clave_cada_dia(monkeypatch):
    claves = _claves(monkeypatch, "premium", [DIA_A, DIA_B])
    assert claves == ["horoscope-2026-09-04", "horoscope-2026-09-05"]


def test_el_plan_gratuito_repite_clave_en_dias_alternos(monkeypatch):
    """Cuatro dias seguidos dan DOS claves, no cuatro.

    Si diera cuatro, el segundo dia generaria otra vez y el plan gratuito seria
    exactamente el premium.
    """
    # Se arranca en un dia que ABRE ventana, preguntandoselo a la propia
    # funcion: si el test eligiera la fecha a mano, dependeria de la paridad
    # del calendario y fallaria cambiando el mes.
    inicio = next(d for d in (date(2026, 9, 4) + timedelta(days=i)
                              for i in range(2))
                  if ho.clave_del_periodo(d, 2) == d)
    dias = [datetime(inicio.year, inicio.month, inicio.day + i, 18,
                     tzinfo=timezone.utc) for i in range(4)]

    assert len(set(_claves(monkeypatch, "free", dias))) == 2
    assert len(set(_claves(monkeypatch, "premium", dias))) == 4


def test_la_ventana_sale_de_los_ajustes_y_no_de_un_numero_suelto():
    assert settings.HOROSCOPE_FREE_EVERY_DAYS == 2
    assert settings.HOROSCOPE_PREMIUM_EVERY_DAYS == 1


# ── El replay se declara, no se disfraza ──────────────────────────────────────

def _replay(monkeypatch, guardado, ahora=AHORA):
    monkeypatch.setattr(astral, "datetime",
                        SimpleNamespace(now=lambda _tz=None: ahora))
    monkeypatch.setattr(
        UsageService, "reserve",
        lambda *a, **k: SimpleNamespace(
            operation=SimpleNamespace(result=guardado), replay=True))
    return astral.horoscope(archivo=_ArchivoFalso(), current_user=_user(),
                            repo=_Repo(_chart()), db=None)


def test_una_lectura_de_ayer_llega_marcada(monkeypatch):
    salida = _replay(monkeypatch, {"date": "2026-09-04", "text": "la de ayer"})
    assert salida["is_previous"] is True
    assert salida["date"] == "2026-09-04"
    assert salida["requested_date"] == "2026-09-05"
    assert salida["text"] == "la de ayer"


def test_la_misma_lectura_del_mismo_dia_no_se_marca(monkeypatch):
    """Abrir dos veces hoy no puede parecer que se te sirve lo de ayer."""
    salida = _replay(monkeypatch, {"date": "2026-09-05", "text": "la de hoy"})
    assert salida["is_previous"] is False


def test_el_replay_no_toca_lo_guardado(monkeypatch):
    guardado = {"date": "2026-09-04", "text": "la de ayer"}
    _replay(monkeypatch, guardado)
    assert guardado == {"date": "2026-09-04", "text": "la de ayer"}, (
        "la procedencia depende de que dia es hoy: congelarla en la fila la "
        "volveria mentira manana"
    )


# ── Lo que se genera es el cielo de HOY ───────────────────────────────────────

def test_estrenar_el_segundo_dia_de_la_ventana_da_el_cielo_de_hoy(monkeypatch):
    """El caso que se escapa si la clave decide tambien el contenido.

    Alguien del plan gratuito que abre por primera vez el segundo dia de su
    ventana reserva con la clave de ayer -- pero lee el cielo de HOY, y su
    lectura se archiva con la fecha de hoy.
    """
    archivo = _ArchivoFalso()
    monkeypatch.setattr(astral, "datetime",
                        SimpleNamespace(now=lambda _tz=None: DIA_B))
    monkeypatch.setattr(
        UsageService, "reserve",
        lambda *a, **k: SimpleNamespace(
            operation=SimpleNamespace(result=None), replay=False))
    monkeypatch.setattr(UsageService, "capture", lambda *a, **k: None)
    monkeypatch.setattr(astral, "generate_horoscope",
                        lambda *a, **k: ("texto de hoy", {"available": True}))

    salida = astral.horoscope(archivo=archivo, current_user=_user(),
                              repo=_Repo(_chart()), db=None)

    assert salida["date"] == "2026-09-05"
    assert salida["is_previous"] is False
    assert archivo.guardadas[0][0] == date(2026, 9, 5)


# ── El sello no entra en esto ─────────────────────────────────────────────────

def test_el_sello_no_mira_el_plan(monkeypatch):
    """`/sky-today` es calculo: gratis, diario y para todo el mundo."""
    monkeypatch.setattr(astral, "datetime",
                        SimpleNamespace(now=lambda _tz=None: AHORA))
    monkeypatch.setattr(UsageService, "reserve",
                        lambda *a, **k: pytest.fail("el sello no reserva cupo"))

    gratis = astral.sky_today(current_user=_user("free"), repo=_Repo(_chart()))
    premium = astral.sky_today(current_user=_user("premium"), repo=_Repo(_chart()))

    assert gratis["date"] == premium["date"] == "2026-09-05"
    assert gratis["today"] == premium["today"]
