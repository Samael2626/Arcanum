# Checkpoint — La hora planetaria del Tarot

- **Fecha:** 2026-08-16
- **Rama:** `feat/nombre-y-umbral-foundation`
- **SHA:** `5f4ec60 fix(tarot): dejar de sellar la hora planetaria de Bogota`
- **Worktree:** `D:/tmp/nombre-y-umbral-foundation`
- **Alcance:** solo el camino que sella la hora planetaria de una tirada. Sin
  rediseno del Tarot, sin creditos, sin tocar el Umbral.

## El tercer escape, y por que era el peor

`routers/tarot.py:119` (antes del arreglo):

```python
hour = ph.get_planetary_hour(now, 4.71, -74.07).planet
```

Los dos escapes anteriores — `/astral/today` y `oracle_context` — **mostraban**
un dato falso. Este lo **escribia**. El valor se persiste en
`divination_session.planetary_hour` y de ahi el Grimorio lo sella.

No es imprecision. A un mismo instante UTC, alguien en Madrid puede estar en
otra hora planetaria y hasta bajo otro regente del dia. Un dato falso escrito en
la base es indistinguible de uno verdadero para siempre: nadie que abra su
Grimorio dentro de un ano tiene forma de saber que esa hora no era la suya.

## Por que se escapo

Las dos redes que existian estaban tejidas a la medida del pez que ya se habia
visto:

- El barrido de Flutter recorre `lib/` — no ve Python.
- `tests_unit/test_oracle_context_sin_fallback.py:49` hace
  `inspect.getsource(oracle_context)` — solo ese modulo.

Ninguna de las dos podia ver el tercero. No fue descuido de quien reviso: fue
una red del tamano exacto del problema conocido.

## El arreglo

`_sky_snapshot(now)` pasa a `_sky_snapshot(now, user)`. Criterio **copiado** de
`oracle_context._coords`, no reinventado: la decision editorial ya estaba tomada
y no admite dos versiones.

- Con `birth_lat`/`birth_lon` confirmados: se calcula con esas coordenadas.
- Sin ellas: `planetary_hour = None`. La tirada se guarda sin anotacion astral
  en vez de con una falsa, exactamente como ya hacia el Grimorio.

Dos detalles que no son cosmeticos:

1. **La ausencia se decide ANTES de llamar al motor.** El `except (AttributeError,
   ValueError)` que ya estaba ahi no habria atrapado unas coordenadas `None`:
   `get_planetary_hour(now, None, None)` levanta `TypeError` y se habria
   escapado como un 500. Un `return` explicito, no una excepcion atrapada por
   casualidad.
2. **Se anade `AstralCalculationError` al catch.** Antes no podia darse, porque
   Bogotá siempre tiene orto y ocaso. Con coordenadas reales, un usuario en
   region polar no los tiene ese dia y el motor lanza. Ahora eso da `None`, no
   un 500 en mitad de una tirada ya cobrada.

Un objeto de usuario **sin** `birth_lat` sigue levantando `AttributeError` a
proposito: eso es un error de programa, no una ausencia de lugar. Se corrigio el
doble de `tests_unit/test_usage_service.py`, que declaraba un `SimpleNamespace`
incompleto, en vez de ensanchar el catch.

## Lo que NO se toco

- **`moon_phase` se queda igual.** La fase lunar es global: la misma para todo
  el mundo en el mismo instante. Solo la hora planetaria depende del observador,
  porque sale del orto y el ocaso locales. Ampliar el arreglo a la Luna habria
  sido romper algo que funciona. Hay test de que sigue llegando con y sin
  coordenadas.
- **El instante.** `datetime.now(timezone.utc)` es correcto: una hora planetaria
  se ancla a un instante absoluto. El error estaba en el lugar, no en el reloj.
- **Ninguna migracion Alembic.** Sigue vigente la prohibicion.

## La red ensanchada

`tests_unit/test_no_bogota_backend.py` recorre **todo `arcanum-api/app`**: 85
modulos, uno por test parametrizado, mas un test que verifica que el barrido
barre de verdad (un barrido que no encuentra archivos pasa en verde sin mirar
nada).

Analiza el **AST**, no el texto crudo. Es deliberado: los docstrings que
EXPLICAN el bug tienen que poder citar la coordenada. Prohibir la palabra
obligaria a borrar la explicacion de por que existe el test, que es la forma mas
segura de que alguien lo relaje el dia que estorbe.

Verificado que la red pesca, no solo que pasa: ejecutada contra el `tarot.py`
anterior al arreglo, lo senala en la linea 119 con las dos constantes.

```
tarot.py PRE-arreglo  -> [(119, 4.71), (119, 74.07)]
tarot.py POST-arreglo -> limpio
```

## Pruebas

Rojo antes, verde despues. La evidencia del rojo:

```
tests/test_tarot.py::test_sin_coordenadas_la_hora_planetaria_no_se_sella FAILED
tests/test_tarot.py::test_el_spread_completo_respeta_la_misma_regla     FAILED
E       AssertionError: assert 'mars' is None
```

`'mars'` era la hora de Bogotá sellada a un usuario que nunca declaro estar
alli.

Tests nuevos (`tests/test_tarot.py`):

- Sin coordenadas: `planetary_hour is None`, y ademas distinto de la hora de
  Bogotá calculada en el propio test — para que siga significando algo el dia
  que el planeta de turno cambie.
- Con coordenadas (Madrid): se usan esas, **verificado contra el motor**, no
  contra el texto de la respuesta.
- La Luna sigue llegando sin coordenadas.
- `draw_spread` respeta la misma regla: comparte `_sky_snapshot` y el arreglo
  tenia que cubrir los dos caminos.
- La replay por `Idempotency-Key` sigue devolviendo lo mismo.

**Backend 364 verdes** (273 antes, +91). **Flutter 288 verdes**, sin cambios.
`flutter analyze lib` 0 issues. `git diff --check` limpio. CJK y codificacion
limpios.

De paso, un hallazgo lateral: los tests de tirada que ya existian
(`test_draw_one_con_auth_devuelve_lectura` y compania) nunca mandaban la
cabecera `Idempotency-Key`, que es obligatoria. Aceptaban `(200, 422)` y siempre
recibian 422: no ejercitaban ni una tirada. Los nuevos si la mandan. No se
tocaron los viejos: es un commit aparte.

## Decision pendiente de autorizacion — las filas ya escritas

**No ejecutado. Requiere visto bueno explicito de Samuel.**

Toda fila de tarot escrita antes de `5f4ec60` lleva una hora planetaria derivada
de Bogotá, viva donde viva la persona.

| | Que es | Precio |
|---|---|---|
| **A** | Dejarlas | Cero riesgo tecnico. Un dato falso permanece indistinguible de uno verdadero, para siempre, en el Grimorio de la gente |
| **B** | Anular `planetary_hour` en las filas previas al arreglo, con script a mano | Honesto y consistente con la decision editorial. Irreversible, y toca datos de produccion |
| **C** | Aplazar con el motivo escrito | Deuda declarada en vez de silenciosa |

**Recomendacion: B.** Es la misma tesis que ya gano dos veces en este proyecto:
ausencia declarada gana a precision fingida. Pero es borrado irreversible sobre
produccion, asi que el arreglo de codigo va commiteado y solo, y B espera
autorizacion.

Forma que tendria: script explicito en `arcanum-api/scripts/`, que se corre a
mano, con `--dry-run` por defecto, acotado por `created_at < ` la fecha del
despliegue del arreglo, y tocando **solo** `planetary_hour` — nunca `moon_phase`,
que es correcto.
