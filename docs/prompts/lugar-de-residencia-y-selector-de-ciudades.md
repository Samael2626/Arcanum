# Prompt — Dónde vives, y dejar de escribir a mano dónde naciste

## El problema, en una frase

ARCANUM guarda **un solo lugar** por persona —el de nacimiento— y lo usa para
**dos cosas que necesitan lugares distintos**.

```
Carta natal (Ascendente, casas, planetas)  -> lugar de NACIMIENTO   correcto hoy
Hora planetaria y regente del dia          -> donde ESTAS AHORA     incorrecto hoy
Fase lunar                                 -> ninguno, es global    correcto hoy
```

La hora planetaria parte en doce la luz entre **tu** amanecer y **tu** atardecer.
Es una medida del Sol respecto a **tu horizonte, hoy**. El horizonte de tu
nacimiento no interviene.

Medido con el motor real, alguien nacido en Bogotá que vive en Madrid:

```
  UTC   segun NACIMIENTO (Bogota)     segun DONDE VIVE (Madrid)
00:00   regente sun   hora jupiter    regente sun    hora moon     <-- NO
06:00   regente sun   hora jupiter    regente moon   hora moon     <-- NO
12:00   regente moon  hora saturn     regente moon   hora venus    <-- NO
18:00   regente moon  hora mercury    regente moon   hora mars     <-- NO

discrepan en 8 de 8 muestras
```

**Ocho de ocho, y a las 06:00 cambia hasta el regente del día.** No es un error
de precisión: se está midiendo desde el sitio equivocado.

> [!important] Por qué no vale renombrar el campo
> La carta natal **debe** seguir usando el nacimiento. Si se cambia ese campo por
> el de residencia, se rompe el Ascendente de todo el que se haya mudado — que es
> peor que el bug actual. Hacen falta **los dos**, no uno distinto.

Precisión necesaria, medida (no estimada):

```
Madrid centro   -> hora del Sol, empieza 10:01:37
Madrid +10 km   -> hora del Sol, empieza 10:01:34    3 segundos
Madrid +50 km   -> hora del Sol, empieza 10:01:21   16 segundos
```

Una ciudad basta y sobra. **El GPS no entra en este plan**: aportaría segundos
sobre una hora de sesenta minutos, a cambio de un permiso en tiempo de ejecución,
una declaración de privacidad en la tienda y mandar posición en vivo al backend,
que va en contra de la política de datos del proyecto.

---

# FRENTE 1 — El selector de lugar (cliente)

Hoy son **dos campos de texto libre** (`place_step.dart`) que se mandan al
servidor y este resuelve con Nominatim `limit: 1`. Se sustituye por un selector.

## El obstáculo que descarta el autocompletado contra Nominatim

```python
# app/services/geocoding.py:51
def _throttle() -> None:
    """Respeta el límite de 1 req/s de Nominatim a nivel de proceso."""
```

**Un segundo entre peticiones, global para todo el servidor**, no por usuario.
Un buscador que dispara al teclear pondría a todos los usuarios en la misma cola.
Es la condición de uso de un servicio público gratuito. **No se toca ese
throttle**: no es una limitación nuestra que podamos relajar.

## Lo que se construye

**País: desplegable estático.** ~195 entradas, sin red. Elimina "Spain" / "España"
/ "espanya" y da un código ISO exacto en vez de texto por interpretar.

**Ciudad: selector con buscador sobre datos empaquetados.** Se escribe para
**filtrar**, pero solo se puede **elegir** de la lista. Nunca sale texto libre
hacia el geocodificador.

### El dataset

**GeoNames `cities5000`** — ~50.000 localidades de más de 5.000 habitantes.

- **Licencia CC BY 4.0**, verificada en `download.geonames.org/export/dump/readme.txt`.
  No es NC ni ambigua. **Exige atribución**: hay que ponerla en pantalla (Ajustes
  → Acerca de, o el pie del selector). Sin la atribución visible no se cumple.
- Trae **`timezone` IANA en el propio registro**, más `lat`, `lon`, `population`
  y código de país.

> [!tip] La consecuencia buena
> Para una ciudad del paquete **no hace falta ni Nominatim ni timezonefinder**:
> el lugar se resuelve entero **sin red y sin esperar**. Se acabó el throttle
> para el camino común.

**Recórtalo antes de empaquetarlo.** El volcado bruto trae columnas que no se
usan (nombres alternativos, elevación, códigos administrativos). Quédate con lo
mínimo: nombre, país, división administrativa (para desambiguar Córdoba-ES de
Córdoba-AR), lat, lon, tz. Los assets actuales pesan **8,8 MB**; declara cuánto
suma esto y en qué formato, y justifica la elección.

**Verifica el peso y el número real de entradas al bajarlo.** Las cifras de
arriba salen del readme oficial; confírmalas contra el archivo, no las repitas.

### El rescate para lo que no esté

Un enlace discreto —"¿No encuentras tu localidad?"— abre la búsqueda actual
contra Nominatim, con su diálogo de confirmación. **Es el camino que ya existe y
funciona: no se toca, solo deja de ser el principal.**

Sin esto, quien nació en un pueblo de 3.000 habitantes no puede calcular su carta
natal. Un usuario real cerrado fuera por una decisión de producto.

### Cuidado

- **Búsqueda insensible a acentos y a mayúsculas.** "cordoba" tiene que
  encontrar "Córdoba". Es España y Latinoamérica: sin esto el selector es
  inservible. `_norm` de `claude_service.py` hace exactamente esa
  normalización — mira ese criterio antes de escribir otro.
- **Que no bloquee el hilo de UI.** Filtrar 50.000 entradas en cada pulsación
  necesita índice o `Isolate`. Pruébalo en gama baja, no solo en el emulador.
- **El texto libre no puede sobrevivir en el estado.** Si `place_step` sigue
  guardando lo tecleado en vez de lo elegido, no hemos arreglado nada.

## Entrega 1

- Peso real del asset y formato, con la razón.
- La atribución CC BY, en pantalla y visible.
- Búsqueda sin acentos demostrada con "cordoba" → "Córdoba".
- Que el rescate a Nominatim sigue funcionando.
- Medida del tiempo de filtrado con el dataset completo.

---

# FRENTE 2 — El lugar de residencia (servidor)

## La migración

Aprobada expresamente para esto. Cuatro columnas en `users`, **todas nullable y
sin backfill**:

```
current_lat       VARCHAR(20)   NULL
current_lon       VARCHAR(20)   NULL
current_city      VARCHAR(100)  NULL
current_timezone  VARCHAR(50)   NULL
```

Mismos tipos que sus gemelas `birth_*` (las coordenadas se guardan como texto en
este esquema; **respétalo**, no introduzcas `NUMERIC` para dos columnas nuevas).

> [!important] Vacío significa "vivo donde nací"
> Es la decisión de producto que evita romper a nadie y evita que la mayoría
> teclee lo mismo dos veces. Nadie tiene que rellenar nada para seguir igual.

**Encadena desde `007`.** Verificado con Alembic sobre esta rama:

```
cabezas: ['007']   una sola, cadena lineal 001 -> 002 -> ... -> 007
```

```python
revision = "008"
down_revision = "007"
```

> [!warning] Corrección de una versión anterior de este documento
> Aquí decía que `007_add_reading_library.py` "no está en la rama de despliegue".
> **Es falso**: está desde antes del 12 de agosto (entró en `379b546`, presente ya
> en `84ad664`). El dato salió de leer mal una tabla del vault que comparaba dos
> ramas. Se conserva la corrección porque el aviso mandaba a resolver un conflicto
> de cabezas inexistente.

## El criterio único

Ya hay **un solo sitio a cada lado** que decide dónde está una persona, y esto no
puede crear un tercero:

```
servidor  app/services/user_sky.py     coords(user)
cliente   lib/core/astro/user_place.dart   userPlaceOf(user)
```

Los dos pasan a **preferir residencia y caer a nacimiento**:

```
current_lat/lon  ->  si existen, se usan
                 ->  si no, birth_lat/lon
                 ->  si tampoco, None  (jamas una ciudad inventada)
```

**Es un cambio dentro de esas dos funciones, no fuera.** Si te ves tocando
`tarot.py`, `grimoire.py`, `astral.py` o `hoy_screen.dart` para esto, para: esos
sitios ya llaman al criterio y no deben saber que ahora hay dos lugares.

`local_date()` de `horoscope.py` usa `birth_timezone` para la fecha del
horóscopo. **Debe pasar a la de residencia**, y por el mismo motivo: el día de
alguien empieza donde vive, no donde nació.

## Lo que NO cambia

**La carta natal sigue usando `birth_*`, sin excepción.** `_birth_data()` en
`astral.py` no se toca. Si la residencia se cuela ahí, se rompe el Ascendente de
todo el que se haya mudado, que es peor que el bug que venimos a arreglar.

Escribe un test que lo fije: usuario con residencia distinta del nacimiento →
la carta natal sale **idéntica** a la que salía antes.

## Entrega 2

- La migración, y contra qué revisión encadena.
- Los dos criterios actualizados, y la prueba de que no hay un tercero.
- Test: residencia ≠ nacimiento → hora planetaria cambia, **carta natal no**.
- Test: sin residencia → se comporta exactamente como hoy.
- El horóscopo tomando la fecha de la residencia.

---

# Cómo se reparten

Dos agentes, **cero solapamiento**: `arcanum_app/lib` contra
`arcanum-api/app` + `migrations/`.

**Un punto de integración**, y hay que declararlo: el paso de residencia en el
onboarding y en el perfil usa el selector del frente 1 y las columnas del
frente 2. **Ese paso no lo hace ninguno de los dos.** Va en un tercer commit,
cuando los dos hayan aterrizado. Si un agente empieza a construirlo, para.

## Reglas

- **Nunca `ARCANUM_SKIP_HOOKS=1`.** Si el hook bloquea, el bloqueo es el dato.
- Postgres `arcanum-test-db` en el puerto **5434**.
- **No commitear con gates rojos.** El hook corre la suite entera.
- **Push solo a `fix/bogota-release`.** Nunca a `release/p0a-beta`.
- **No desplegar.** `release/p0a-beta` ya tiene trabajo pendiente de deploy;
  esto se suma a la cola, no se adelanta.
- Código en inglés sin acentos; comentarios en español sin acentos; UI en
  español **con** acentos. **Nada de CJK.**

## Aviso

**Esto cambia el onboarding, que es la primera pantalla que ve alguien nuevo**, y
la más cara de romper: quien no lo termina, no existe como usuario. Hoy funciona.
Un selector que se atasca con 50.000 entradas en un teléfono de gama baja es peor
que dos campos de texto feos.

Y sigue en pie: **nada de esto se ha ejecutado nunca en un teléfono real**.
Séptima sesión con el OnePlus pendiente. Compilar y pasar el analyzer no es
funcionar, y un selector es precisamente un componente que se juzga con el dedo.
