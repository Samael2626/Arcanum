# Prompt — Tres tablas vacias, 26 usuarios y dos meses: żque esta pasando de verdad?

## Objetivo

Averiguar **cuanta de la actividad de produccion es real** y **si el Grimorio
guarda de verdad**. Sin esas dos respuestas, todas las decisiones de producto
que quedan encima de la mesa se estan tomando leyendo el poso de una taza casi
vacia.

Este encargo es de **medir y diagnosticar**. No arregla nada.

## Estado verificado

```
tabla                    filas  ph NOT NULL  moon NOT NULL
tarot_readings               0            0              0
divination_sessions         62            0              0   2026-06-23 .. 2026-08-15
grimoire_entries             0            0              0
usuarios: 26
```

`tarot_readings` en cero **ya esta explicado**: nadie puede llegar a
`TarotScreen`, porque ninguna pantalla enlaza `/oraculo/tarot`. Ver
`docs/prompts/dos-caminos-de-tirada.md`.

`grimoire_entries` en cero **no esta explicado**, y ese es el hueco.

## Por que el Grimorio no tiene explicacion facil

Al contrario que Tarot, **el camino esta enchufado de punta a punta**:

```
grimorio_screen.dart:40   bookPageRoute(const GrimorioEditor())     <- alcanzable
grimorio_editor.dart:69   api.grimoireCreate({...})
arcanum_api.dart:158      POST /grimoire
routers/grimoire.py       create_entry  ->  grimoire_entries
arcanum_api.dart:148      GET /grimoire                             <- y se lee
```

El Grimorio es pestana real de la navegacion, el editor se abre desde su propia
pantalla, y el `GET` de lista existe. **No es codigo muerto.** Aun asi: cero
entradas en dos meses con 26 usuarios.

Quedan dos hipotesis que **no se pueden separar leyendo el codigo**:

- **A. El camino falla en ejecucion.** Algo revienta en el dispositivo.
- **B. Nadie escribe en su Grimorio.** Hallazgo de producto, no de ingenieria.

## Los dos sospechosos concretos, si es A

### 1. El `catch` que lo dice todo igual

`grimorio_editor.dart:80-88`:

```dart
} catch (e) {
  setState(() {
    _error = 'No se pudo sellar la entrada. Revisa tu conexion.';
  });
}
```

**Un solo `catch` para todo el bloque**, y siempre culpa a la conexion. Ese
bloque incluye el cifrado, la llamada a `/astral/today` y el `POST`. Si lo que
falla es el cifrado o un 422 del servidor, el usuario lee "revisa tu conexion",
lo intenta otra vez, vuelve a fallar y **abandona**. Nadie reporta un bug de red.

Es la cuarta variante del patron de esta sesion: **un fallo real disfrazado de
otra cosa**.

### 2. El cifrado depende del almacen seguro del dispositivo

`core/crypto/grimoire_crypto.dart:25-32`: la clave se lee de
`FlutterSecureStorage` y, si no existe, se genera y se escribe. **Si esa
escritura o esa lectura falla en el dispositivo real, no hay entrada posible** —
y el `catch` de arriba lo convertiria en "revisa tu conexion".

Encaja con algo ya sabido: la **verificacion en OnePlus fisico lleva cinco
sesiones pendiente**. Nada de esto se ha ejecutado nunca en un telefono de
verdad.

## Trabajo

### 1. Cuantos de los 26 usuarios son reales

Es la pregunta que reordena todo lo demas. Con la base de produccion, **solo
lectura**:

- Distribucion de altas por fecha.
- Cuantos tienen `birth_lat`/`birth_lon` confirmados, carta natal calculada,
  o cualquier senal de uso.
- Cuantos huelen a cuenta de prueba (correos repetidos, dominios de prueba,
  altas en rafaga el mismo minuto).
- **Cuantos usuarios distintos** aparecen en las 62 sesiones.

Si resulta que hay tres personas reales, "cero entradas de Grimorio" deja de ser
una senal de nada, y este encargo termina ahi con esa conclusion.

### 2. Si el Grimorio guarda, probarlo de extremo a extremo

Contra un backend **local**, no produccion:

- `POST /grimoire` con un cuerpo valido: żguarda?
- El mismo cuerpo que manda el cliente de verdad (`grimorio_editor.dart:69`):
  `entry_type`, `title`, `encrypted_content`, `content_iv`, `moon_phase`,
  `planetary_hour`, `day_planet`, `entry_date`. żPasa la validacion del schema?
- Con `moon_phase`/`planetary_hour` en `null`, que es lo que ocurre si
  `/astral/today` falla: żsigue guardando?

Si algo devuelve 422, **ese es el bug** y explica los dos meses en cero.

### 3. El desglose del `catch`

Separar el bloque para saber **cual de los tres pasos** falla: cifrado,
`/astral/today`, o el `POST`. **Diagnosticar, no arreglar** — pero dejar dicho
exactamente que mensaje deberia ver el usuario en cada caso.

### 4. Solo si 1, 2 y 3 no lo explican

Entonces la respuesta es **B**, y hay que decirlo con esas palabras: el camino
funciona y la gente no lo usa. Es una conclusion legitima y valiosa, no un
fracaso del encargo.

## Lo que NO se hace

- **No arreglar el `catch`,** aunque este claro que hay que hacerlo. Commit
  aparte, y probablemente con la verificacion en dispositivo fisico al lado.
- **No escribir en produccion.** Lectura y nada mas. Borrar del disco cualquier
  credencial usada, al terminar.
- **No conectar `TarotScreen`,** ni tocar los dos caminos de tirada.
- **No tocar el cifrado.** Es el dato mas sensible de la app y su formato tiene
  compatibilidad hacia atras (`v2:` y el camino CBC heredado).
- Nada de Umbral, nombres, biblioteca, migraciones ni `release/p0a-beta`.
- Nunca `ARCANUM_SKIP_HOOKS=1`.

## Aviso

**No confundir "no puedo comprobarlo" con "funciona".** La lista de no
comprobados de esta investigacion es parte del entregable, no un residuo. Esta
sesion ya perdio tiempo dos veces por dar por cierta una etiqueta que nadie
habia verificado — una rama de despliegue y un P0 que no existia.

Y hay un limite duro: **nada de esto se ha ejecutado nunca en un telefono
real**. Compilar y pasar el analyzer no es funcionar. Si la respuesta honesta
acaba siendo "hace falta el OnePlus", decirlo y parar.

## Entrega final

- **Cuantos usuarios reales hay**, con el criterio usado para decidirlo escrito.
- Cuantos usuarios distintos hay detras de las 62 sesiones.
- Veredicto sobre el Grimorio: **A (falla)** o **B (nadie lo usa)**, con la
  evidencia que lo sostiene.
- Si es A: cual de los tres pasos falla, y el mensaje que deberia ver el usuario.
- Las salidas crudas de todo lo que se ejecute.
- Lo no comprobado, marcado como tal, y por que no se pudo comprobar.
