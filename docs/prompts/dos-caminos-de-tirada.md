# Prompt — Dos pantallas de tirada, dos tablas, y una que nadie usa

## Objetivo

ARCANUM tiene **dos caminos de tirada de tarot** que escriben en **tablas
distintas**. En dos meses y 26 usuarios, uno acumulo 62 filas y el otro **cero**.
La pantalla que no se usa esta construida y enrutada, pero **ninguna pantalla
enlaza a ella**.

Esto no es un bug que arreglar a ciegas: es una pregunta de producto con
consecuencias tecnicas. El encargo es **entenderlo y proponer**, no reescribir.

## Estado verificado

### Los dos caminos

| Pantalla | Metodo | Endpoint | Escribe en |
|---|---|---|---|
| `oraculo_screen.dart:255` | `tarotDraw` | `POST /oracle/tarot/draw` | `divination_sessions` |
| `tarot_screen.dart:86-87` | `tarotDrawOne` / `tarotSpread` | `/tarot/draw-one`, `/tarot/spread` | `tarot_readings` |

### Los datos de produccion

```
tabla                    filas  ph NOT NULL  moon NOT NULL
tarot_readings               0            0              0
divination_sessions         62            0              0   2026-06-23 .. 2026-08-15
grimoire_entries             0            0              0
usuarios: 26
```

### La pantalla esta desenlazada

`TarotScreen` esta enrutada como subruta del Oraculo:

```
app_router.dart:107   GoRoute(path: 'tarot', builder: (c,s) => const TarotScreen())
```

Pero **nada navega a `/oraculo/tarot`**. Barrido sobre `lib/` completo: ni un
`go()` ni un `push()` hacia esa ruta. `oraculo_screen.dart` solo empuja a
`/paywall`. La pantalla solo es alcanzable por deep link escrito a mano.

### El dato astral nunca se guardo

`routers/oracle.py:68` construye `DivinationSessionCreate` **sin**
`planetary_hour` ni `moon_phase`, pese a que la tabla tiene ambas columnas. Las
62 sesiones reales las tienen a NULL. Ese dato no existe para ninguna tirada que
haya ocurrido de verdad.

### Consecuencia ya confirmada

El fix `5f4ec60` se justifico como "el peor de los tres escapes de Bogotá,
porque no mostraba un dato falso, lo ESCRIBIA". `_sky_snapshot` vive en
`routers/tarot.py` — **el router que nadie recorre**. El bug era real en el
codigo y **jamas escribio una fila**. Por eso el simulacro de anulacion dio cero
en las tres tablas.

El arreglo sigue siendo correcto, pero la urgencia venia de un dano que no
ocurrio.

## Lo que hay que averiguar

1. **żPor que `TarotScreen` esta desenlazada?** Distinguir, con evidencia del
   historial de git, entre:
   - se decidio a proposito y quedo como trabajo futuro,
   - el enlace existio y se perdio en algun cambio,
   - nunca se termino de conectar.

   El tratamiento es distinto en cada caso, y el `git log` de
   `oraculo_screen.dart` y `app_router.dart` deberia poder decirlo.

2. **żCual es el camino canonico?** Los dos existen, consumen la MISMA cuota
   (`UsageService` con la clave `"tarot"` en ambos), y devuelven contratos
   distintos. Dos formas de hacer lo mismo son dos formas de divergir.

3. **żQuien lee estas tablas?** No hay ningun endpoint `GET` de historial ni
   para `tarot_readings` ni para `divination_sessions` (los unicos `GET` de
   `tarot.py` son del catalogo de cartas). Averiguar si el historial de tiradas
   se lee desde algun sitio, o si estas tablas solo se escriben. Si nadie las
   lee, eso cambia por completo el peso de la decision.

4. **żQue pasa el dia que `TarotScreen` se conecte?** Empezaria a escribir en
   una tabla distinta de la que lleva dos meses acumulando el historial real.
   Cualquier vista de historial tendria que leer de dos sitios con formas
   distintas. Evaluar el riesgo concreto, no en abstracto.

5. **żDeberia `/oracle/tarot/draw` guardar el dato astral?** Tiene las columnas y
   nunca las rellena. Con el criterio ya fijado en `user_sky.py`: coordenadas
   confirmadas o `None`. **Es una propuesta a evaluar, no un encargo de
   implementar** — decidirlo aqui repetiria el error de ampliar alcance sin
   consultar.

## Lo que NO se hace en este encargo

- **No conectar la pantalla.** Que este desenlazada puede ser deliberado.
- **No borrar `TarotScreen` ni el router `tarot.py`.** Codigo sin uso no es
  codigo muerto hasta que alguien lo declare.
- **No unificar los dos caminos.** Es la decision que este encargo prepara, no
  la que ejecuta.
- **No migrar datos** entre tablas.
- **No tocar produccion.** Lectura si, escritura no. Si hace falta leer la base
  real, borrar la credencial del disco al terminar.
- Nada de Umbral, nombres, biblioteca, migraciones ni `release/p0a-beta`.

## Trabajo

1. Reconstruir la historia de las dos pantallas con `git log`: cuando aparecio
   cada una, si el enlace existio, y que commit lo dejo como esta.
2. Trazar los dos contratos de extremo a extremo: que manda el cliente, que
   guarda el servidor, que devuelve, y en que se diferencian.
3. Responder las cinco preguntas de arriba con evidencia, no con impresiones.
4. **Proponer** un camino canonico con sus consecuencias, y decir explicitamente
   que se pierde en cada opcion. Incluir la opcion de no hacer nada.
5. Si aparece un bug de verdad por el camino: declararlo, no arreglarlo aqui.

## Entrega final

- Respuesta a las cinco preguntas, cada una con la evidencia que la sostiene.
- La historia del enlace perdido o nunca puesto, con SHAs.
- Tabla comparando los dos contratos.
- Recomendacion sobre el camino canonico, con lo que cuesta cada opcion y la de
  no hacer nada incluida.
- Riesgo concreto de que `TarotScreen` se conecte tal como esta hoy.
- Lo que quede sin poder comprobarse, marcado como **no comprobado**. Es
  preferible a rellenarlo con una suposicion: esta sesion ya perdio tiempo por
  dar por cierta una etiqueta que nadie habia verificado.
