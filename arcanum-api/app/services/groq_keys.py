"""Reparto de las llamadas entre varias claves de Groq.

POR QUE, con los numeros medidos el 29-sep-2026. El system prompt del
horoscopo son 4.360 tokens, y el plan gratuito da 8.000 POR MINUTO: una sola
lectura se lleva mas de la mitad del minuto y la segunda rebota. El techo real
del horoscopo es **~1 por minuto**, no las 30 que sugiere el limite de
peticiones. El cuello no es el cupo diario: es el del minuto.

De las palancas que se estudiaron, esta es la UNICA que sube el techo en vez de
bajar el coste por llamada. Con tres claves, ~3 por minuto y ~600.000 tokens al
dia en vez de 200.000. Decision de Samuel del 28-sep-2026.

COMO REPARTE, y por que asi:

- **Por turnos, no "la primera hasta que reviente".** Con una sola clave activa
  se agota su minuto y las otras dos se quedan mirando; el reparto por turnos
  mantiene las tres frias y es lo que multiplica el TPM de verdad.
- **Una clave que devuelve 429 se aparta**, el tiempo que diga su cabecera
  `retry-after`. Sin eso, un tercio de las llamadas seguiria yendo a una clave
  que ya dijo que no. El 429 de minuto se apaga en segundos y el de dia tarda,
  y por eso el tiempo lo manda la respuesta y no una constante de aqui.
- **Cada clave se prueba como mucho UNA vez por llamada.** El techo sigue
  siendo el que era; lo que cambia es que se agota el de las tres y no el de
  una. Sin ese limite, una racha de 429 daria vueltas quemando cupo.

LO QUE ESTO NO ARREGLA: el coste por llamada. Sigue siendo el mismo, y la
cache de prompt de Groq --que lo haria casi gratis-- **no funciona en esta
cuenta**, medido el 29-sep con cuatro llamadas seguidas a la misma region sin
un solo acierto. Ver la nota del vault.
"""
from __future__ import annotations

import logging
import threading
import time
from dataclasses import dataclass, field

from groq import Groq

from app.core.config import settings

logger = logging.getLogger("arcanum.groq")

# Cuanto se aparta una clave cuando el 429 no trae `retry-after`. Corto a
# proposito: si el que falta es el minuto, un castigo largo regalaria capacidad
# que ya estaba disponible.
ENFRIADO_POR_DEFECTO = 60.0


def claves_configuradas() -> list[str]:
    """Las claves, sin repetidas y en orden estable.

    `GROQ_API_KEY` sigue siendo la principal y se mantiene la primera: quien
    tenga una sola configurada no nota nada, que es la condicion para que esto
    se pueda desplegar sin tocar el entorno.

    `GROQ_API_KEYS` admite varias separadas por comas. Se acepta que venga con
    espacios y con la principal repetida dentro, porque escribir las tres en la
    misma variable es lo que va a hacer quien las pegue de la consola.
    """
    crudas: list[str] = []
    if settings.GROQ_API_KEY:
        crudas.append(settings.GROQ_API_KEY)
    extra = getattr(settings, "GROQ_API_KEYS", None) or ""
    crudas.extend(extra.split(","))

    vistas: set[str] = set()
    limpias: list[str] = []
    for c in crudas:
        c = c.strip()
        if c and c not in vistas:
            vistas.add(c)
            limpias.append(c)
    return limpias


@dataclass
class _Clave:
    indice: int
    valor: str
    cliente: Groq
    #  Instante (monotónico) hasta el que NO se usa. 0 = disponible.
    frio_hasta: float = 0.0


@dataclass
class Rotador:
    """Reparte por turnos y aparta las que dicen 429.

    Guarda un cliente por clave: `Groq()` abre su propio pool de conexiones y
    crear uno por llamada tiraria el reuso de sockets, que es justo lo que hace
    barata la segunda peticion.
    """

    _claves: list[_Clave] = field(default_factory=list)
    _turno: int = 0
    _lock: threading.Lock = field(default_factory=threading.Lock)

    def __post_init__(self) -> None:
        for i, valor in enumerate(claves_configuradas()):
            self._claves.append(_Clave(indice=i, valor=valor,
                                       cliente=Groq(api_key=valor)))

    def __len__(self) -> int:
        return len(self._claves)

    @property
    def disponibles(self) -> int:
        ahora = time.monotonic()
        return sum(1 for c in self._claves if c.frio_hasta <= ahora)

    def siguiente(self) -> _Clave | None:
        """La clave que toca, saltando las apartadas. None si no queda ninguna.

        Avanza el turno UNA vez por llamada, de modo que dos peticiones
        seguidas no caen en la misma clave aunque las dos acierten.
        """
        with self._lock:
            if not self._claves:
                return None
            ahora = time.monotonic()
            total = len(self._claves)
            arranque = self._turno % total
            self._turno = (self._turno + 1) % total
            for salto in range(total):
                c = self._claves[(arranque + salto) % total]
                if c.frio_hasta <= ahora:
                    return c
            return None

    def alternativas(self, ya_probadas: set[int]) -> list[_Clave]:
        """Las claves frias que esta llamada todavia no ha probado.

        Sin el registro de probadas, una racha de 429 daria vueltas sobre las
        mismas claves quemando cupo. Cada una, como mucho una vez por llamada.
        """
        with self._lock:
            ahora = time.monotonic()
            return [c for c in self._claves
                    if c.indice not in ya_probadas and c.frio_hasta <= ahora]

    def por_cliente(self, cliente: Groq) -> _Clave | None:
        """La clave a la que pertenece un cliente, o None si es de fuera.

        Devuelve None para los dobles de los tests, y eso es lo que hace que el
        camino de siempre siga siendo el de siempre cuando no hay rotacion.
        """
        for c in self._claves:
            if c.cliente is cliente:
                return c
        return None

    def enfriar(self, clave: _Clave, segundos: float | None) -> None:
        """Aparta una clave el tiempo que ella misma pidio."""
        espera = ENFRIADO_POR_DEFECTO if not segundos or segundos <= 0 else segundos
        with self._lock:
            clave.frio_hasta = time.monotonic() + espera
        logger.warning(
            "Clave de Groq #%d apartada %.0fs por 429. Quedan %d de %d.",
            clave.indice, espera, self.disponibles, len(self._claves),
        )


_rotador: Rotador | None = None
_rotador_lock = threading.Lock()


def rotador() -> Rotador:
    """El rotador del proceso, creado una sola vez."""
    global _rotador
    if _rotador is None:
        with _rotador_lock:
            if _rotador is None:
                _rotador = Rotador()
                logger.info("Groq: %d clave(s) configurada(s).", len(_rotador))
    return _rotador


def reiniciar() -> None:
    """Tira el rotador. Solo para los tests, que cambian el entorno."""
    global _rotador
    with _rotador_lock:
        _rotador = None
