# Checkpoint — El mojibake commiteado y el guardian roto

- **Fecha:** 2026-08-16
- **Rama:** `feat/nombre-y-umbral-foundation`
- **SHA:** `7b9edb2 fix(codificacion): limpiar el mojibake commiteado y arreglar el guardian`
- **Worktree:** `D:/tmp/nombre-y-umbral-foundation`
- **Alcance:** bytes de texto, ninguna logica. Commit unico y aparte.

## Eran tres archivos, no dos

El checkpoint anterior decia dos. `materia.py` no estaba, y aparece solo al
barrer **todo** `git ls-files` en vez de mirar donde ya se sabia que habia algo.
Es el mismo error que dejo escapar el tercer Bogotá: una red del tamano exacto
del problema conocido.

| Archivo | Lineas | Que eran |
|---|---|---|
| `arcanum-api/app/routers/admin.py` | 3,4,5,56,73,77,84,88,115 | docstring del modulo, comentarios y un `detail=` de HTTPException |
| `arcanum-api/app/core/config.py` | 21,38,57,58,94 | comentarios y el mensaje de configuracion insegura |
| `arcanum-api/app/routers/materia.py` | 1,3,61 | docstring y un `detail=` de HTTPException |

**No todo era comentario.** `config.py:94` y `materia.py:61` son cadenas que
salen de verdad — un mensaje de arranque y un 409 de la API. Ya se leian
corruptas en los logs.

Diagnostico: doble codificacion estandar, alguien leyo UTF-8 como cp1252 y lo
reescribio. Una sola vuelta de `cp1252 -> utf-8` lo deshace, linea a linea y
conservando el fin de linea. 17 lineas tocadas, 17 en el diff:

```
 arcanum-api/app/core/config.py     | 10 +++++-----
 arcanum-api/app/routers/admin.py   | 18 +++++++++---------
 arcanum-api/app/routers/materia.py |  6 +++---
 3 files changed, 17 insertions(+), 17 deletions(-)
```

CRLF intacto: 99 -> 99, 132 -> 132, 92 -> 92. Si no se hubiera conservado, el
diff seria el archivo entero y enterraria el cambio real.

## Los dos fallos del guardian, que importaban mas que las 17 lineas

### 1. Se moria imprimiendo su propio informe

La consola de Windows es cp1252 y el texto **corregido** contiene la flecha
U+2192 de `admin.py:88`, que ahi no existe. `print` levantaba
`UnicodeEncodeError` y abortaba a media lista:

```
UnicodeEncodeError: 'charmap' codec can't encode character '\u2192'
```

Quien lo disparaba veia un traceback en vez de los hallazgos, y **los que
faltaban quedaban invisibles**. Una herramienta que detecta corrupcion de
codificacion y que ella misma no sabe escribir su salida.

Se sanea **antes** de escribir, no se atrapa el error despues: asi el informe
sale entero. Y con `backslashreplace`, no con `replace` — lo que la consola no
puede escribir sale como `\u2192` y no como `?`. Una herramienta que habla de
caracteres no puede borrar justo el caracter del que habla.

### 2. No saltaba los `.glb`

Tres modelos 3D versionados se leian como texto y salian como "NO es UTF-8
valido". Un falso positivo que bloquea el commit por un archivo que es binario a
proposito.

Se anaden los sufijos que faltaban y, sobre todo, **un descarte por byte nulo**:
la lista de sufijos siempre va por detras del repo, y un byte nulo no existe en
texto. Eso cierra la clase de falso positivo, no el caso.

## Verificacion

Barrido sobre **todo lo versionado**, no solo sobre los tres:

```
git ls-files -z | xargs -0 python scripts/check_encoding.py
EXIT=0
```

Y la prueba de que el guardian **pesca**, no solo de que pasa — ejecutado contra
las versiones anteriores sacadas con `git show HEAD:<ruta>`:

```
17 hallazgos · 54 lineas de informe · cero tracebacks · EXIT=1

  D:/tmp/claude/viejas/admin.py:88: mojibake
      encontrado: # Detecta poolclass (pgbouncer transaction mode <mojibake>)
      deberia ser: # Detecta poolclass (pgbouncer transaction mode \u2192 NullPool)
```

Esa es exactamente la linea que antes mataba el informe: ahora sale escapada y
el informe continua hasta el final.

Siete tests en `tests_unit/test_check_encoding.py` fijan las dos cosas contra un
flujo cp1252 **de verdad** (`TextIOWrapper` sobre `BytesIO`), no contra un doble
que acepte cualquier cosa: si alguien quita el saneado, el test levanta el mismo
`UnicodeEncodeError` que se vino a matar. El mojibake de prueba se **genera**
(`texto.encode("utf-8").decode("cp1252")`) en vez de escribirse literal — un
literal corrupto en ese archivo lo volveria un hallazgo del propio guardian y
bloquearia el commit del test que lo arregla.

Tres de los siete estaban **en rojo antes** del arreglo, uno por archivo sucio.

**Backend 379 verdes** (372 antes, +7), 3 skipped. Dart sin tocar. `git diff
--check` limpio. CJK limpio.

## Hallazgos laterales, no arreglados aqui

- `_SKIP_SUFFIXES` incluye `.lock`. `pubspec.lock` es texto: si alguna vez se
  corrompe, el guardian no lo vera. No se toca en este commit porque cambiar
  ese salto puede sacar hallazgos nuevos y este commit no cambia veredictos,
  solo bytes.
- El informe se degrada al redirigirlo a archivo: Python usa la codificacion
  local (cp1252) y los acentos salen escapados. Es comportamiento estandar de
  Python, no del script. Con `PYTHONIOENCODING=utf-8` sale integro.

## La mina, desactivada

Deja de ser cierto que `config.py` y `admin.py` bloquean el commit si entran en
stage. Ya no hay mojibake commiteado en ningun archivo versionado.
