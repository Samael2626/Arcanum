"""Lo que el modelo devuelve mal NO puede llegar a la base de datos.

Tres fallos que la guarda de cobertura de terminos NO ve, porque ella solo mira
si el texto NOMBRA lo que debia nombrar:

  - `finish_reason == "length"`: el techo de tokens se quedo corto y el texto
    acaba a media frase. Puede haber nombrado todas las cartas y aun asi no
    servir.
  - texto vacio: el modelo gasto el presupuesto entero razonando y no escribio.
  - 429 de Groq: la cuenta tiene un techo de tokens por minuto muy bajo.

En los tres casos la reserva de cuota tiene que quedar LIBERADA, porque si no,
`UsageService.reserve` responde 409 "sigue en curso" y esa persona se queda sin
horoscopo el resto del dia.

Groq va mockeado entero: estos tests no gastan un solo token.
"""
from datetime import datetime, timezone
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi import HTTPException
from groq import RateLimitError

from app.application.services.usage_service import UsageService
from app.core.config import settings
from app.routers import astral
from app.services import claude_service as cs


class _FakeGroq:
    """Devuelve las respuestas que se le den, en orden, y cuenta invocaciones.

    Cada respuesta es (texto, finish_reason). Un elemento que sea una excepcion
    se lanza en vez de devolverse. Agotada la lista, repite la ultima: al
    reintento de cobertura le da igual lo que responda, y fijar aqui su numero
    exacto haria que estos tests fallasen por algo que no es lo suyo.
    """

    def __init__(self, *respuestas):
        self.respuestas = list(respuestas)
        self.llamadas = 0
        self.kwargs: list[dict] = []
        self.chat = SimpleNamespace(completions=SimpleNamespace(create=self._create))

    def _create(self, **kwargs):
        self.llamadas += 1
        self.kwargs.append(kwargs)
        item = self.respuestas.pop(0) if len(self.respuestas) > 1 else self.respuestas[0]
        if isinstance(item, Exception):
            raise item
        texto, finish = item
        return SimpleNamespace(
            choices=[SimpleNamespace(message=SimpleNamespace(content=texto),
                                     finish_reason=finish)],
            usage=SimpleNamespace(completion_tokens=len(texto)),
        )


def _rate_limit_error(retry_after: str = "17"):
    """El RateLimitError tal y como lo levanta el SDK de groq."""
    response = SimpleNamespace(
        headers={"retry-after": retry_after}, status_code=429, request=None)
    return RateLimitError("rate limit", response=response, body=None)


# ── La guarda de truncado, en el camino del horoscopo ────────────────────────


def test_un_horoscopo_truncado_no_esta_disponible(monkeypatch, caplog):
    # Nombra los dos cuerpos del transito, asi que la guarda de COBERTURA lo da
    # por bueno. La de truncado es la unica que lo puede pescar.
    cortado = "Saturno cuadra tu Sol natal y pide oficio; lo que hoy se sost"
    cliente = _FakeGroq((cortado, "length"))
    monkeypatch.setattr(cs, "_get_client", lambda: cliente)

    _texto, diag = cs.generate_horoscope("cielo", ["Saturno", "Sol"])

    assert diag["missing_first"] == [], "la guarda de cobertura no ve el truncado"
    assert diag["available"] is False
    assert diag["unavailable_reason"] == cs.UNAVAILABLE_TRUNCATED
    assert any(r.levelname == "WARNING" for r in caplog.records)


def test_un_horoscopo_vacio_no_esta_disponible(monkeypatch, caplog):
    cliente = _FakeGroq(("   \n  ", "stop"), ("   \n  ", "stop"))
    monkeypatch.setattr(cs, "_get_client", lambda: cliente)

    _texto, diag = cs.generate_horoscope("cielo", ["Saturno", "Sol"])

    assert diag["available"] is False
    assert diag["unavailable_reason"] == cs.UNAVAILABLE_EMPTY
    assert any(r.levelname == "WARNING" for r in caplog.records)


def test_el_motivo_del_truncado_se_distingue_del_de_sin_clave(monkeypatch):
    monkeypatch.setattr(cs, "_get_client", lambda: None)
    _texto, sin_clave = cs.generate_horoscope("cielo", ["Saturno", "Sol"])

    assert sin_clave["available"] is False
    assert sin_clave["unavailable_reason"] == cs.UNAVAILABLE_NO_API_KEY
    assert cs.UNAVAILABLE_NO_API_KEY not in cs.INVALID_OUTPUT_REASONS, (
        "una instalacion sin clave no es una respuesta invalida del modelo"
    )


# ── La guarda de truncado, en el camino del oraculo ──────────────────────────


def test_una_lectura_truncada_no_se_devuelve_como_texto(monkeypatch):
    cliente = _FakeGroq(("El Loco abre el camino y el Mago lo ord", "length"))
    monkeypatch.setattr(cs, "_get_client", lambda: cliente)

    with pytest.raises(HTTPException) as error:
        cs.get_claude_response(context="cielo", question="que hago",
                               model="modelo-de-prueba")

    assert error.value.status_code == 503


def test_una_lectura_vacia_no_se_devuelve_como_texto(monkeypatch):
    cliente = _FakeGroq(("", "stop"))
    monkeypatch.setattr(cs, "_get_client", lambda: cliente)

    with pytest.raises(HTTPException) as error:
        cs.get_claude_response(context="cielo", question="que hago",
                               model="modelo-de-prueba")

    assert error.value.status_code == 503


def test_sin_clave_el_oraculo_sigue_devolviendo_el_texto_de_desarrollo(monkeypatch):
    # Este camino NO cambia: sin clave no hay 503, hay fallback de desarrollo.
    monkeypatch.setattr(cs, "_get_client", lambda: None)
    assert cs.get_claude_response(context="cielo", model="m") == cs._FALLBACK


# ── El 429 de Groq ───────────────────────────────────────────────────────────


def test_el_rate_limit_de_groq_sale_como_429(monkeypatch, caplog):
    cliente = _FakeGroq(_rate_limit_error("17"))
    monkeypatch.setattr(cs, "_get_client", lambda: cliente)

    with pytest.raises(HTTPException) as error:
        cs.get_claude_response(context="cielo", question="que hago", model="m")

    assert error.value.status_code == 429
    assert any("retry_after=17" in r.getMessage() for r in caplog.records), (
        "el retry-after tiene que quedar en el log para poder dimensionarlo"
    )


def test_el_rate_limit_no_queda_disfrazado_de_texto_del_oraculo(monkeypatch):
    # `get_claude_response` atrapa Exception para no reventar la peticion; el
    # 429 tiene que pasar POR ENCIMA de ese except, o se persiste como lectura.
    cliente = _FakeGroq(_rate_limit_error())
    monkeypatch.setattr(cs, "_get_client", lambda: cliente)

    with pytest.raises(HTTPException):
        cs.get_claude_response(context="cielo", model="m")


# ── El modelo sale de settings, no de una constante ──────────────────────────


def test_no_queda_ningun_id_de_modelo_hardcodeado():
    import inspect

    fuente = inspect.getsource(cs)
    assert "_GROQ_MODEL" not in fuente
    # Con comillas: el docstring lo NOMBRA a proposito para contar por que se
    # fue. Lo que no puede volver es un literal de modelo en el codigo.
    for comilla in ('"', "'"):
        assert f"{comilla}llama-3.3-70b-versatile{comilla}" not in fuente, (
            "el modelo retirado que tumbo produccion no puede volver al codigo"
        )


def test_el_modelo_del_oraculo_llega_desde_el_llamador(monkeypatch):
    cliente = _FakeGroq(("una lectura entera y cerrada.", "stop"))
    monkeypatch.setattr(cs, "_get_client", lambda: cliente)

    cs.get_claude_response(context="cielo", question="q", model="modelo-inyectado")

    assert cliente.kwargs[0]["model"] == "modelo-inyectado"


def test_el_horoscopo_usa_el_modelo_free_de_settings(monkeypatch):
    monkeypatch.setattr(settings, "ORACLE_MODEL_FREE", "modelo-free-de-settings")
    cliente = _FakeGroq(("Saturno sobre tu Sol, entero.", "stop"))
    monkeypatch.setattr(cs, "_get_client", lambda: cliente)

    cs.generate_horoscope("cielo", ["Saturno", "Sol"])

    assert cliente.kwargs[0]["model"] == "modelo-free-de-settings"


def test_el_oraculo_pasa_el_modelo_premium_o_free_segun_el_tramo():
    import inspect

    from app.routers import oracle

    fuente = inspect.getsource(oracle)
    assert "settings.ORACLE_MODEL_PREMIUM if is_premium else settings.ORACLE_MODEL_FREE" in fuente


# ── Los techos medidos ───────────────────────────────────────────────────────


def test_los_techos_cubren_lo_que_el_modelo_gasta_de_verdad():
    # Medido contra la API real: tarot chico gasta 2000+, cruz celta 2594,
    # horoscopo 1117. El razonamiento es coste casi fijo, asi que el suelo de
    # las tiradas chicas tiene que ser generoso aunque solo saque 3 cartas.
    assert cs._max_tokens_for(3) >= 3000
    assert cs._max_tokens_for(10) >= 3500
    assert cs._HOROSCOPE_MAX_TOKENS >= 2000


def test_una_tirada_chica_no_gasta_mucho_menos_techo_que_la_cruz_celta():
    # El razonamiento NO escala con las cartas: si el techo de 3 fuese una
    # fraccion del de 10, volveria a truncar.
    assert cs._max_tokens_for(3) > cs._max_tokens_for(10) * 0.7


def test_el_entorno_solo_puede_subir_el_techo(monkeypatch):
    monkeypatch.setattr(settings, "CLAUDE_MAX_TOKENS", 256)
    assert cs._max_tokens_for(3) >= 3000, "un valor corto en el entorno no puede truncar"
    monkeypatch.setattr(settings, "CLAUDE_MAX_TOKENS", 8000)
    assert cs._max_tokens_for(3) == 8000


def test_no_se_manda_reasoning_effort_por_defecto(monkeypatch):
    # `reasoning_effort=low` empobrece el texto (se salta el regente del dia y
    # la hora planetaria). Se queda el razonamiento por defecto del modelo.
    cliente = _FakeGroq(("Saturno sobre tu Sol, entero.", "stop"))
    monkeypatch.setattr(cs, "_get_client", lambda: cliente)

    cs.generate_horoscope("cielo", ["Saturno", "Sol"])

    assert "reasoning_effort" not in cliente.kwargs[0]


# ── El endpoint: nada invalido se persiste y la reserva siempre se libera ────


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


def _espia_reserva(monkeypatch):
    """Cablea UsageService y devuelve (operacion, liberadas, capturadas)."""
    operacion = SimpleNamespace(result=None)
    liberadas: list = []
    capturadas: list = []
    monkeypatch.setattr(
        UsageService, "reserve",
        lambda *_a, **_k: SimpleNamespace(operation=operacion, replay=False))
    monkeypatch.setattr(UsageService, "reverse",
                        lambda _self, _db, op: liberadas.append(op))
    monkeypatch.setattr(UsageService, "capture",
                        lambda _self, _db, op, res: capturadas.append(res))
    return operacion, liberadas, capturadas


@pytest.mark.parametrize("texto,finish", [
    ("Saturno cuadra tu Sol y lo que hoy se sost", "length"),
    ("", "stop"),
])
def test_un_horoscopo_invalido_no_se_persiste_y_libera_la_reserva(
        monkeypatch, texto, finish):
    operacion, liberadas, capturadas = _espia_reserva(monkeypatch)
    cliente = _FakeGroq((texto, finish), (texto, finish))
    monkeypatch.setattr(cs, "_get_client", lambda: cliente)

    with pytest.raises(HTTPException) as error:
        astral.horoscope(current_user=_user(), repo=_Repo(_chart()), db=None)

    assert error.value.status_code == 503
    assert capturadas == [], "un texto cortado no puede quedar como el horoscopo del dia"
    assert liberadas == [operacion]


def test_el_429_libera_la_reserva_del_horoscopo(monkeypatch):
    operacion, liberadas, capturadas = _espia_reserva(monkeypatch)
    monkeypatch.setattr(cs, "_get_client", lambda: _FakeGroq(_rate_limit_error()))

    with pytest.raises(HTTPException) as error:
        astral.horoscope(current_user=_user(), repo=_Repo(_chart()), db=None)

    assert error.value.status_code == 429
    assert capturadas == []
    assert liberadas == [operacion], (
        "sin esto la reserva queda en 'reserved' y reserve() responde 409 el resto del dia"
    )


def test_cualquier_httpexception_del_horoscopo_libera_la_reserva(monkeypatch):
    # El caso general del bug: `except HTTPException: raise` dejaba colgada
    # CUALQUIER salida por HTTPException, no solo la del 429.
    operacion, liberadas, _capturadas = _espia_reserva(monkeypatch)
    monkeypatch.setattr(
        astral, "generate_horoscope",
        lambda *_a, **_k: (_ for _ in ()).throw(HTTPException(502, "proveedor caido")))

    with pytest.raises(HTTPException) as error:
        astral.horoscope(current_user=_user(), repo=_Repo(_chart()), db=None)

    assert error.value.status_code == 502
    assert liberadas == [operacion]


def test_un_horoscopo_valido_si_se_captura(monkeypatch):
    _operacion, liberadas, capturadas = _espia_reserva(monkeypatch)
    entero = "Saturno cuadra tu Sol natal: hoy se sostiene lo que ya estaba en pie."
    monkeypatch.setattr(cs, "_get_client", lambda: _FakeGroq((entero, "stop")))
    monkeypatch.setattr(astral, "datetime",
                        SimpleNamespace(now=lambda _tz=None: datetime(
                            2026, 8, 16, 15, 0, tzinfo=timezone.utc)))

    resultado = astral.horoscope(current_user=_user(), repo=_Repo(_chart()), db=None)

    assert resultado["text"] == entero
    assert capturadas == [resultado]
    assert liberadas == []
