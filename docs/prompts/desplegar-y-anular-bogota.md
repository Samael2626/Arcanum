# Prompt — Desplegar el corte de Bogotá y anular las filas ya escritas

## Objetivo

Producción lleva desde el 12 de agosto sellando una hora planetaria derivada de
Bogotá a gente que nunca declaro estar ahi. El arreglo ya esta escrito y probado
sobre la rama que despliega. Falta desplegarlo y limpiar lo que quedo escrito.

Este encargo termina con un borrado irreversible sobre datos reales. Nada de lo
que hay aqui se ejecuta en piloto automatico.

## Estado verificado

**Railway** (panel, servicio `Arcanum-Code`, Settings → Source):

```
Branch connected to production   release/p0a-beta
                                 Auto deploy is disabled
```

**El despliegue es MANUAL.** Un push a `release/p0a-beta` no despliega nada. Es
la propiedad mas util de todo este encargo: el instante del despliegue se elige
y se anota, en vez de estimarse a posteriori.

**Lo desplegado:** `origin/release/p0a-beta` = `84ad664`, del 12 de agosto.

> [!] `release/p0a-beta` LOCAL esta desactualizada (`c45b5a6`) y no es lo que
> despliega. `84ad664` la contiene y le anade 6 commits. **Trabajar siempre
> contra `origin/release/p0a-beta`.** Confundirlas ya costo un worktree en esta
> sesion.

**El corte:** `fae72e4` en `fix/bogota-release`, cherry-pick limpio de `fb1812c`
sobre `84ad664`. 9 archivos, 496 lineas. Pusheado, **sin desplegar**.

```
suite sobre la rama de despliegue CON el corte    307 passed, 3 skipped
suite SIN el corte (mismos tests)                 5 failed, 297 passed
Bogota en app/ despues del corte                  (vacio)
```

## Trabajo

### 1. Llevar el corte a `release/p0a-beta`

`fae72e4` sale de `84ad664`, asi que es fast-forward. Pushear a
`release/p0a-beta`. **Esto no despliega nada** (auto deploy off): deja el codigo
listo y nada mas.

Antes de pushear, correr la suite completa una vez mas contra esa rama y dejar
el numero escrito. La captura de arriba se hizo en `fix/bogota-release`.

### 2. Desplegar a mano, y ANOTAR EL INSTANTE

Disparar el deploy desde Railway. En cuanto termine:

- Anotar el instante **con zona**, en ISO. No la fecha del commit, no la del
  push: el instante en que el despliegue quedo sirviendo.
- Confirmar que el servicio levanto y responde.
- **Verificar en caliente que el arreglo esta vivo**: una tirada de un usuario
  sin coordenadas confirmadas tiene que guardar `planetary_hour` nulo. Sin esta
  comprobacion no se pasa al punto 3 — anular filas mientras el bug sigue
  escribiendo es perseguir un blanco movil, que es justo lo que este encargo
  viene a impedir.

> [!] `RUN_STARTUP_MIGRATIONS` no esta definida en Railway, asi que vale `False`
> por defecto y las migraciones las aplica el `Procfile` con
> `alembic upgrade head` antes de `uvicorn`. Este commit no toca migraciones.

### 3. El simulacro

```
python scripts/null_bogota_planetary_hour.py --before <instante del punto 2>
```

Sin `--apply`. Leer el conteo y **contrastarlo con lo esperado** antes de seguir:
un numero absurdamente alto o un cero son motivo de parar, no de continuar.

`--before` no tiene default a proposito y rechaza fechas sin zona, en el futuro
o ausentes. Heredar una fecha inventada ahi repetiria exactamente el bug que el
script viene a limpiar.

Las tres tablas y su columna de tiempo — `divination_sessions` no tiene
`created_at`, usa `session_date`:

| Tabla | Columna | Quien la escribia |
|---|---|---|
| `tarot_readings` | `created_at` | `_sky_snapshot`, servidor |
| `grimoire_entries` | `created_at` | el cliente, desde `today()` |
| `divination_sessions` | `session_date` | historico; hoy ya no se contamina |

### 4. Solo entonces, `--apply`

Antes de correrlo:

- **`arcanum-api/scripts/out/` esta sin trackear y sin ignorar.** Ahi cae el
  respaldo de un borrado irreversible. Al `.gitignore` primero, commit aparte.
- Comprobar que el directorio existe y es escribible. Un respaldo que no se
  escribe convierte esto en un borrado sin vuelta atras.

Despues: verificar el respaldo en disco, y que los conteos posteriores cuadran
con el simulacro.

## Lo que NO se toca

- **`moon_phase`, en ninguna tabla.** La fase lunar es global: la misma para
  todo el mundo en el mismo instante, y los valores guardados son correctos.
  Solo la hora planetaria depende del observador. Hay tests que fijan que
  ninguna sentencia del script la menciona.
- **Ninguna fila se borra.** Solo se anula una columna.
- **Ninguna migracion.** La prohibicion sigue vigente.
- **La Lectura del Umbral** (`8247325`), el catalogo de nombres y la biblioteca.
  No entran en este despliegue.
- **`get_alembic_config()`**, aunque su `ImportError` esta vivo en produccion
  (`release/p0a-beta` trae el parametro de `c44ae86` pero conserva la
  importacion rota). El arreglo existe en `082d6c8`, en otra rama. **Commit y
  decision aparte**, para que el despliegue de Bogotá no arrastre un cambio en
  el camino de migraciones.
- Firebase, RevenueCat, AdMob.
- Nunca `ARCANUM_SKIP_HOOKS=1`.

## Cuando parar y preguntar

- Si el conteo del simulacro no cuadra con lo esperado.
- Si el despliegue no levanta, o la verificacion en caliente del punto 2 falla.
- Si `scripts/out/` no es escribible.
- Si aparece cualquier tabla con `planetary_hour` que no este en la lista.

Parar con la mitad hecho es correcto aqui. Terminar a ciegas no.

## Entrega final

- SHA desplegado y **el instante del despliegue, con zona**.
- La verificacion en caliente del punto 2: la tirada sin coordenadas y su
  `planetary_hour` nulo.
- Conteo del simulacro, por tabla.
- Conteo del `--apply`, por tabla, y que cuadre con el simulacro.
- Ruta y contenido del respaldo.
- Conteos posteriores: `planetary_hour` y `moon_phase` en las tres tablas,
  probando que la Luna quedo intacta y que no se borro ninguna fila.
- Numeros de la suite antes y despues.
- Cualquier hallazgo lateral, declarado y sin arreglar aqui.
