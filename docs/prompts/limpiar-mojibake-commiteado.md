# Prompt — Limpiar el mojibake commiteado y arreglar el guardian que lo vigila

## Objetivo

Dejar en cero la corrupcion de codificacion que ya esta en el repo, y arreglar
los dos fallos de `scripts/check_encoding.py` que hacen que la herramienta no
pueda hacer su trabajo.

Rama: `feat/nombre-y-umbral-foundation`, worktree `D:/tmp/nombre-y-umbral-foundation`.
Commit unico y aparte. No mezclar con nada del Tarot ni del Umbral.

## Estado verificado (barrido completo sobre `git ls-files`, hoy)

Son **tres** archivos, 17 lineas. El checkpoint anterior decia dos: `materia.py`
no estaba, y aparece solo al barrer todo lo versionado en vez de mirar donde ya
se sabia que habia algo.

| Archivo | Lineas | Que son |
|---|---|---|
| `arcanum-api/app/routers/admin.py` | 3,4,5,56,73,77,84,88,115 | docstring del modulo, comentarios, y un `detail=` de HTTPException |
| `arcanum-api/app/core/config.py` | 21,38,57,58,94 | comentarios, y el mensaje de configuracion insegura |
| `arcanum-api/app/routers/materia.py` | 1,3,61 | docstring, y un `detail=` de HTTPException |

**No todo es comentario.** `config.py:94` y `materia.py:61` son cadenas que
salen de verdad — un mensaje de arranque y un 409 de la API. Eso ya se lee
corrupto en algun log.

## El diagnostico

Doble codificacion estandar: alguien leyo UTF-8 como cp1252 y lo reescribio.
Una sola vuelta de `cp1252 -> utf-8` lo deshace. Bytes reales del disco:

```
c3 83 c2 b3                ->  'A~^3'  ->  'o' con tilde
c3 a2 e2 82 ac e2 80 9d    ->  'a,-"'  ->  raya larga
c3 83 c5 a1                ->  'A~s'   ->  'U' con tilde
c3 a2 e2 80 a0 e2 80 99    ->  'a+-'   ->  flecha a la derecha
```

## Los dos bugs del guardian, que importan mas que las 17 lineas

1. **`check_encoding.py` se muere imprimiendo su propio informe.** La consola de
   Windows es cp1252 y el texto corregido contiene una flecha U+2192, que no
   existe en cp1252. `print()` levanta `UnicodeEncodeError` y aborta con
   traceback a media lista. Quien lo dispare ve un crash en vez de los
   hallazgos, y **los que faltaban quedan invisibles**. Reproducible hoy:

   ```
   git ls-files -z '*.py' | xargs -0 python scripts/check_encoding.py
   -> UnicodeEncodeError: 'charmap' codec can't encode character '\u2192'
   ```

   Una herramienta que detecta corrupcion de codificacion y que ella misma no
   sabe escribir su salida.

2. **No salta los `.glb`.** Hay tres modelos 3D versionados
   (`arcanum_app/assets/models/luna.glb` y compania). `_SKIP_SUFFIXES` no los
   lista, se leen como texto y salen como "NO es UTF-8 valido". Si un `.glb`
   entra en stage alguna vez, el hook bloquea el commit por un falso positivo
   sobre un archivo que es binario a proposito.

## Aviso de infraestructura

- **CRLF.** `core.autocrlf=true` y no hay `.gitattributes`. Los tres archivos
  estan con CRLF en disco. Reescribirlos sin conservar el final de linea
  convierte el diff en el archivo entero y entierra el cambio real. Verificar
  con `git diff --stat` que las lineas tocadas son ~17, no ~400.
- **El hook necesita Postgres.** `arcanum-test-db` en el puerto **5434** (5433
  lo ocupa `botlaw-pg`). Levantarlo antes de commitear.
- **Nunca `ARCANUM_SKIP_HOOKS=1`.** Si el hook bloquea, el bloqueo es el dato.
- **No tocar produccion, Railway, Firebase, RevenueCat, AdMob, migraciones ni
  `release/p0a-beta`.** Push SOLO a `feat/nombre-y-umbral-foundation`.

## Lo que NO se toca

- **Ninguna logica.** Esto cambia bytes de texto, no comportamiento. Si un test
  cambia de resultado, algo se rompio: parar e investigar, no ajustar el test.
- **Los acentos se conservan.** Estos son textos que lee un humano (comentarios,
  docstrings, mensajes de UI y de API) y van CON acentos, bien codificados. La
  regla de "sin acentos" es para identificadores, commits y nombres de archivo.
- **Nada de reescribir archivos enteros a mano.** Leer, corregir, guardar como
  UTF-8, conservando el final de linea.

## Trabajo

1. **Arreglar `scripts/check_encoding.py` primero.** Es la herramienta con la
   que se va a verificar el resto; arreglarla despues seria verificar con un
   instrumento roto.
   - Que la salida no dependa de la consola: escribir en UTF-8 con reemplazo, o
     por `sys.stdout.buffer`, de forma que **nunca** aborte a mitad del informe.
   - Anadir los sufijos binarios que faltan (`.glb` como minimo; revisar si hay
     otros binarios versionados que hoy se leen como texto).
   - Test que fije las dos cosas: que un texto con flecha se reporta entero sin
     levantar, y que un binario no genera hallazgo.

2. **Corregir los tres archivos**, una sola vuelta de decodificacion,
   conservando CRLF.

3. **Barrido de verificacion sobre TODO lo versionado**, no solo sobre los tres:

   ```
   git ls-files -z | xargs -0 python scripts/check_encoding.py
   ```

   Tiene que salir limpio y con codigo 0. Es el mismo error que dejo escapar el
   tercer Bogota: una red del tamano exacto del problema ya conocido.

4. **Verificar que el guardian pesca.** Ejecutar el `check_encoding.py` nuevo
   contra las versiones ANTERIORES de los tres archivos (sacarlas con
   `git show HEAD:<ruta>`) y comprobar que las senala. Que pase en verde no
   demuestra nada si no se demuestra que tambien sabe fallar.

5. **Suite completa verde** (`pytest`) y `flutter analyze` si se toco Dart —
   no deberia tocarse.

6. **Commit y push** a la rama feature. Mensaje en espanol sin acentos. Que
   diga que eran tres archivos y no dos, y que el guardian tenia dos fallos.

## Entrega final

- SHA y rama.
- Tabla de archivos corregidos con numero de lineas por archivo.
- La demostracion del punto 4: salida del guardian contra las versiones viejas.
- Salida del barrido completo del punto 3, limpia.
- `git diff --stat` del commit, probando que no se reescribieron archivos
  enteros por CRLF.
- Numeros de la suite antes y despues.
- Cualquier hallazgo lateral, sin arreglarlo dentro de este commit.
