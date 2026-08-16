# Prompt — Hora planetaria del Tarot: el tercer Bogota (ARCANUM)

> Fase correctiva posterior a Lectura del Umbral (`f79181d`, rama `feat/nombre-y-umbral-foundation`).
> Copiar de aqui hacia abajo.

---

Skills: `arcanum-dev`, `senior-programmer`, `checkpoint`, `obsidian-vault`. Modo cavernicola.

## Objetivo

Matar el **tercer** sitio donde vive la coordenada de Bogota. Los dos anteriores
(`/astral/today` y `oracle_context`) se arreglaron en `8247325`. Este se escapo,
y es el peor de los tres: **no muestra el dato falso, lo escribe en la base.**

Alcance estrecho a proposito: solo el camino que sella la hora planetaria de una
tirada. No rediseñar el Tarot, no tocar creditos, no tocar el Umbral.

## Estado verificado (comprobado ejecutando, no de memoria)

- `arcanum-api/app/routers/tarot.py:119`

  ```python
  hour = ph.get_planetary_hour(now, 4.71, -74.07).planet
  ```

- Lo llama `_sky_snapshot`, y a `_sky_snapshot` lo llaman `draw_spread`
  (`tarot.py:64`) y `draw_one` (`tarot.py:95`).
- El valor **se persiste**: `divination_session.planetary_hour` y
  `grimoire_entry.planetary_hour`. Queda escrito y luego el Grimorio lo sella.
- Un barrido completo de `arcanum-api/app` y `arcanum_app/lib` confirma que
  **esta es la unica coordenada viva que queda**. Todo lo demas que menciona
  Bogota son comentarios que documentan bugs ya muertos.
- El cliente ya tolera el nulo: `grimorio_screen.dart:380` tiene rama para
  `planetaryHour == null || isEmpty`, y `grimorio_detail.dart:229` lo lee como
  `String?`. El esquema tambien: `schemas/tarot.py:67` y `:77` son `Optional`.
- Suite actual en verde y medida: backend `273 passed, 3 skipped`; Flutter
  `288 passed`; `flutter analyze lib` sin issues.

### Por que se escapo

Los dos barridos que existen son de alcance local y ninguno podia verlo:

- El test Flutter recorre `lib/` — no ve Python.
- `tests_unit/test_oracle_context_sin_fallback.py:49` hace
  `inspect.getsource(oracle_context)` — **solo ese modulo**.

No fue descuido de quien reviso: fue una red tejida a la medida del pez que ya
se habia visto.

## Aviso de infraestructura — leer antes de tocar backend

1. **Railway despliega desde `feat/onboarding-5-pasos`.** Cada push a esa rama
   va a produccion sin CI. **No pushear ahi.** Solo a
   `feat/nombre-y-umbral-foundation`.
2. El **hook de pre-commit exige Postgres** cuando cambia el backend. Contenedor
   `arcanum-test-db`, **puerto 5434** (el 5433 lo ocupa `botlaw-pg`).
   **No usar `ARCANUM_SKIP_HOOKS=1`.**
3. **Mina pisada, no la pises:** `app/core/config.py` y `app/routers/admin.py`
   tienen mojibake **ya commiteado** (5 lineas y varias, respectivamente).
   `scripts/check_encoding.py` los rechaza. Si los pones en stage por cualquier
   motivo, el hook bloquea el commit y parecera culpa de tu cambio. No los
   toques en esta fase; su limpieza es un commit aparte.

## Lo que NO se toca

- **`moon_phase` se queda como esta.** La fase lunar es global: no depende del
  lugar del observador. Solo la hora planetaria lo hace, porque sale del orto y
  el ocaso locales. Ampliar el arreglo a la Luna seria romper algo que funciona.
- **Nada de migraciones Alembic.** Sigue vigente la prohibicion. Si se decide
  tocar filas historicas, es un script explicito que se corre a mano, no una
  revision de esquema.
- El instante (`datetime.now(timezone.utc)`) es correcto: una hora planetaria se
  ancla a un instante absoluto. El error esta en el lugar, no en el reloj.

## Trabajo

### 1. Test que falla primero

Antes del arreglo, un test que demuestre el fallo actual: un usuario **sin**
coordenadas confirmadas produce hoy una hora planetaria no nula, y esa hora es
la de Bogota. Debe estar rojo antes y verde despues.

### 2. Arreglar el camino de escritura

`_sky_snapshot` pasa a recibir el usuario, no solo el instante. Misma decision
que ya tomo `oracle_context._coords` — copiar el criterio, no reinventarlo:

- Con `birth_lat`/`birth_lon` confirmados: se calcula con **esas** coordenadas.
- Sin ellas: `planetary_hour = None`. La tirada se guarda **sin anotacion astral
  en vez de con una falsa**, exactamente como ya hace el Grimorio.

Cuidado con el `except (AttributeError, ValueError)` que ya esta ahi: unas
coordenadas `None` levantarian `TypeError` y se escaparian del catch. La
ausencia de lugar tiene que ser una **decision explicita antes de llamar al
motor**, no una excepcion atrapada por casualidad. Fallar ruidoso, nunca
silencioso.

### 3. Ensanchar la red para que no haya un cuarto

El barrido deja de mirar un modulo y pasa a mirar **todo `arcanum-api/app`**:
ninguna coordenada literal de Bogota en el arbol de codigo del backend, con la
lista de agujas que ya usa `test_oracle_context_sin_fallback.py:16`.

Que el test explique en su docstring por que existe. Un barrido sin motivo
escrito es el primero que alguien relaja cuando estorba.

### 4. Decidir que pasa con lo ya escrito — **no ejecutar sin visto bueno**

Toda fila de tarot escrita antes de este arreglo lleva una hora planetaria
derivada de Bogota, **independientemente de donde viva la persona**. No es
imprecision: a un mismo instante UTC, alguien en Madrid puede estar en otra hora
planetaria y hasta bajo otro regente del dia.

Tres caminos, con su precio:

- **A — dejarlas.** Cero riesgo tecnico. Precio: un dato falso permanece
  indistinguible de uno verdadero, para siempre, en el Grimorio de la gente.
- **B — anular `planetary_hour` en las filas previas al arreglo** (script a
  mano, no migracion). Honesto y consistente con la decision editorial ya
  tomada. Precio: irreversible, y toca datos de produccion.
- **C — aplazar** con el motivo escrito en el checkpoint.

**Recomendacion: B.** Es la misma tesis que ya gano dos veces en este proyecto:
ausencia declarada gana a precision fingida. Pero es borrado irreversible sobre
produccion, asi que **el arreglo de codigo (1-3) va primero y se commitea solo**,
y B no se ejecuta hasta que Samuel lo autorice de forma explicita.

### 5. Tests obligatorios

- Sin coordenadas: `planetary_hour` es `None` y **Bogota no aparece por ningun
  lado** en la respuesta ni en la fila guardada.
- Con coordenadas: se usan **esas**, verificado contra el motor, no contra el
  texto.
- Barrido de fuente sobre todo `arcanum-api/app`.
- `moon_phase` sigue llegando con y sin coordenadas: la Luna no se rompio.
- Idempotencia intacta: la replay por `Idempotency-Key` sigue devolviendo lo
  mismo.

### 6. Gates

`pytest -q` (con Postgres en 5434) · `flutter analyze lib` · `flutter test` ·
`git diff --check` · CJK y codificacion limpios.

**No commit con gates rojos.** Stage selectivo — **no arrastrar `config.py` ni
`admin.py`**. Commit en espanol sin acentos, push **solo** a
`feat/nombre-y-umbral-foundation`. Checkpoint doble en `docs/checkpoints` y
`D:\Brain\10-Proyectos\ARCANUM`. Actualizar `MOC-ARCANUM`.

## Entrega final compacta

Veredicto; el arreglo y por que el `except` no bastaba; como quedo el barrido y
que cubre ahora; que se decidio sobre las filas historicas y si se ejecuto;
pruebas con numeros reales antes y despues; SHA y rama.
