# Prompt — Dos frentes en paralelo: el Bogotá del cliente y las migraciones mudas

## Cómo se ejecuta

Dos frentes **independientes**, con **cero solapamiento de archivos**. Lanza un
subagente por frente y trabájalos en paralelo:

| | Frente A | Frente B |
|---|---|---|
| Qué | Bogotá vive en el cliente Flutter | `get_alembic_config()` roto en producción |
| Archivos | `arcanum_app/lib/**` | `arcanum-api/app/db/migrate.py` + tests |
| Gate | `flutter analyze` + `flutter test` | `pytest` |

**Ninguno de los dos toca lo del otro.** Si un frente necesita un archivo del
otro, para y dilo: significa que el reparto estaba mal medido.

**Un commit por frente.** No mezclar. Si uno queda bloqueado, el otro se
commitea igual.

Rama de trabajo: `fix/bogota-release` (donde está `f661f9a`).

---

# FRENTE A — Bogotá sigue vivo, y ahora en el teléfono

## Lo verificado

El corte del servidor (`fb1812c`) dejó de **escribir** horas planetarias
falsas. Pero la coordenada nunca salió del cliente:

```dart
// arcanum_app/lib/core/api/arcanum_api.dart:44-45
Future<Map<String, dynamic>> today({
  double lat = 4.71,
  double lon = -74.07,
}) async {
```

Barrido completo de `lib/`: **es el único sitio vivo**. Los cuatro llamadores
usan `today()` **sin argumentos**:

```
lib/features/hoy/hoy_screen.dart:30    _future = _api.today()      <- carga inicial
lib/features/hoy/hoy_screen.dart:53    onRefresh                   <- tirar para refrescar
lib/features/hoy/hoy_screen.dart:103   onPressed                   <- reintentar tras error
lib/features/grimorio/grimorio_editor.dart:55   final today = await api.today()
```

Consecuencia, en dos partes y las dos reales:

1. **La pantalla Hoy le muestra el regente del día y la hora planetaria de
   Bogotá a todo el mundo.** Es la pantalla que más se abre.
2. **El editor del Grimorio pide ese mismo dato y lo manda en el POST.** El
   servidor ya lo descarta y sella el suyo (`grimoire.py`), así que **no se
   persiste** — pero lo que la persona ve mientras escribe sigue siendo falso.

## El dato bueno ya está en el cliente

`AuthState.user` guarda la respuesta entera de `GET /users/me`
(`auth_controller.dart:64`), que incluye `birth_lat`, `birth_lon` y
`birth_timezone`. Además se persiste con `saveProfile`, así que sobrevive sin
red. **No hay que pedir nada nuevo al servidor para saber dónde está la
persona.**

## La decisión de diseño, que es tuya

`/astral/today` es `noAuth: true` y exige `lat`/`lon` como query obligatorios
(`astral.py:241-245`). Hay dos caminos y **no son equivalentes**:

- **A1 — el cliente manda sus coordenadas reales.** Cambio pequeño, no toca el
  contrato. Pero el servidor sigue confiando en un dato del cliente, que es la
  forma exacta del bug que se acaba de cerrar en el Grimorio.
- **A2 — el servidor sella también aquí.** Variante autenticada que saca las
  coordenadas del usuario, como ya hacen `tarot.py` y el horóscopo vía
  `user_sky.coords`. Más superficie, pero deja UN solo criterio de "dónde está
  una persona" en todo el sistema.

**Mide las dos y recomienda una, con el porqué.** No la elijas por ser la más
corta.

## Qué hacer sí o sí, elijas la que elijas

**Borrar el default.** Mientras `lat = 4.71` siga siendo el valor por omisión,
cualquier llamador nuevo que se olvide de pasar coordenadas hereda Bogotá en
silencio. Un parámetro obligatorio convierte ese olvido en un error de
compilación.

**Y decidir qué pasa sin coordenadas.** Es la pregunta de verdad. Un usuario sin
lugar confirmado no tiene hora planetaria, y la regla del proyecto ya está
fijada: *ausencia declarada, jamás una ciudad por defecto*. Hoy tendrá que saber
mostrar "no disponible" para la hora y el regente, sin romper la luna, que es
global y sí se puede calcular siempre.

## Cuidado con esto

- **`grimorio_editor.dart` está pendiente de otro arreglo** (el `catch` único
  que culpa a la conexión, diagnosticado en `f8099be`). **No lo hagas aquí.**
  Toca solo la llamada a `today()`. Si te descubres reescribiendo el `catch`,
  para.
- Los tests de `hoy_screen_test.dart` y `widget_test.dart` tienen `4.71/-74.07`
  en sus fakes. Eso es legítimo: son coordenadas de prueba. Pero
  **`hoy_screen_test.dart` es también el guardián de rendimiento de Hoy** — si
  falla por `ArcanumSurface`, no lo relajes: usa `TodayCard`.
- `test/features/onboarding/onboarding_test.dart` usa Bogotá como lugar de
  prueba. **No se toca**: ahí es un dato de fixture, no un default.

## Entrega A

- Qué camino elegiste (A1/A2) y por qué el otro no.
- El default borrado, y qué pasa ahora si nadie pasa coordenadas.
- Qué ve un usuario **sin** lugar confirmado, en Hoy y en el editor.
- Un test que falle **antes** del arreglo. Sin eso no hay prueba de nada.
- `grep -rn "4\.71\|74\.07" lib/` → vacío.

---

# FRENTE B — Las migraciones que fallan diciendo que todo va bien

## Lo verificado, reproducido hoy

```
>>> from app.db.migrate import get_alembic_config
>>> get_alembic_config()
ImportError: cannot import name 'SQLALCHEMY_DATABASE_URL' from 'app.db.session'
```

`migrate.py:22-29` importa un nombre que `session.py` **ya no exporta**.
Comprobado: `grep SQLALCHEMY_DATABASE_URL app/db/session.py` no da nada.

Y no falla ruidoso, que es lo grave. Los dos únicos llamadores lo envuelven:

```
migrate.py:48   config = get_alembic_config()   dentro de try/except Exception
migrate.py:78   config = get_alembic_config()   dentro de try/except Exception
```

Ese `except Exception` devuelve `{"status": "error", ...}` con **HTTP 200**. Un
bug de programa disfrazado de resultado esperable.

## Por dónde sangra

```
app/main.py:9,25          run_migrations(engine)      <- arranque de la app, y DESCARTA lo que devuelve
app/routers/admin.py:48   run_migrations(engine)
app/routers/admin.py:106  run_migrations(custom_engine)
app/routers/admin.py       check_migration_status
```

El arranque de la app llama y **tira el resultado al suelo**. Si alguna vez
hiciera falta migrar al arrancar, no migraría y nadie se enteraría.

## El trabajo

1. **Arreglar el import.** Mira de dónde saca `session.py` la URL ahora y usa
   esa fuente. No inventes una constante nueva para que el import cuadre: eso
   arregla el síntoma y deja dos fuentes de verdad para la misma URL.
2. **Estrechar el `except`.** Un fallo de conexión o una migración que choca son
   esperables y merecen `{"status": "error"}`. Un `ImportError` es un bug de
   programa y **debe reventar**. Hoy los dos salen iguales, y por eso este error
   lleva vivo lo que lleva.
3. **Decidir qué hace `main.py` con lo que devuelve.** Ahora mismo lo descarta.
   Si el arranque no va a mirar el resultado, que al menos lo registre.
4. **Un test que pesque.** Debe fallar contra el `migrate.py` actual. Verifica
   que **pesca**, no solo que pasa: `git stash` el arreglo, corre el test, mira
   el rojo, y restaura.

## Lo que NO se hace en el frente B

- **Ninguna migración nueva.** Ni tocar las siete existentes.
- **No ejecutar migraciones contra ninguna base real.** Esto es arreglar el
  código que las lanza, no lanzarlas.
- **No tocar `/admin/migrate-direct`.** Que acepte cualquier connection string
  con solo el token de admin es un problema real y aparte, y es decisión de
  Samuel. Anótalo si lo ves, no lo arregles.
- Nada de Railway, `release/p0a-beta` ni producción.

## Entrega B

- La salida del `ImportError` **antes**, y la del arreglo funcionando después.
- Qué excepciones quedan atrapadas y cuáles pasan, con el criterio escrito.
- La prueba de que el test nuevo falla contra el código viejo.

---

# Reglas comunes a los dos frentes

- **Nunca `ARCANUM_SKIP_HOOKS=1`.** Si el hook bloquea, el bloqueo es el dato:
  léelo. En la última sesión bloqueó tres veces y las tres tenía razón.
- Postgres `arcanum-test-db` en el puerto **5434** (el 5433 lo ocupa
  `botlaw-pg`).
- **No commitear con gates rojos.** Un commit que deja el árbol en rojo no es un
  commit, y el hook corre la suite **entera**, no solo lo que está en stage.
- **Push solo a `fix/bogota-release`.** Nunca a `release/p0a-beta`, que es la
  que despliega Railway.
- Código en inglés sin acentos; comentarios en español sin acentos; textos de
  UI en español **con** acentos.
- **Nada de caracteres CJK**, en ningún sitio.

## El aviso que importa

**No confundir "no puedo comprobarlo" con "funciona".** Nada de esto se ha
ejecutado nunca en un teléfono real: el OnePlus lleva seis sesiones pendiente y
`flutter devices` solo da Windows, Chrome y Edge. Compilar y pasar el analyzer
no es funcionar.

El frente A cambia lo que la gente **ve** en la pantalla que más se abre. Si al
terminar la respuesta honesta es "esto necesita el aparato para darse por
cerrado", dilo y páralo ahí. La lista de no comprobados es parte de la entrega,
no un residuo.
