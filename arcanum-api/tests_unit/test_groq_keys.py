# -*- coding: utf-8 -*-
"""El reparto entre varias claves de Groq.

POR QUE EXISTE, con el numero que lo motivo: una llamada de horoscopo son 4.360
tokens y el plan gratuito da 8.000 por MINUTO, asi que con una clave el techo
real es ~1 lectura por minuto. Rotar es la unica palanca que sube ese techo.

Lo que vigilan estos tests es la contabilidad del reparto, que es donde duele
equivocarse: repartir mal (y no multiplicar nada), insistir en una clave que ya
dijo 429, o dar vueltas quemando cupo.
"""
import time

import pytest

from app.services import groq_keys as gk


@pytest.fixture(autouse=True)
def _limpio(monkeypatch):
    """Cada test arranca con su propio rotador y sin clientes de verdad."""
    monkeypatch.setattr(gk, "Groq", lambda api_key: f"cliente:{api_key}")
    gk.reiniciar()
    yield
    gk.reiniciar()


def _config(monkeypatch, principal=None, extra=None):
    monkeypatch.setattr(gk.settings, "GROQ_API_KEY", principal, raising=False)
    monkeypatch.setattr(gk.settings, "GROQ_API_KEYS", extra, raising=False)
    gk.reiniciar()


def test_sin_ninguna_clave_no_hay_de_donde_tirar(monkeypatch):
    _config(monkeypatch, None, None)
    assert len(gk.rotador()) == 0
    assert gk.rotador().siguiente() is None


def test_con_una_sola_clave_nada_cambia(monkeypatch):
    # La condicion para poder desplegar esto sin tocar el entorno.
    _config(monkeypatch, "k1")
    rot = gk.rotador()
    assert len(rot) == 1
    assert rot.siguiente().cliente == "cliente:k1"
    assert rot.siguiente().cliente == "cliente:k1"


def test_las_tres_se_reparten_por_turnos(monkeypatch):
    # Si no rotara, la primera agotaria su minuto y las otras dos mirarian.
    _config(monkeypatch, "k1", "k2,k3")
    rot = gk.rotador()
    assert len(rot) == 3
    vistas = [rot.siguiente().valor for _ in range(6)]
    assert vistas == ["k1", "k2", "k3", "k1", "k2", "k3"]


def test_la_principal_va_primera_y_no_se_duplica(monkeypatch):
    # Pegar las tres en GROQ_API_KEYS incluyendo la principal es lo que va a
    # pasar en la consola, y no puede acabar con la misma clave dos veces.
    _config(monkeypatch, "k1", " k1 , k2 ,, k3 ")
    assert [c.valor for c in gk.rotador()._claves] == ["k1", "k2", "k3"]


def test_una_clave_con_429_se_aparta_el_tiempo_que_pide(monkeypatch):
    _config(monkeypatch, "k1", "k2,k3")
    rot = gk.rotador()
    primera = rot.siguiente()
    rot.enfriar(primera, 30)
    assert rot.disponibles == 2
    # Y ya no sale en el reparto mientras este fria.
    assert primera.valor not in [rot.siguiente().valor for _ in range(6)]


def test_el_enfriado_caduca_y_la_clave_vuelve(monkeypatch):
    _config(monkeypatch, "k1", "k2")
    rot = gk.rotador()
    c = rot.siguiente()
    rot.enfriar(c, 0.05)
    assert rot.disponibles == 1
    time.sleep(0.08)
    assert rot.disponibles == 2


def test_sin_retry_after_se_aparta_poco(monkeypatch):
    # Un castigo largo cuando falta el dato regalaria capacidad que quiza ya
    # estaba: el 429 de minuto se apaga en segundos.
    _config(monkeypatch, "k1", "k2")
    rot = gk.rotador()
    c = rot.siguiente()
    rot.enfriar(c, None)
    assert c.frio_hasta - time.monotonic() == pytest.approx(
        gk.ENFRIADO_POR_DEFECTO, abs=1.0
    )


def test_con_todas_frias_no_queda_ninguna(monkeypatch):
    _config(monkeypatch, "k1", "k2")
    rot = gk.rotador()
    for c in list(rot._claves):
        rot.enfriar(c, 60)
    assert rot.siguiente() is None
    assert rot.alternativas(set()) == []


def test_alternativas_no_repite_las_ya_probadas(monkeypatch):
    # Sin esto, una racha de 429 daria vueltas sobre las mismas claves.
    _config(monkeypatch, "k1", "k2,k3")
    rot = gk.rotador()
    restantes = rot.alternativas({0, 1})
    assert [c.valor for c in restantes] == ["k3"]


def test_un_cliente_de_fuera_no_pertenece_a_la_rotacion(monkeypatch):
    # Es lo que hace que los dobles de los tests sigan el camino de siempre.
    #
    # Se compara por IDENTIDAD y no por igualdad a proposito: dos clientes de
    # Groq con la misma clave son objetos distintos con su propio pool de
    # conexiones, y confundirlos enfriaria la clave equivocada. Por eso aqui se
    # pasa el objeto que el rotador guarda, no uno igual.
    _config(monkeypatch, "k1", "k2")
    rot = gk.rotador()
    suyo = rot._claves[1].cliente
    assert rot.por_cliente(suyo) is not None
    assert rot.por_cliente(suyo).valor == "k2"
    assert rot.por_cliente(object()) is None


# ── El salto a otra clave dentro de `_complete` ──────────────────────────────
#
# El reparto por turnos sube el techo; este salto es lo que evita que un 429 de
# minuto --- que se toca constantemente, porque una llamada se lleva 4.360 de
# los 8.000 --- llegue a quien pregunta.

from types import SimpleNamespace  # noqa: E402

from fastapi import HTTPException  # noqa: E402
from groq import RateLimitError  # noqa: E402

from app.services import claude_service as cs  # noqa: E402


def _respuesta(texto="ok"):
    return SimpleNamespace(
        choices=[SimpleNamespace(message=SimpleNamespace(content=texto),
                                 finish_reason="stop")],
        usage=SimpleNamespace(completion_tokens=3, prompt_tokens=100,
                              prompt_tokens_details=None),
    )


def _rate_limit(segundos="7"):
    # `RateLimitError` pide una respuesta con `.request`: el SDK la guarda para
    # poder reintentar, aunque aqui no se use.
    resp = SimpleNamespace(headers={"retry-after": segundos}, request=None,
                           status_code=429)
    return RateLimitError("429", response=resp, body=None)


class _ClienteFalso:
    """Un cliente que falla las primeras `fallos` veces y luego responde."""

    def __init__(self, fallos=0):
        self.fallos = fallos
        self.llamadas = 0
        self.chat = SimpleNamespace(completions=SimpleNamespace(create=self._create))

    def _create(self, **_kw):
        self.llamadas += 1
        if self.fallos > 0:
            self.fallos -= 1
            raise _rate_limit()
        return _respuesta()


def _rotador_con(monkeypatch, clientes):
    """Monta un rotador cuyas claves son los clientes dados."""
    gk.reiniciar()
    it = iter(clientes)
    monkeypatch.setattr(gk, "Groq", lambda api_key: next(it))
    monkeypatch.setattr(gk.settings, "GROQ_API_KEY", "k1", raising=False)
    monkeypatch.setattr(
        gk.settings, "GROQ_API_KEYS",
        ",".join(f"k{i + 2}" for i in range(len(clientes) - 1)) or None,
        raising=False,
    )
    return gk.rotador()


def test_si_la_primera_da_429_se_prueba_la_siguiente(monkeypatch):
    c1, c2 = _ClienteFalso(fallos=1), _ClienteFalso()
    rot = _rotador_con(monkeypatch, [c1, c2])

    texto, _fin, _tok = cs._complete(rot._claves[0].cliente, "m", "sys", "user",
                                     100, 0.5)

    assert texto == "ok"
    assert c1.llamadas == 1 and c2.llamadas == 1
    # Y la que fallo queda apartada el tiempo que pidio.
    assert rot._claves[0].frio_hasta > 0


def test_con_todas_saturadas_se_rinde_con_429_y_sin_dar_vueltas(monkeypatch):
    c1, c2, c3 = (_ClienteFalso(fallos=9) for _ in range(3))
    rot = _rotador_con(monkeypatch, [c1, c2, c3])

    with pytest.raises(HTTPException) as exc:
        cs._complete(rot._claves[0].cliente, "m", "sys", "user", 100, 0.5)

    assert exc.value.status_code == 429
    # CADA clave una sola vez: sin esto, una racha quemaria cupo en circulos.
    assert [c.llamadas for c in (c1, c2, c3)] == [1, 1, 1]


def test_un_cliente_ajeno_no_salta_a_ninguna_parte(monkeypatch):
    # Los dobles de los otros tests siguen el camino de siempre: un 429 suyo
    # sale como 429 y no arrastra a las claves de verdad.
    _rotador_con(monkeypatch, [_ClienteFalso(), _ClienteFalso()])
    ajeno = _ClienteFalso(fallos=1)

    with pytest.raises(HTTPException) as exc:
        cs._complete(ajeno, "m", "sys", "user", 100, 0.5)

    assert exc.value.status_code == 429
    assert ajeno.llamadas == 1


def test_el_tiempo_de_castigo_sale_de_la_cabecera():
    assert cs._retry_after(_rate_limit("42")) == 42.0
    assert cs._retry_after(_rate_limit("")) is None
    sin_respuesta = _rate_limit("7")
    sin_respuesta.response = None
    assert cs._retry_after(sin_respuesta) is None
