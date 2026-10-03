# Plan: llevar la mesa de tarot a la app

**Especificación:** `docs/ARCANUM-Spec-Mesa-Tarot.md`.
**Prototipo de referencia:** `prototipos/tarot-mesa-3d-v2.html`.
**Orden de trabajo** (el que pide `AGENTS.md`): backend primero, después la interfaz; tests en cada fase.

## Puntos de partida (comprobados en el código, 29-sep)

- **Tiradas:** `app/domain/spreads.py` tiene 3 (`one_card`, `three_card`, `celtic_cross`) en un registro en código. Faltan Cruz simple, Relación, Herradura y Rueda del año.
- **Sorteo:** `TarotService.draw_spread` sortea con `random.sample` en el momento, sin sesión, sin montones y sin elegir posiciones. `random` no sirve para un sorteo que queramos poder defender: hay que usar `secrets.SystemRandom`.
- **Cupo:** `/tarot/spread` y `/tarot/draw-one` reservan el cupo diario (`TAROT_FREE_DAILY` / `TAROT_PREMIUM_DAILY`) con `Idempotency-Key`. Las lecturas se guardan en `tarot_readings` con fase lunar y hora planetaria.
- **Migraciones:** la última era la 014. La nueva fue la 015; el 01-oct pasó a **016** al traer `main`, que ya había desplegado su 015 de fragmentos (ver D6).
- **App:** las rutas están en `lib/core/router/app_router.dart` y las cartas en `lib/features/oraculo/widgets/tarot_card.dart` (`TarotCardView`, volteos por palo). El módulo nuevo irá en `lib/features/tarot/`.

## Reglas que no se saltan

- **Rama propia:** `feat/mesa-tarot`, sacada de `main`, en un **`git worktree` aparte** (`../Arcanum-mesa`). Cambiar de rama en la carpeta compartida rompería a las otras sesiones. **Un push a `main` despliega solo a producción:** nada entra en `main` sin las dos puertas en verde.
- **Puerta del backend:** la suite con las **dos** bases levantadas (`arcanum-test-db` en 5434 y `arcanum-svc-test` en 55434). Un verde con ~172 tests saltados no vale. Además, `scripts/verify_migrations.py` en verde.
- **Puerta de la app:** `flutter analyze` y `flutter test` en verde.
- **Solo añadir en la API:** las rutas actuales (`/tarot/spread`, `/tarot/draw-one`, `/oracle/tarot/draw`) no cambian. La app publicada en la prueba cerrada tiene que seguir funcionando.
- **Nunca `ARCANUM_SKIP_HOOKS=1`.**
- **Commits** con `git commit -- <rutas>`: el índice de git lo comparten las sesiones paralelas.

---

## Fase 0: preparación

- [x] Medir el prototipo en un móvil real con `#fps`. **Referencia (móvil de Samuel, 29-sep): 36–42 fps en reposo, ~18 con movimiento o animaciones fuertes.** Es el techo del 3D del navegador; Flutter tiene que llegar a 60.
- [x] Decisiones D1–D4 cerradas con Samuel el 29-sep; D5 se comprueba en la fase 3.
- [x] `git worktree add ../Arcanum-mesa -b feat/mesa-tarot origin/main` y traer la especificación, el plan y el prototipo.

## Fase 1: dominio del backend (sin HTTP)

- [x] **Catálogo de tiradas:** pasar a 7, con las mismas posiciones, nombres y significados que el prototipo, incluidas las coordenadas del paño. Una sola fuente para la app y el Oráculo, sin romper los 3 slugs actuales.
- [x] **Catálogo de mazos:** Rider–Waite–Smith (78) y Arcanos Mayores (22), como datos: cartas incluidas, si admite invertidas y arte.
- [x] **`TarotSession` como entidad de dominio pura:** abrir, barajar, cortar, unir, sacar por posición, devolver y recoger. Montones con posiciones estables (`null` = sacada) e invertidas decididas al barajar.
- [x] Azar con `secrets.SystemRandom`, inyectable para poder testear con semilla.
- [x] **Tests unitarios puros**, sin base de datos:
  - [x] Barajar mantiene el conjunto de cartas.
  - [x] Cortar y unir conservan el orden esperado, incluido el corte clásico.
  - [x] Sacar por posición es estable mientras hay un abanico abierto.
  - [x] Devolver y recoger no duplican ni pierden cartas: siempre suman 78 o 22.
  - [x] Con el mazo de Mayores nunca sale un Menor.

**Fase 1 hecha (29-sep, `f084f95`):** 243 tests puros; con el hook, 1176 + 98 de `tests_pg` en verde.

## Fase 2: persistencia y API

- [x] **Migración 015 (hoy 016, ver D6):** tabla `tarot_sessions` (usuario, mazo, estado JSONB, estado de la sesión, creada/actualizada, caducidad). Como mucho una sesión activa por usuario.
- [x] Repositorio y servicio de aplicación, con la misma estructura en capas que ya usa el módulo.
- [x] **Rutas nuevas:**
  - [x] `GET /tarot/decks` y `GET /tarot/spreads`: catálogos.
  - [x] `POST /tarot/sessions`: abrir con un mazo. `GET /tarot/sessions/current`: estado sin revelar el orden.
  - [x] `POST /tarot/sessions/{id}/shuffle | cut | merge | take | return | gather`: libres, sin cupo.
  - [x] `POST /tarot/sessions/{id}/interpret`: gasta el cupo (D1) y devuelve la interpretación de Tradición.
  - [x] `POST /tarot/sessions/{id}/close`: cierra el círculo y guarda la lectura.
  - [x] **El cliente nunca recibe el orden de los montones:** solo cuántas cartas quedan y las que ya sacó.
- [x] **Cupo (D1):** la sesión y sus operaciones son libres; el cupo se reserva en `POST /tarot/sessions/{id}/interpret`, con `Idempotency-Key` como hoy. Esa misma ruta devuelve la interpretación de Tradición y deja la lectura lista para guardarse.
- [x] **Cerrar el círculo:** guarda la lectura en `tarot_readings` con fase, hora planetaria, pregunta, tirada, cartas y aclaratorias.
- [x] **Historial:** listar y leer lecturas guardadas para contemplarlas y continuarlas.
- [x] Tests con base de datos (`tests_pg`) de rutas, cupo, idempotencia y permisos (un usuario no toca la sesión de otro).
- [x] **Puerta:** suite completa con las dos bases + `verify_migrations`.

**Hecha el 29-sep** (`migrations/versions/015_add_tarot_sessions.py`, `app/application/services/tarot_table_service.py`, `app/routers/tarot_table.py`, `tests_pg/test_tarot_table_pg.py`). Lo que conviene saber para la fase 3:

- **Estados de la mesa:** `open` → `interpreted` → `closed`, o `abandoned` si se abre otra o pasan **12 h** sin tocarla. Abandonada o caducada responde **404**; cerrada, **409**. El índice único parcial `uq_tarot_sessions_one_active` impide dos activas aunque falle el código.
- **Bloqueo:** cada operación bloquea la fila de la mesa (`FOR UPDATE`). Probado: ocho peticiones a la vez por la misma carta, una sale 200 y siete 400.
- **Estilos de barajar:** `cascada`, `por_encima`, `sobre_el_pano` (los tres del radial del prototipo).
- **Interpretar** recibe `{spread, question, placements: [{slug, slot}] + aclaratorias [{slug, clarifies}]}`. Valida **antes** de cobrar (una tirada mal formada no gasta cupo), pone las invertidas que decidió el servidor y devuelve la lectura de Tradición: nombre y significado de cada hueco y el significado de la carta según su sentido. Máximo 3 aclaratorias por hueco. Se puede interpretar otra vez tras sacar aclaratorias, y cada vez gasta cupo.
- **Cerrar** exige una lectura interpretada, guarda en `tarot_readings` (con `slot` y `clarifies` en `cards_drawn`, y la foto de la mesa en `table_snapshot`, hasta 64 KB) y es idempotente: repetirlo devuelve la misma lectura.
- **Historial:** `GET /tarot/readings` y `GET /tarot/readings/{id}`. Solo las del usuario; las de otro dan 404.
- **La pregunta** se guarda como hoy en `/tarot/spread`, en claro. D5 sigue abierta.
- **Puerta:** `verify_migrations` hasta 015 y vuelta; 1251 pasan y 2 saltados; `tests_pg` 119 (21 nuevos).

## Fase 3: base de la app

- [x] `lib/features/tarot/` con la estructura de la especificación (§10).
- [x] Cliente de la API nueva en `arcanum_api.dart` y modelos.
- [x] `TableState`: el equivalente de `serialize`, con providers de Riverpod (`@riverpod` + codegen).
- [x] Autoguardado local **cifrado**, igual que el Grimorio.
- [x] Tests unitarios de `TableState`: serializar y restaurar, y deshacer con copias reales, no referencias.

**Hecha el 29-sep** (`lib/features/tarot/`: `domain/table_models.dart`, `domain/table_state.dart`, `data/table_store.dart`, `application/table_controller.dart`; tests en `test/features/tarot/`). Lo que conviene saber para la fase 4:

- **Sin generación de código de Riverpod.** `AGENTS.md` pide `@riverpod` + codegen, pero el repo no lo usa en ningún sitio (ni `riverpod_annotation` ni `build_runner` en `pubspec.yaml`): todo es `Notifier`/`AsyncNotifier` a mano. Se siguió lo que hay para no meter una cadena de build nueva por un módulo.
- **`TableState` es inmutable:** cada cambio devuelve una mesa nueva y las listas no se pueden modificar. Así, la foto de deshacer no puede compartir arrays con la mesa viva, que fue el fallo del prototipo. Hay un test que lo vigila.
- **Guarda la vista pública, no el mazo:** `ServerView` (cuántas quedan y en qué posiciones) más la disposición local. `withServer()` reconcilia: montones nuevos tras un corte, montones que desaparecen al unir y cartas que vuelven al mazo.
- **Operaciones en fila:** dos toques seguidos se aplican en orden. Los errores de red no se tragan; llegan a la pantalla.
- **Autoguardado cifrado** con el mismo AES-256-GCM y la misma clave del dispositivo que el Grimorio, uno por usuario. `flush()` guarda en el acto (para cuando la app pasa a segundo plano). Si el servidor ya no tiene esa mesa, la foto se olvida. Borrar la cuenta borra las mesas guardadas.
- **Deshacer es local:** vuelve a la disposición de antes del gesto, 5 s, una vez. **El mazo del servidor no retrocede**, así que deshacer un corte o una unión no los deshace en el servidor. Para la fase 5 hay que decidir si el servidor guarda un paso de deshacer o si esos gestos no se ofrecen para deshacer.
- **Puerta:** `flutter analyze` limpio; `flutter test` 675 pasan (22 nuevos, tres pasadas seguidas sin fallos intermitentes).

## Fase 4: la mesa

- [x] **Prueba de rendimiento primero:** 78 cartas en `Transform` sobre un `Stack` en el móvil real con Impeller. Si no llega a 60 fps, se decide ya entre `Stack` de widgets y pintar las cartas del abanico con `CustomPainter`.
  - [x] APK de prueba lista (29-sep): `prototipos/mesa_rendimiento/`, proyecto aparte con id propio. Mide widgets frente a pintor en cinco escenas.
  - [x] **Medida el 30-sep en el móvil de Samuel** (GN2200, Android 12, pantalla a 60 Hz, Impeller), leída por `adb logcat`:

    | Escena | Widgets: fps · montaje p90 · dibujo p90 | Pintor: fps · montaje p90 · dibujo p90 |
    |---|---|---|
    | Abanico | 59,9 · 6,6 ms · 12,6 ms | 60,6 · 10,2 ms · 12,1 ms |
    | Volteos | 59,6 · 4,5 ms · 11,4 ms | 60,7 · 10,5 ms · 12,0 ms |
    | Arrastre | 59,9 · 6,9 ms · 12,7 ms | 60,2 · 10,3 ms · 12,0 ms |
    | Cámara | 59,7 · 4,5 ms · 11,6 ms | 59,6 · 10,4 ms · 12,0 ms |
    | Todo a la vez | 58,4 · 10,6 ms · 13,2 ms | 59,6 · 10,6 ms · 12,1 ms |

    **Las dos técnicas llegan a 60 fps** (el prototipo DOM daba ~18 con movimiento). El margen está en el dibujo: 12–13 ms de 16,7.
  - [x] **Decisión: híbrido.** Las 78 cartas del **abanico** (solo dorso, todas iguales) se pintan con `CustomPainter`: es lo que más pesa y el pintor lo aguanta estable. Las cartas **en juego** (una docena como mucho) van como **widgets** con `Transform`: reutilizan `TarotCardView` con su arte y sus volteos por palo, tienen `Semantics` para lectores de pantalla y su toque es por pieza. Así no se pierde nada de lo visual por rendimiento.
  - **Ojo:** las cartas de la prueba eran más ligeras que `TarotCardView`. Si la mesa real baja de 60, lo primero es envolver cada carta quieta en `RepaintBoundary`.
- [x] **Lógica sin dibujo, adelantada mientras llega la medición** (`lib/features/tarot/table/`, 30-sep):
  - `table_camera.dart`: encuadre del prototipo, matriz con perspectiva y toque a mesa por homografía inversa; órbita invertida, inercia, pellizco y recentrado. Suavizado independiente de los Hz.
  - `gesture_grammar.dart`: máquina de estados pura (tocar, mantener 430 ms, arrastrar, cortar, abanico, esquina, órbita, pellizco, bordado 1,3 s).
  - `radial_logic.dart`: disposición, elección por ángulo con zona muerta de 46 y los menús en orden fijo.
  - `table_geometry.dart` y `card_physics.dart`: huecos, imán, aclaratorias, abanico, estante, volteo por esquina y peso.
  - `table_director.dart`: traduce gestos en acciones contra `TableOps` (que implementa el controlador) y expone `pieces()` para cualquiera de las dos técnicas de dibujo. Errores a la pantalla; un 402 abre la tienda.
  - **Fallo cazado por los tests:** `setEntry(3, 2)` sobre una matriz ya trasladada dejaba el punto de fuga en la esquina y torcía la mesa. Corregido también en la APK de prueba.
  - **Girar** una carta viaja como `turned` al interpretar y el servidor invierte su sentido (salvo en mazos sin invertidas).
  - **A vigilar en el móvil:** en la tirada de tres los imanes de los huecos casi se tocan (158 entre huecos, 94 de imán): el sitio para soltar una aclaratoria es estrecho.
- [x] **Dibujo de la mesa, técnica híbrida (30-sep)** (`table/table_painters.dart`, `table_pieces.dart`, `table_view.dart`, `table_icons.dart`, `tarot_screen.dart`):
  - Paño, marco, huecos con su número o nombre, estante y «Interpretar» bordado, en un `CustomPainter`. El dorso se graba una vez en imagen y se estampa (abanico y montones).
  - Cartas en juego como widgets: viajan animadas a su sitio, se voltean con los tiempos del palo del oráculo (`TarotFlipTiming`), siguen la esquina con su bisagra, giran 180° con un pequeño salto y se anuncian al lector de pantalla con nombre, sentido y hueco.
  - Radial dibujado con los 21 iconos de trazo del prototipo, no con iniciales; el centro cierra o deshace.
  - Solo se piden frames cuando algo se mueve o espera al reloj.
  - `TarotCardFaceArt`, `TarotCardBack`, `paintTarotBack` y `TarotFlipTiming` se exponen desde `tarot_card.dart` sin tocar lo que usa el oráculo.
  - La carta pasa a 110 × 176 (1:1,6, la del naipe de la app) para que la lámina no se deforme.
  - Ruta `/tarot` y entrada «Mesa de tarot · en pruebas» en el cajón, **solo fuera de release**.
- [x] **Fallo encontrado de paso:** `seed_tarot.py` y `seed_materia.py` importaban `SessionLocal`, que vale None hasta crear la fábrica: la siembra del arranque fallaba siempre y en silencio. En producción no se notaba porque las cartas ya estaban. Corregido con test.
- **Backend local para probar en el móvil:** base `arcanum_dev_mesa` en `arcanum-test-db` (5434), migrada y sembrada a mano, sin `GROQ_API_KEY`. **Nunca con el `.env` de `arcanum-api`, que apunta a la base de producción:** el arranque aplicaría la 016 allí. La app de depuración va con `--dart-define=API_BASE_URL=http://127.0.0.1:8000` y `adb reverse tcp:8000 tcp:8000`.
- [x] **Decisiones de Samuel del 30-sep, hechas:**
  - **Cerrar el círculo sin interpretar:** se guarda gratis lo que hay en la mesa: tirada completa, a medias o libre (`spread_type = free`, cartas sueltas no apartadas). El sello se abre al cerrar. Interpretado, se guarda lo interpretado.
  - **Deshacer también en el servidor:** `tarot_sessions.previous_state` y `previous_until` (30 s; la app ofrece 5). Cada operación lleva `checkpoint`: en un gesto de varias, solo la primera marca punto, así se deshace entero. Lo interpretado o cerrado ya no se deshace. Si el servidor avanza fuera del gesto, ese deshacer se retira para no revertir otra cosa. Se deshacen: cortar (menú o borde), unir (soltar encima, por orden o automático), recoger todo, devolver una carta y sacar del abanico arrastrando.
  - **Continuar una lectura:** `POST /tarot/sessions` con `from_reading` abre una mesa con esas cartas ya fuera del mazo y su sentido (un giro ya viene aplicado); la app recoloca la foto guardada. Solo se ofrece en lecturas hechas en la mesa (las de `/tarot/spread` no guardaron la foto). Si la mesa actual tiene cartas, se pide confirmación.
  - Como la migración de la mesa no ha salido de esta rama, se amplió en vez de crear otra.
- [x] **`TableCamera`:** `Matrix4` con perspectiva 1/1000, inclinación y giro. Inversa para convertir toques en unidades de mesa. Encuadre a 30° e inercia. *(Repasado el 01-oct: `table_camera.dart`, inversa por homografía.)*
- [x] **`DeckPiece`:** caja con grosor según el número de cartas. **`CardPiece`:** envuelve `TarotCardView` y añade la bisagra de la esquina y el muelle de inclinación. *(01-oct: se llaman `PilePiece`/`PilePainter`, hasta 13 capas, y `TableCardPiece`.)*
- [x] **Huecos de las 7 tiradas**, con imán, intercambio y aclaratorias.
- [x] **Gestos de la tabla de la especificación (§3):** tocar, mantener 430 ms, arrastrar, esquina, doble toque, pellizcar. Zona de toque de 48 dp. *(01-oct: el toque de cada pieza se agranda 24 unidades de mesa por lado.)*
- [x] **`RadialMenu`:** círculos sueltos de 52 dp, elección por ángulo deslizando y soltando, orden fijo.
- [x] **Paneles compactos:** Leer, pregunta y lecturas guardadas, anclados a lo que se tocó (D7). *(02-oct: `table/table_panel.dart`. Encima de la pieza, debajo si arriba no cabe, dentro de la pantalla con 8 de margen, como mucho 360 de ancho y 60 % de alto. Tocar fuera o «atrás» lo cierra. Anclas: la carta con su giro (`screenRectOfCard`), el sello (`sealScreenRect`) y, para lo elegido en el radial del paño, donde se abrió (`menuAt`). La interpretación sigue en hoja hasta la «Lectura revelada».)*
- [x] **Widget tests:** tocar, mantener abre el radial, arrastrar encaja en el hueco, esquina voltea pasados 70°. *(01-oct: los dos últimos, con dedo real, en `table_view_test.dart` «gestos con el dedo»; comprobado que fallan si el umbral baja de 70.)*

- [x] **Movimiento (30-sep, `table/table_motion.dart`):** las piezas viajan en vez de aparecer.
  - Cartas que nacen volando desde el montón o el abanico (al repartir, escalonadas cada 110 ms) y fantasmas que vuelan al montón al devolver o recoger.
  - Montones que se mueven: el corte sale del original, el mazo abierto sale del estante, y al unir el de encima vuela sobre el otro, desde donde se soltó.
  - Abanico que se despliega en 780 ms y se pliega en 460 ms.
  - Barajado en escena con los tres estilos del prototipo: es teatro, el orden lo fija el servidor.
  - Radial que se abre con los círculos saliendo del centro.
  - Las animaciones arrancan después del fotograma: desde `build` avisarían a sus oyentes en plena construcción.

## Fase 5: el ritual

- [x] **Sellar la pregunta** y romper el sello al interpretar (30-sep): sello de cera en (88, 712) que entra con un golpe; sellado no enseña el texto al tocarlo; al interpretar da un respingo y lo cruza una grieta. Pregunta de hasta 300 caracteres, como el prototipo. **Falta** el vuelo del texto del panel al sello (fase 6).
- [x] **Interpretar bordado** en el paño. Mantener 1,3 s cierra el círculo. *(Repasado el 01-oct: `TableDirector.embroideryAt`, solo con la tirada completa y desvelada; tests en `table_logic_test` y `table_director_test`.)*
- [x] **Interpretación de Tradición:** textos de `tarot_cards` por posición y sentido. El Oráculo queda fuera de esta versión (D4). *(01-oct: `tarot_table_service` lee `meaning_upright`/`meaning_reversed` con el giro aplicado, más el significado de la posición y las aclaratorias; la app lo enseña en la hoja de interpretación.)*
- [x] **«Lectura revelada» (D7):** interpretación a pantalla completa, una carta por página, con atmósfera por elemento (las de `ArcanumColors`), lámina desenfocada calculada una vez por carta (no en cada fotograma), volteo al entrar, tirada arriba y síntesis con «Cerrar el círculo». Respetar «reducir movimiento». Movimiento por elemento en la fase 6.
  - Construirla como dos piezas reutilizables: **Atmósfera** (color del elemento o planeta + lámina desenfocada + movimiento) y **Revelado** (una pantalla por pieza, con volteo y franja de contexto).
  - *(02-oct, hecho sin el movimiento por elemento.)* Piezas en `lib/shared/revelado/`: `Atmosphere` (luz del elemento + lámina decodificada a 24 px de ancho y estirada: el desenfoque sale del escalado, sin filtro por fotograma) y `RevealPager`, `RevealIn`, `RevealFlip`, `HoldToConfirm`. La de la mesa, en `lib/features/tarot/reading/lectura_revelada.dart`; la atmósfera de cada carta es la de su cara (`tarotAtmosphere`). El bordado abre antes un panel anclado con la pregunta, lo que cuesta y «Interpretar». Reabrir la lectura desde el bordado no vuelve a cobrar: la pantalla la guarda hasta cerrar el círculo.
  - *(02-oct, adelantado de la fase 6 a petición de Samuel.)* **Movimiento por elemento** en la lectura: `lib/shared/revelado/element_motion.dart` (ascuas en fuego, ondas en agua, polvo de luz en aire, motas en tierra, rayos en el Sol, estrellas en la Luna; invertida, lo que sube cae). Como mucho 44 piezas, un solo pintor, se para fuera de pantalla y con «reducir movimiento» no dibuja. La lámina desenfocada va teñida del elemento: una lámina clara (La Torre) lavaba la luz del fuego. Mirado en capturas del motor de Flutter con las fuentes reales; falta verlo en el GN2200.
  - **Fallo encontrado y arreglado (02-oct):** interpretar una mesa ya interpretada con una clave nueva volvía a cobrar (o daba 402 sin cupo). Ahora, si la petición es la misma lectura (tirada, pregunta y cartas con su hueco y su giro, en cualquier orden), el servidor devuelve la interpretación guardada sin tocar el cupo. Otra lectura distinta (por ejemplo, una carta girada) sí es otra interpretación y cobra.
- [x] **Lecturas guardadas:** continuar (30-sep). «Contemplar» sin tocar queda descartado por ahora: continuar ya enseña la mesa tal cual.
- [x] **Deshacer:** botón abajo a la izquierda con su anillo de 5 s, y el centro del radial (30-sep). Deshace lo local y, desde la decisión del 30-sep, también lo del servidor (ver fase 4).
- [x] **Contexto astral desde el backend**, con el lugar del usuario (`user_place.dart`). *(02-oct, opción A con detalles de B, decidido con Samuel.)* El servidor calcula fase y hora planetaria con el lugar de residencia confirmado (sin lugar, sin hora: no se inventa) y lo guarda en la lectura. Añadido: `moon_illumination` (0..1) y `read_at` en la respuesta de interpretar, sin migración; la hoja lo enseña en una línea («Luna creciente · 63 % iluminada · hora de Venus · 2 de octubre de 2026, 21:14»). **Diferencias con la especificación que se aceptan:** el cielo se anota al interpretar (o al cerrar sin interpretar), no con la primera carta; y la iluminación no se guarda en `tarot_readings`, solo viaja en la interpretación. Las dos pedirían columnas nuevas.

## Fase 6: efectos, sonido y háptica

- [ ] Símbolos del palo junto a la carta.
- [ ] Huella del palo en el paño: brasas, ondas, destello, polvo.
- [ ] Luz de la fase lunar y la fase dibujada en la cabecera.
- [ ] Humo al sellar y al cerrar el círculo.
- [ ] Muestras de sonido grabadas, con variación de tono (±5 %) y volumen (±3 dB). Vibración con `HapticFeedback`.
- [ ] Calidad adaptativa con `FrameTiming`.
- [ ] Respetar «reducir movimiento».

## Fase 7: calidad

### Prueba en GN2200 (03-oct-2026, APK profile)

- Puertas previas: `flutter analyze` verde; `flutter test` 811 pasan y 7 capturas manuales saltadas. Backend con las dos bases propias de esta rama: `pytest` 1399 pasan, 2 saltados; `scripts/verify_migrations.py` completo en verde. La APK profile apuntó a la API local mediante `adb reverse tcp:8000 tcp:8001`; el puerto 8000 del PC ya estaba ocupado y la API de la rama escuchó en 8001 con `DATABASE_URL` de desarrollo de la rama, sin cargar `.env`.
- Fallo hallado y corregido: el cajón ocultaba «Mesa de tarot · en pruebas» en profile por `!kReleaseMode`. Se muestra con `kDebugMode || kProfileMode`; sigue oculta en release. Verificado en el GN2200 y con `flutter analyze` y los 7 tests de `arcanum_drawer_test.dart` en verde.
- Recorrido observado: entrar en la mesa, abrir Rider–Waite–Smith, extender y sacar una carta, barajar en cascada, cortar en dos montones, elegir tirada de tres cartas, colocar una carta en Pasado y sellar la pregunta. La mesa recuperó su estado al salir y volver. [Captura de la tirada y el abanico](../.qa-mesa/gn2200-tres-cartas.png).
- Quedaron sin verificar en esta pasada: desvelado y sus efectos, lectura larga y paginación, cierre de 1,3 s, historial, «reducir movimiento» y Cruz Celta completa. Samuel pidió detener ese recorrido; la inspección posterior de abajo reabre la revisión. `adb logcat -d -s Choreographer:I | findstr /i "Skipped Choreographer"` no devolvió líneas en esta consulta; no hubo ventana de medida controlada ni `FrameTiming`, así que **no se afirma 60 fps** y el criterio de rendimiento sigue pendiente.
- **Hallazgo posterior, bloqueante (03-oct):** [captura GN2200 del estado real](../.qa-mesa/gn2200-caos-cartas.png). Tras seguir sacando y moviendo cartas, la cámara quedó inclinada y el paño parcialmente fuera de pantalla; cartas y montones se amontonan sobre los huecos y el abanico invade sello y bordado. Samuel reporta que al tocar una carta tarda en salir, a veces aparece enorme, hay que moverla para sacar otra y la interacción se bloquea. La captura confirma la geometría y las superposiciones; latencia y bloqueo requieren reproducción cronometrada. **No dar la mesa por aprobada en móvil.** Diagnosticar cámara, tamaños proyectados, orden de capas, hit-test y espera de `ops.take` antes de seguir con publicación.

### Reparación de la mesa en móvil (03-oct-2026, sesión en la nube, sin el GN2200)

**Reproducido antes de tocar nada**, sobre `483a8d1`, con una mesa de 78 cartas en 360 × 760 (la pantalla útil del GN2200) y un servidor de pruebas que no contesta hasta que el test lo suelta:

- **Tocar una carta del abanico no se ve hasta que contesta el servidor**, y un segundo toque durante la espera **se tira en silencio** (`_busy`): de dos toques salió una sola petición. Es el «tarda» y el «se bloquea».
- **Arrastre corto soltado antes de la respuesta** (12 px de temblor, por encima del umbral de 6): la carta se queda **para siempre** levantada (`lift` 64), marcada como arrastrándose, a **escala 1,0** (la carta más grande de la mesa; el abanico va a 0,55) y **encima del abanico** (13 806 u² de solape), robando el toque de las cartas de debajo hasta que se arrastra otra vez. Es «sale enorme y hay que moverla para sacar otra».
- **Sin tirada, o con la tirada llena, todas las cartas sacadas caen en (470, 472)**: una sobre otra y sobre el hueco «Futuro» de la tirada de tres. Es el montón de la captura.
- **Con el abanico abierto, el sello no se puede tocar**: el toque se lo lleva el abanico.
- **Cámara.** El zoom acercaba la mesa a la cámara (`scale3d(K, K, K)` del prototipo), así que la perspectiva se disparaba: con 56° y zoom 2,6, una carta suelta levantada en la esquina cercana ocupaba el **88 % del alto** (8,6 veces lo que mide sin zoom). Pellizcar acercaba hacia el centro de la mesa y no hacia los dedos, y lo que había bajo los dedos se escapaba. El límite del desplazamiento era un rectángulo de pantalla que no sabía del giro ni de la inclinación. La cámara **no se guardaba nunca** (`TableState.camera` siempre por defecto). El doble toque para recentrar solo valía sobre el paño, justo lo que falta cuando la mesa se ha ido.

**Corregido** (`ce28646`, `e0b80b8`; tests en `0dd8cc7`):

- **Sacar del abanico sin esperar.** La carta sale del abanico y vuela a su hueco en el mismo fotograma del toque, como un dorso (`PieceKind.pendingCard`); el hueco queda reservado y el siguiente toque va al siguiente. Cuando el servidor dice qué carta era, la de verdad ocupa ese sitio. Si falla, el dorso vuelve al abanico y se avisa. Las peticiones siguen en fila en el controlador: el servidor no recibe dos a la vez.
- **Arrastre que termina antes de la respuesta:** la carta se suelta donde quedó, sin altura y a la escala de la tirada. **Soltada sobre el abanico se coloca como un toque** (primer hueco libre o sitio libre): así un temblor no la deja tapando las demás.
- **Sitio libre para las cartas sueltas** (`freeSpot` en `table_geometry.dart`): por encima de la zona cercana (y < 690, el límite de la especificación), sin pisar huecos de la tirada (aunque estén vacíos), sello, bordado, montones con su nombre ni otras cartas, y lo más cerca posible de donde salió. Si no queda sitio, el que menos tapa. Los cortes buscan sitio igual, primero en la zona cercana.
- **Sello y bordado encendido por encima del abanico y los montones**, al dibujar y al tocar. La especificación los pone en la misma zona (abanico en y 782, sello en 712, «Interpretar» en 716); las cartas en juego sí pueden taparlos, como antes.
- **Toque igual a lo dibujado:** cada pieza se busca en su plano (`toTable(screen, z:)`), así que una carta levantada se toca donde se ve; primero lo que hay justo bajo el dedo y solo después el margen de 24 unidades, para que el margen de una carta no le robe el toque al sello o a la de al lado.
- **Cámara:** el zoom amplía la imagen ya proyectada (el rango 1–2,6 de la especificación no cambia; ahora todo crece igual). Pellizcar acerca hacia los dedos. El centro de la pantalla cae **siempre en el paño**, con cualquier giro, inclinación y zoom. La cámara se guarda con la mesa y, al restaurarla, se mete en los límites. **Doble toque fuera de la mesa también recentra.**
- **Medida de la espera:** `TableDirector.takeTimings` guarda lo que tardó el servidor en cada carta y, fuera de release, sale en el log como `[mesa] sacar carta: N ms`. En el GN2200: `adb logcat -s flutter | findstr "sacar carta"`.

**Medido en tests** (motor de Flutter, 360 × 760; **no es el móvil**):

| | Antes | Después |
|---|---|---|
| Toque en el abanico con el servidor sin contestar | nada visible; el segundo toque, perdido | dorso en su hueco en el mismo fotograma; 3 toques = 3 cartas; Cruz Celta 10 de 10 |
| Carta más grande en pantalla (suelta, levantada, cualquier cámara permitida) | 672 px (88 % del alto) | 216 px (28 %); nunca crece más que el zoom |
| Paño a la vista con zoom 1 | — | 100 % sin giro; 90–91 % con giro de 40° |
| Paño a la vista con zoom 2,6 | — | 34–44 % (es el zoom); el centro siempre en el paño |
| 4 cartas sacadas sin tirada | las 4 en (470, 472), sobre «Futuro» | 4 sitios distintos, sin tocarse ni tocar el abanico |

Capturas del motor con el mismo guion (cuatro cartas sin tirada, tirada de tres, sello): [antes](../.qa-mesa/motor-antes-reposo.png) y [después](../.qa-mesa/motor-despues-reposo.png); y con la cámara inclinada y acercada: [antes](../.qa-mesa/motor-antes-zoom.png) y [después](../.qa-mesa/motor-despues-zoom.png). Las letras salen como cajas: el motor de tests no carga las fuentes.

- **Puertas:** `flutter analyze` sin avisos; `flutter test` 825 pasan y 7 capturas manuales saltadas (14 tests nuevos en `mesa_movil_test.dart` y `mesa_movil_view_test.dart`). No se tocó el backend, así que no se corrieron `pytest` ni `verify_migrations`.
- **Pendiente de comprobar en el GN2200 (APK profile):** que la carta se vea al instante con la red real y cuánto tarda el servidor (`[mesa] sacar carta`); que no se pierdan toques rápidos seguidos; tres cartas y Cruz Celta completas a toques; que un toque con temblor no deje cartas sobre el abanico; pellizco, giro y doble toque fuera de la mesa; que la cámara vuelva como se dejó; y fps quieta, con abanico y con la Cruz Celta. **No se afirma 60 fps.**

**Decisiones abiertas para Samuel** (no se han tocado; las cifras son de 360 × 760):

1. **Giro de ±40° con zoom 1:** deja fuera hasta un 10 % del paño (esquinas). A) Dejarlo así: se recupera con doble toque en cualquier sitio. B) Encuadre que se aleja con el giro para que entre entero (la especificación solo fija que *inclinar* no cambia el zoom). C) Bajar el giro máximo; habría que medir con qué valor entra entero.
2. **Umbral de toque:** 6 px, el del prototipo (pensado para ratón). Flutter usa 18 (`kTouchSlop`). Con 6, un temblor convierte un toque en arrastre; lo corregido cubre las cartas del abanico, no los montones ni las cartas sueltas. A) 6. B) 18. C) Un valor medido en el GN2200.
3. **Abanico frente a sello y bordado:** hoy se resuelve con el orden de capas. A) Dejarlo. B) Bajar la línea del abanico dentro de la zona cercana (y 690–880) para que no se pisen; cambia una coordenada de la especificación (y = 782).

- [ ] Medir en el móvil real con Impeller: 60 fps quieta y con la Cruz Celta; el abanico sin tirones.
- [ ] Accesibilidad: `Semantics` en cartas y radial, 48 dp, lectores de pantalla.
- [ ] Probar en el móvil más pequeño de la prueba cerrada (360 dp). *(02-oct, en tests: `pantalla_pequena_test.dart` abre la mesa, el panel de lecturas y una Cruz Celta con textos largos en 360×640 y 360×740, sin desbordes y con «Cerrar el círculo» al alcance. Cazó un fallo: con texto largo la carta se quedaba con el deslizamiento y no se podía pasar a la siguiente; ahora, al llegar al final del texto, seguir tirando pasa de carta. Falta verlo en un móvil real de 360 dp.)*
- [ ] Revisión de código (`/code-review`) antes de mezclar.

## Fase 8: publicar

- [ ] Pestaña «Tarot» en la navegación principal (D2).
- [ ] Mezclar a `main` solo con las puertas en verde. Ojo: **eso despliega el backend en el acto**.
- [ ] Comprobar el commit vivo en Railway (`railway status --json`).
- [ ] Build para la prueba cerrada de Play.
- [ ] Nota en el vault y actualizar la especificación con lo que haya cambiado.

---

## Después de la mesa: llevar «Atmósfera» y «Revelado» a otras pantallas

Decidido el 02-oct-2026: solo en **momentos de revelación** (cuando la app entrega una lectura, una carta o un horóscopo), no en listas, formularios ni ajustes. Cada una en su rama, fuera de `feat/mesa-tarot`. Orden propuesto:

1. **Estudiar una carta (Saber):** ficha de cada arcano con su atmósfera y su lámina.
2. **Lecturas guardadas:** reabrirlas como «Lectura revelada», con el cielo de aquel día.
3. **Oráculo (tiradas con IA):** pide que el texto venga separado por carta; tocar el prompt solo midiendo con `arcanum-voz`.
4. **Materia Arcana:** ficha con la atmósfera de su planeta y su grabado desenfocado (ya existe `materia_plate_reveal`).
5. **Horóscopo diario:** atmósfera del elemento del signo y su lámina del zodiaco.
6. **Hoy:** solo un tinte de fondo según la hora planetaria.

## Decisiones

| # | Decisión | Estado |
|---|---|---|
| D1 | ¿Cuándo se gasta el cupo diario de tarot? (gratis 1 al día, premium 10: `TAROT_FREE_DAILY` / `TAROT_PREMIUM_DAILY` en `config.py`; el 50 que ponía aquí era un error) | **Decidido por Samuel (29-sep): al pulsar Interpretar.** Barajar, cortar, sacar y desvelar son libres. Consecuencia: se pueden ver cartas sin gastar cupo, pero la lectura guardada y la interpretación sí lo gastan. La reserva con `Idempotency-Key` va en la ruta de interpretar. |
| D2 | ¿Dónde entra el módulo en la app? | **Decidido: pestaña propia «Tarot»** en la navegación principal. |
| D3 | ¿Todo de golpe o por entregas? | **Decidido: por fases.** Primera entrega = fases 1–5 (mesa y ritual) a la prueba cerrada. Segunda = fase 6 (efectos, sonido, háptica). |
| D4 | ¿Oráculo con IA en la mesa? | **Decidido: solo Tradición en la primera versión.** El Oráculo, más adelante, con `arcanum-voz` y el cupo de Groq resuelto. |
| D6 | ¿Sobre qué base va la migración de sesiones? | **Cerrada el 29-sep-2026.** `release/1.0.6` se mezcló en `main` (PR #9, `3ebf688`) y Railway lo desplegó: producción está en la **014** con `sendero_progress`, comprobado leyendo `alembic_version`. Esta rama se rebasó sobre ese `main`; la migración de la mesa es la **015**, colgando de la 014. **Reabierta y cerrada el 01-oct-2026:** mientras tanto `main` sacó a producción su propia 015 (`015_add_fragments.py`, `fragment_movements`). Al traer `main` a esta rama, la de la mesa pasó a **016** (`016_add_tarot_sessions.py`), colgando de la 015 de fragmentos. Las dos no tocan las mismas tablas. |
| D5 | ¿La pregunta de la lectura se cifra? | **Cerrada el 29-sep: se hace lo mismo que la app de hoy.** Comprobado: `/tarot/spread` y `/tarot/draw-one` reciben la pregunta **en claro** y el servidor la guarda así. El comentario del modelo que decía «en el cliente se cifra» era falso y está corregido. La mesa manda la pregunta en claro al interpretar (el Oráculo, cuando llegue, la necesita legible). En el móvil, en cambio, el autoguardado de la mesa va **cifrado**. Si algún día se quiere la pregunta cifrada también en el servidor, es un cambio para todas las tiradas, no solo para la mesa. |
| D7 | ¿Cómo se abren leer, pregunta, lecturas e interpretación? | **Decidido por Samuel (02-oct-2026).** Leer carta, pregunta y lecturas guardadas: **paneles compactos anclados** a lo que se tocó, como pide la especificación. Interpretación: **«Lectura revelada»**, una carta por pantalla (paginado vertical) con la atmósfera de su elemento, su lámina desenfocada detrás, volteo al entrar (invertida entra invertida), la tirada asomando arriba con la carta actual iluminada, y una síntesis final con «Cerrar el círculo» manteniendo 1,3 s. Se aparta de la especificación solo en la interpretación, que pedía un panel anclado: con 10 cartas no se lee bien en una caja pequeña. Maquetas: `prototipos/paneles-mesa.html` y `prototipos/lectura-revelada.html`. El movimiento por elemento (ascuas, ondas, polvo de luz, motas, rayos) es la «huella del palo» de la fase 6: primero colores y volteo, el movimiento después. **El diseño se reutilizará** en otras pantallas de revelación (ver «Después de la mesa»). |

## Entorno de pruebas de esta rama

Esta rama va por la **016** y las bases de pruebas compartidas están en la 015 (lo que hay en `main`).

> **Desde el 01-oct, las bases propias de esta rama están en una 015 que NO es la de `main`:** su `alembic_version` dice 015 pero tienen `tarot_sessions`, no `fragment_movements`. Hay que vaciarlas y migrar de cero (`DROP SCHEMA public CASCADE; CREATE SCHEMA public;`). Lo mismo con `arcanum_dev_mesa`. Con ellas, los `tests_pg` se saltan porque la cabeza no coincide. Esta rama usa bases propias en los mismos contenedores, sin tocar las compartidas:

```
TEST_DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:5434/arcanum_test_mesa
MIGRATION_TEST_DATABASE_URL=postgresql://postgres:test@127.0.0.1:55434/arcanum_migration_test_mesa
ARCANUM_DATA_DIR=D:/Proyectos/Arcanum-datos
PYTHON=D:/Proyectos/Arcanum/arcanum-api/.venv/Scripts/python.exe
```

Además, el JSON de la biblioteca se copia desde la carpeta principal: está en `.gitignore`.

## Riesgos

- **Numeración de migraciones:** resuelto (D6). `main` y producción están en la 015 (fragmentos); la de sesiones de la mesa es la 016. Si `main` saca otra migración antes de mezclar, volver a renumerar.

- **Mezclar a `main` despliega.** Toda la API nueva es aditiva y va detrás de rutas nuevas.
- **Rendimiento de Flutter con muchas cartas en `Transform`:** por eso la prueba va al principio de la fase 4.
- **Cupo de Groq:** no afecta mientras la mesa use solo Tradición (D4).
- **Sesiones abandonadas:** caducidad y limpieza (una activa por usuario).
