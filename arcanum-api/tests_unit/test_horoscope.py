"""El horoscopo diario: fecha local, idempotencia y la guarda de cobertura.

Sin red y sin base de datos: Groq va mockeado y se cuentan las invocaciones.
"""
from datetime import datetime, timezone
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.application.services.usage_service import UsageService
from app.routers import astral
from app.services import claude_service as cs
from app.services import horoscope as hs

NOW = datetime(2026, 8, 16, 15, 0, tzinfo=timezone.utc)


# ── La fecha es la de la persona, no la de UTC ───────────────────────────────


def test_la_fecha_es_la_local_y_no_la_de_utc():
    # 02:00 UTC del 17 son las 21:00 del 16 en Bogota. El horoscopo de esa
    # persona no puede cambiar mientras aun es de dia para ella.
    en_utc = datetime(2026, 8, 17, 2, 0, tzinfo=timezone.utc)
    assert hs.local_date("America/Bogota", en_utc).isoformat() == "2026-08-16"
    assert en_utc.date().isoformat() == "2026-08-17"


def test_sin_zona_o_con_zona_invalida_se_cae_a_utc_sin_reventar():
    assert hs.local_date(None, NOW) == NOW.date()
    assert hs.local_date("Marte/Olympus", NOW) == NOW.date()
    assert hs.local_date("", NOW) == NOW.date()


# ── Que se le exige al modelo ────────────────────────────────────────────────


def test_los_terminos_exigidos_son_los_dos_cuerpos_en_espanol():
    # `expected_terms` pasa a recibir el cielo entero y no un transito suelto:
    # ahora elige el carril del DIA, que es lo que hace diario a un horoscopo.
    sky = {"today": {"transit": "saturn", "natal": "ascendant", "aspect": "square"},
           "chapter": None}
    assert hs.expected_terms(sky) == ["Saturno", "Ascendente"]


def test_sin_ningun_transito_no_se_exige_nada():
    assert hs.expected_terms({"today": None, "chapter": None}) == []


def test_sin_transitos_se_le_prohibe_inventar_uno():
    texto = hs.describe({"primary": None, "supporting": []}, NOW)
    assert "NO inventes un transito" in texto


def test_sin_lugar_confirmado_no_se_sustituye_la_hora_planetaria():
    # La regla que dejo el corte de Bogota: ausencia declarada, nunca una
    # ciudad por defecto.
    texto = hs.describe({"primary": None, "supporting": []}, NOW, planetary_hour=None)
    assert "no disponible" in texto
    assert "No la menciones ni la sustituyas" in texto


def test_la_direccion_del_transito_llega_al_modelo():
    aplicativo = {"transit": "saturn", "natal": "sun", "aspect": "square",
                  "orb": 0.2, "applying": True, "exact_at": "2026-08-20T00:00:00+00:00",
                  "tempo": "slow"}
    linea = hs._describe_aspect(aplicativo)
    assert "APLICATIVO" in linea and "2026-08-20" in linea
    assert "capitulo de meses" in linea

    separativo = {**aplicativo, "applying": False, "exact_at": None, "tempo": "fast"}
    assert "SEPARATIVO" in hs._describe_aspect(separativo)


# ── La guarda de cobertura (guard D) ─────────────────────────────────────────


class _FakeGroq:
    """Cuenta invocaciones y devuelve las respuestas que se le den, en orden."""

    def __init__(self, *respuestas):
        self.respuestas = list(respuestas)
        self.llamadas = 0
        self.chat = SimpleNamespace(completions=SimpleNamespace(create=self._create))

    def _create(self, **kwargs):
        self.llamadas += 1
        texto = self.respuestas.pop(0)
        return SimpleNamespace(
            choices=[SimpleNamespace(message=SimpleNamespace(content=texto),
                                     finish_reason="stop")],
            usage=SimpleNamespace(completion_tokens=len(texto)),
        )


def test_un_texto_que_nombra_su_transito_no_reintenta(monkeypatch):
    cliente = _FakeGroq("Saturno aprieta sobre tu Sol natal y pide oficio.")
    monkeypatch.setattr(cs, "_get_client", lambda: cliente)

    texto, diag = cs.generate_horoscope("cielo", ["Saturno", "Sol"])

    assert diag["retried"] is False
    assert cliente.llamadas == 1
    assert "Saturno" in texto


def test_un_horoscopo_generico_dispara_el_reintento(monkeypatch):
    # La red tiene que PESCAR, no solo pasar: este texto podria ser de
    # cualquiera, y es exactamente lo que no se quiere publicar.
    generico = "Hoy es un dia de cambios. Confia en el universo."
    cliente = _FakeGroq(generico, "Saturno cuadra tu Sol natal: hay que sostener.")
    monkeypatch.setattr(cs, "_get_client", lambda: cliente)

    texto, diag = cs.generate_horoscope("cielo", ["Saturno", "Sol"])

    assert diag["retried"] is True
    assert diag["missing_first"] == ["Saturno", "Sol"]
    assert diag["missing_final"] == []
    assert cliente.llamadas == 2
    assert "Saturno" in texto


def test_no_se_reintenta_mas_de_una_vez_y_falla_ruidoso(monkeypatch, caplog):
    generico = "Hoy es un dia de cambios."
    cliente = _FakeGroq(generico, generico)
    monkeypatch.setattr(cs, "_get_client", lambda: cliente)

    _texto, diag = cs.generate_horoscope("cielo", ["Saturno", "Sol"])

    assert cliente.llamadas == 2, "nunca mas de un reintento"
    assert diag["missing_final"] == ["Saturno", "Sol"]
    assert any(r.levelname == "WARNING" for r in caplog.records), "debe fallar ruidoso"


def test_sin_clave_de_groq_no_hay_horoscopo(monkeypatch):
    monkeypatch.setattr(cs, "_get_client", lambda: None)
    texto, diag = cs.generate_horoscope("cielo", ["Saturno", "Sol"])
    assert diag["available"] is False
    assert texto == cs._FALLBACK


# ── El endpoint ──────────────────────────────────────────────────────────────


def _user(tz="America/Bogota"):
    return SimpleNamespace(id=uuid4(), birth_timezone=tz,
                           birth_lat=None, birth_lon=None)


class _Repo:
    def __init__(self, chart):
        self._chart = chart

    def get_by_user_id(self, _user_id):
        return self._chart


def _chart():
    return SimpleNamespace(chart_data={"planets": [{"name": "sun", "longitude": 10.0}]})


def test_sin_carta_natal_responde_404():
    with pytest.raises(HTTPException) as error:
        astral.horoscope(current_user=_user(), repo=_Repo(None), db=None)
    assert error.value.status_code == 404


def test_la_segunda_llamada_del_dia_es_un_replay_sin_tocar_el_modelo(monkeypatch):
    guardado = {"date": "2026-08-16", "text": "el horoscopo de hoy"}
    operacion = SimpleNamespace(result=guardado)
    monkeypatch.setattr(
        UsageService, "reserve",
        lambda *_a, **_k: SimpleNamespace(operation=operacion, replay=True))

    llamadas = []
    monkeypatch.setattr(astral, "generate_horoscope",
                        lambda *a, **k: llamadas.append(a) or ("nuevo", {"available": True}))

    resultado = astral.horoscope(current_user=_user(), repo=_Repo(_chart()), db=None)

    assert resultado == guardado
    assert llamadas == [], "un replay no puede gastar una llamada al modelo"


def test_la_clave_de_idempotencia_lleva_la_fecha_local(monkeypatch):
    claves = []

    def _reserve(_self, _db, _uid, action, key, _payload, _limit):
        claves.append((action, key))
        return SimpleNamespace(operation=SimpleNamespace(result={}), replay=True)

    monkeypatch.setattr(UsageService, "reserve", _reserve)
    monkeypatch.setattr(astral, "datetime",
                        SimpleNamespace(now=lambda _tz=None: datetime(2026, 8, 17, 2, 0, tzinfo=timezone.utc)))

    astral.horoscope(current_user=_user("America/Bogota"), repo=_Repo(_chart()), db=None)

    assert claves == [("horoscope", "horoscope-2026-08-16")]


def test_sin_modelo_se_libera_la_reserva_y_no_se_guarda_el_relleno(monkeypatch):
    operacion = SimpleNamespace(result=None)
    liberadas, capturadas = [], []
    monkeypatch.setattr(
        UsageService, "reserve",
        lambda *_a, **_k: SimpleNamespace(operation=operacion, replay=False))
    monkeypatch.setattr(UsageService, "reverse",
                        lambda _self, _db, op: liberadas.append(op))
    monkeypatch.setattr(UsageService, "capture",
                        lambda _self, _db, op, res: capturadas.append(res))
    monkeypatch.setattr(astral, "generate_horoscope",
                        lambda *_a, **_k: (cs._FALLBACK, {"available": False}))

    with pytest.raises(HTTPException) as error:
        astral.horoscope(current_user=_user(), repo=_Repo(_chart()), db=None)

    assert error.value.status_code == 503
    assert liberadas == [operacion]
    assert capturadas == [], "el texto de desarrollo no puede quedar como el horoscopo del dia"


def test_un_fallo_inesperado_libera_la_reserva(monkeypatch):
    operacion = SimpleNamespace(result=None)
    liberadas = []
    monkeypatch.setattr(
        UsageService, "reserve",
        lambda *_a, **_k: SimpleNamespace(operation=operacion, replay=False))
    monkeypatch.setattr(UsageService, "reverse",
                        lambda _self, _db, op: liberadas.append(op))
    monkeypatch.setattr(astral, "generate_horoscope",
                        lambda *_a, **_k: (_ for _ in ()).throw(RuntimeError("groq caido")))

    with pytest.raises(RuntimeError):
        astral.horoscope(current_user=_user(), repo=_Repo(_chart()), db=None)

    assert liberadas == [operacion], "una reserva sin resultado no puede quedarse colgada"


def test_el_horoscopo_generado_se_captura_con_su_transito(monkeypatch):
    operacion = SimpleNamespace(result=None)
    capturadas = []
    monkeypatch.setattr(
        UsageService, "reserve",
        lambda *_a, **_k: SimpleNamespace(operation=operacion, replay=False))
    monkeypatch.setattr(UsageService, "capture",
                        lambda _self, _db, op, res: capturadas.append(res))
    monkeypatch.setattr(astral, "generate_horoscope",
                        lambda *_a, **_k: ("Saturno sobre tu Sol.", {"available": True}))

    resultado = astral.horoscope(current_user=_user(), repo=_Repo(_chart()), db=None)

    assert resultado["text"] == "Saturno sobre tu Sol."
    assert "primary" in resultado and "total_aspects" in resultado
    assert capturadas == [resultado]
