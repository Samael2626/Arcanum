# Checkpoint — Los dos caminos de tarot, y por que uno tiene cero filas

- **Fecha:** 2026-08-17
- **Rama de referencia:** `fix/bogota-release` (arbol que coincide con las
  lineas citadas: `oraculo_screen.dart:255`, `app_router.dart:107`)
- **Naturaleza:** investigacion. Ningun cambio de comportamiento.

## 1. Por que `TarotScreen` esta desenlazada: **nunca se conecto**

No es un enlace perdido. La cadena `oraculo/tarot` **no aparece ni una sola vez
en toda la historia** de `arcanum_app/lib`:

```
git log --all --oneline -S "oraculo/tarot" -- arcanum_app/lib
(vacio)
```

Y `TarotScreen` solo cambia de conteo en un commit — el que la crea:

```
git log --all --oneline -S "TarotScreen" -- arcanum_app/lib
e9c9674 Remove railway.toml (conflicting with railway.json)
```

`e9c9674` (2026-06-21) crea **en el mismo commit** la pantalla, su ruta y todo
el backend de `tarot_readings` (`routers/tarot.py`, migracion 002). El mensaje
del commit no tiene nada que ver con lo que hace.

Lo que decide la lectura es lo que vino DESPUES:

| Fecha | SHA | Que hizo |
|---|---|---|
| 2026-06-21 | `e9c9674` | crea `TarotScreen` + ruta `/oraculo/tarot` + `routers/tarot.py`. Sin enlace desde ningun sitio |
| 2026-07-23 | `7a2da65` | esqueleto definitivo de navegacion: **5 pestanas — Hoy, Cielos, Grimorio, Saber, Oraculo**. Tarot no esta |
| 2026-07-23 | `251bf3c` | "modo Aprender — visor de tarot carta por carta", construido **dentro de `features/oraculo/`** |
| 2026-08-04 | `22776a4` | monetizacion: toca `tarot_screen.dart` para adaptarla a cuotas |
| 2026-08-11 | `5b4ef3a` | creditos p0a: la vuelve a tocar |

O sea: cuando la app recibio su navegacion definitiva, `TarotScreen` no entro; y
toda la inversion posterior en tarot se hizo en el Oraculo. La pantalla se ha
seguido **manteniendo** (compila, pasa el analyzer, tiene un test de widget en
`tarot_idempotency_retry_test.dart`) sin estar **conectada**. Por eso nadie
noto que estaba muerta: los gates la ven, los usuarios no.

**Veredicto:** el tercer caso — nunca se termino de conectar. Y con dos hitos
posteriores que sugieren que la decision de facto ya se tomo a favor del
Oraculo, aunque no se escribiera en ningun sitio.

## 2. Los dos contratos

| | Camino Oraculo | Camino TarotScreen |
|---|---|---|
| Pantalla | `oraculo_screen.dart` (pestana real) | `tarot_screen.dart` (inalcanzable) |
| Endpoint | `POST /oracle/tarot/draw` | `POST /tarot/draw-one`, `POST /tarot/spread` |
| Tabla | `divination_sessions` | `tarot_readings` |
| Filas en produccion | **62** (23 jun – 15 ago) | **0** |
| Tiradas | `three_card`, `celtic_cross` | `one_card`, `three_card`, `celtic_cross` |
| Pregunta | `encrypted_question` + `question_iv` — pero el cliente **no manda ninguna** en la tirada | `question` en **texto plano**; el propio cliente lo documenta |
| Dato astral | columnas presentes, **nunca rellenadas** (`oracle.py:68`) | `moon_phase` + `planetary_hour` sellados por `_sky_snapshot` |
| Devuelve | la sesion completa, con `id` | `TarotReadingResponse` con `resolved` |
| Encadena con IA | **si**: el `id` va a `/oracle/ia` como `divination_session_id` | **no** hay forma de anclar la lectura de IA a un `tarot_reading` |
| Cuota | `UsageService` accion `"tarot"` | `UsageService` accion `"tarot"` — **la misma** |

Limites: `TAROT_FREE_DAILY = 1`, `TAROT_PREMIUM_DAILY = 50`.

## 3. Quien lee estas tablas

- **`divination_sessions`: SI se lee**, pero solo desde el servidor.
  `/oracle/ia` hace `div_repo.get_owned(...)` y `build_tarot_context(session)`
  para anclar la lectura de IA a la tirada. No hay `GET` de historial: la app no
  puede listar tiradas pasadas.
- **`tarot_readings`: NO la lee nadie.** `TarotReadingRepository.list_by_user`
  existe, y tambien esta declarado en el puerto
  (`application/ports/repositories.py:64`), pero **ningun endpoint lo llama**.
  Hay hasta un indice preparado para esa consulta
  (`ix_tarot_readings_user_created`). Camino de lectura escrito y nunca
  enchufado, igual que la pantalla.
- `grimoire_entries` si tiene `GET /grimoire` y lo consume la pestana Grimorio.

Esto **baja el peso de la decision**: hoy no existe ninguna vista de historial,
asi que el problema de "leer de dos sitios con formas distintas" es futuro, no
presente.

## 4. Riesgo concreto el dia que se conecte, tal cual esta hoy

1. **La cuota es la misma y vale 1/dia en gratis.** Un usuario libre que tire en
   el Oraculo se queda sin tirada en Tarot, y al reves. La segunda pantalla
   fallaria con un error de saldo sin explicar por que — dos puertas, una sola
   llave, y ninguna lo dice.
2. **El historial se parte en dos tablas** con formas distintas
   (`cards_drawn` es un dict `{"cards": [...]}` en una y una lista en la otra) y
   columnas de tiempo distintas (`session_date` vs `created_at`).
3. **La pregunta viaja en claro** por el camino nuevo, mientras el viejo tiene
   el diseno de cifrado en el dispositivo. Conectar la pantalla degrada la
   privacidad del producto sin que nadie lo decida.
4. **La lectura de IA no se puede anclar** a una tirada de `tarot_readings`:
   `/oracle/ia` solo acepta `divination_session_id`. La pantalla conectada
   ofreceria tirar pero no interpretar.

## 5. Propuesta de camino canonico

**Recomendacion: el Oraculo (`/oracle/tarot/draw` + `divination_sessions`).**

Razones, todas con evidencia arriba: es donde esta el uso real (62 vs 0), es lo
unico que encadena con la IA, es lo que recibio la inversion posterior
(`251bf3c`), es lo que entro en la navegacion definitiva (`7a2da65`), y es el
que tiene el diseno de pregunta cifrada.

**Que se pierde:** la tirada de **una carta** (el Oraculo la rechaza
explicitamente: `spread_type not in ("three_card","celtic_cross")` -> 400) y el
**sello astral**, que hoy solo escribe el camino muerto.

| Opcion | Coste | Que se pierde |
|---|---|---|
| **A. Canonico = Oraculo** (recomendada) | bajo; el trabajo real es decidir que hacer con la pantalla y el router | `one_card`, y el sello astral salvo que se traslade |
| **B. Canonico = TarotScreen** | alto: rehacer el flujo del Oraculo, inventar un ancla de IA para `tarot_readings`, y las 62 filas reales quedan huerfanas | el encadenado con IA tal como existe hoy |
| **C. Los dos, con reparto explicito** | medio y permanente: dos contratos que sincronizar, la cuota compartida hay que separarla, y cualquier historial lee de dos sitios | nada de golpe; se paga en divergencia continua |
| **D. No hacer nada** | cero hoy — la pantalla es inalcanzable salvo deep link a mano | nada hoy; se paga el dia que alguien enlace la ruta sin conocer este analisis |

**D no es absurda**: el riesgo esta contenido porque nadie puede llegar. Lo que
si conviene, cueste lo que cueste la decision, es **dejar escrito** que la ruta
esta desenlazada a proposito — un `GoRoute` sin enlace parece un olvido y algun
dia alguien lo "arregla".

## Sobre la pregunta 5 — el dato astral en `/oracle/tarot/draw`

`DivinationSessionCreate` acepta `moon_phase` y `planetary_hour`;
`routers/oracle.py:68` no los pasa. Las 62 sesiones reales los tienen a NULL: en
dos meses de uso, **ninguna tirada de verdad guardo dato astral**.

Trasladarlo seria unas pocas lineas con el criterio ya fijado (coordenadas
confirmadas o `None`), y haria que el camino canonico no fuera peor que el que
se abandona. **Es propuesta, no encargo.** No se ha tocado.

## Correcciones a lo ya documentado

1. **`divination_sessions` NO la escribe el cliente.** Los checkpoints del 16 de
   agosto decian "cliente, desde el default de `today()`". Es falso: la crea el
   **servidor** en `oracle.py:65`, y sin dato astral. El unico sitio donde el
   cliente manda `planetary_hour` es `grimorio_editor.dart:70`, hacia
   `grimoire_entries`.
2. **La hipotesis del `Idempotency-Key` era falsa.** Se sugirio que
   `tarot_readings` podia estar vacia porque la app recibiera 422 por no mandar
   la cabecera. No: el cliente **si** la manda (`_idempotentOptions`). La tabla
   esta vacia por una razon mas simple — **nadie puede llegar a la pantalla**.
3. **La urgencia del fix `5f4ec60` estaba mal fundada.** Se justifico como "el
   peor de los tres escapes porque lo ESCRIBIA". Escribia en el router que nadie
   recorre. El arreglo sigue siendo correcto; el dano no ocurrio.

## No comprobado

- **Por que `grimoire_entries` tiene 0 filas.** El Grimorio si es una pestana
  real, con `GET /grimoire` y un editor alcanzable por `Navigator.push`. Que no
  haya ni una entrada en dos meses y con 26 usuarios no tiene explicacion
  tecnica encontrada aqui. Puede ser simplemente que nadie escriba.
- **Si `TarotScreen` funciona hoy.** No se ha ejecutado ni renderizado; lleva
  meses sin recorrerse. Compila y tiene un test de widget, que no es lo mismo.
- **Cuantos de los 26 usuarios son reales** y no cuentas de prueba. Cambia la
  lectura de "62 sesiones" pero no la del cero.
