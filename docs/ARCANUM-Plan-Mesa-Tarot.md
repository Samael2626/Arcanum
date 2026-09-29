# Plan: llevar la mesa de tarot a la app

**Especificación:** `docs/ARCANUM-Spec-Mesa-Tarot.md`.
**Prototipo de referencia:** `prototipos/tarot-mesa-3d-v2.html`.
**Orden de trabajo** (el que pide `AGENTS.md`): backend primero, después la interfaz; tests en cada fase.

## Puntos de partida (comprobados en el código, 29-sep)

- **Tiradas:** `app/domain/spreads.py` tiene 3 (`one_card`, `three_card`, `celtic_cross`) en un registro en código. Faltan Cruz simple, Relación, Herradura y Rueda del año.
- **Sorteo:** `TarotService.draw_spread` sortea con `random.sample` en el momento, sin sesión, sin montones y sin elegir posiciones. `random` no sirve para un sorteo que queramos poder defender: hay que usar `secrets.SystemRandom`.
- **Cupo:** `/tarot/spread` y `/tarot/draw-one` reservan el cupo diario (`TAROT_FREE_DAILY` / `TAROT_PREMIUM_DAILY`) con `Idempotency-Key`. Las lecturas se guardan en `tarot_readings` con fase lunar y hora planetaria.
- **Migraciones:** la última es la 014. La nueva será la 015.
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

- [ ] Medir el prototipo en un móvil real con `#fps` (quieta, Cruz Celta, abanico, girando). Es la referencia a batir en Flutter.
- [x] Decisiones D1–D4 cerradas con Samuel el 29-sep; D5 se comprueba en la fase 3.
- [ ] `git worktree add ../Arcanum-mesa -b feat/mesa-tarot origin/main` y traer la especificación, el plan y el prototipo.

## Fase 1: dominio del backend (sin HTTP)

- [ ] **Catálogo de tiradas:** pasar a 7, con las mismas posiciones, nombres y significados que el prototipo, incluidas las coordenadas del paño. Una sola fuente para la app y el Oráculo, sin romper los 3 slugs actuales.
- [ ] **Catálogo de mazos:** Rider–Waite–Smith (78) y Arcanos Mayores (22), como datos: cartas incluidas, si admite invertidas y arte.
- [ ] **`TarotSession` como entidad de dominio pura:** abrir, barajar, cortar, unir, sacar por posición, devolver y recoger. Montones con posiciones estables (`null` = sacada) e invertidas decididas al barajar.
- [ ] Azar con `secrets.SystemRandom`, inyectable para poder testear con semilla.
- [ ] **Tests unitarios puros**, sin base de datos:
  - [ ] Barajar mantiene el conjunto de cartas.
  - [ ] Cortar y unir conservan el orden esperado, incluido el corte clásico.
  - [ ] Sacar por posición es estable mientras hay un abanico abierto.
  - [ ] Devolver y recoger no duplican ni pierden cartas: siempre suman 78 o 22.
  - [ ] Con el mazo de Mayores nunca sale un Menor.

## Fase 2: persistencia y API

- [ ] **Migración 015:** tabla `tarot_sessions` (usuario, mazo, estado JSONB, estado de la sesión, creada/actualizada, caducidad). Como mucho una sesión activa por usuario.
- [ ] Repositorio y servicio de aplicación, con la misma estructura en capas que ya usa el módulo.
- [ ] **Rutas nuevas:**
  - [ ] `GET /tarot/decks` y `GET /tarot/spreads`: catálogos.
  - [ ] `POST /tarot/sessions`: abrir con un mazo. `GET /tarot/sessions/current`: estado sin revelar el orden.
  - [ ] `POST /tarot/sessions/{id}/shuffle | cut | merge | take | return | gather`: libres, sin cupo.
  - [ ] `POST /tarot/sessions/{id}/interpret`: gasta el cupo (D1) y devuelve la interpretación de Tradición.
  - [ ] `POST /tarot/sessions/{id}/close`: cierra el círculo y guarda la lectura.
  - [ ] **El cliente nunca recibe el orden de los montones:** solo cuántas cartas quedan y las que ya sacó.
- [ ] **Cupo (D1):** la sesión y sus operaciones son libres; el cupo se reserva en `POST /tarot/sessions/{id}/interpret`, con `Idempotency-Key` como hoy. Esa misma ruta devuelve la interpretación de Tradición y deja la lectura lista para guardarse.
- [ ] **Cerrar el círculo:** guarda la lectura en `tarot_readings` con fase, hora planetaria, pregunta, tirada, cartas y aclaratorias.
- [ ] **Historial:** listar y leer lecturas guardadas para contemplarlas y continuarlas.
- [ ] Tests con base de datos (`tests_pg`) de rutas, cupo, idempotencia y permisos (un usuario no toca la sesión de otro).
- [ ] **Puerta:** suite completa con las dos bases + `verify_migrations`.

## Fase 3: base de la app

- [ ] `lib/features/tarot/` con la estructura de la especificación (§10).
- [ ] Cliente de la API nueva en `arcanum_api.dart` y modelos.
- [ ] `TableState`: el equivalente de `serialize`, con providers de Riverpod (`@riverpod` + codegen).
- [ ] Autoguardado local **cifrado**, igual que el Grimorio.
- [ ] Tests unitarios de `TableState`: serializar y restaurar, y deshacer con copias reales, no referencias.

## Fase 4: la mesa

- [ ] **Prueba de rendimiento primero:** 78 cartas en `Transform` sobre un `Stack` en el móvil real con Impeller. Si no llega a 60 fps, se decide ya entre `Stack` de widgets y pintar las cartas del abanico con `CustomPainter`.
- [ ] **`TableCamera`:** `Matrix4` con perspectiva 1/1000, inclinación y giro. Inversa para convertir toques en unidades de mesa. Encuadre a 30° e inercia.
- [ ] **`DeckPiece`:** caja con grosor según el número de cartas. **`CardPiece`:** envuelve `TarotCardView` y añade la bisagra de la esquina y el muelle de inclinación.
- [ ] **Huecos de las 7 tiradas**, con imán, intercambio y aclaratorias.
- [ ] **Gestos de la tabla de la especificación (§3):** tocar, mantener 430 ms, arrastrar, esquina, doble toque, pellizcar. Zona de toque de 48 dp.
- [ ] **`RadialMenu`:** círculos sueltos de 52 dp, elección por ángulo deslizando y soltando, orden fijo.
- [ ] **Paneles compactos:** Leer, pregunta, interpretación y lecturas.
- [ ] **Widget tests:** tocar, mantener abre el radial, arrastrar encaja en el hueco, esquina voltea pasados 70°.

## Fase 5: el ritual

- [ ] **Sellar la pregunta** (animación hasta el sello) y romper el sello al interpretar.
- [ ] **Interpretar bordado** en el paño. Mantener 1,3 s cierra el círculo.
- [ ] **Interpretación de Tradición:** textos de `tarot_cards` por posición y sentido. El Oráculo queda fuera de esta versión (D4).
- [ ] **Lecturas guardadas:** contemplar y continuar.
- [ ] **Deshacer:** botón en la esquina con su anillo, y el centro del radial.
- [ ] **Contexto astral desde el backend**, con el lugar del usuario (`user_place.dart`).

## Fase 6: efectos, sonido y háptica

- [ ] Símbolos del palo junto a la carta.
- [ ] Huella del palo en el paño: brasas, ondas, destello, polvo.
- [ ] Luz de la fase lunar y la fase dibujada en la cabecera.
- [ ] Humo al sellar y al cerrar el círculo.
- [ ] Muestras de sonido grabadas, con variación de tono (±5 %) y volumen (±3 dB). Vibración con `HapticFeedback`.
- [ ] Calidad adaptativa con `FrameTiming`.
- [ ] Respetar «reducir movimiento».

## Fase 7: calidad

- [ ] Medir en el móvil real con Impeller: 60 fps quieta y con la Cruz Celta; el abanico sin tirones.
- [ ] Accesibilidad: `Semantics` en cartas y radial, 48 dp, lectores de pantalla.
- [ ] Probar en el móvil más pequeño de la prueba cerrada (360 dp).
- [ ] Revisión de código (`/code-review`) antes de mezclar.

## Fase 8: publicar

- [ ] Pestaña «Tarot» en la navegación principal (D2).
- [ ] Mezclar a `main` solo con las puertas en verde. Ojo: **eso despliega el backend en el acto**.
- [ ] Comprobar el commit vivo en Railway (`railway status --json`).
- [ ] Build para la prueba cerrada de Play.
- [ ] Nota en el vault y actualizar la especificación con lo que haya cambiado.

---

## Decisiones

| # | Decisión | Estado |
|---|---|---|
| D1 | ¿Cuándo se gasta el cupo diario de tarot? (gratis 1 al día, premium 50) | **Decidido por Samuel (29-sep): al pulsar Interpretar.** Barajar, cortar, sacar y desvelar son libres. Consecuencia: se pueden ver cartas sin gastar cupo, pero la lectura guardada y la interpretación sí lo gastan. La reserva con `Idempotency-Key` va en la ruta de interpretar. |
| D2 | ¿Dónde entra el módulo en la app? | **Decidido: pestaña propia «Tarot»** en la navegación principal. |
| D3 | ¿Todo de golpe o por entregas? | **Decidido: por fases.** Primera entrega = fases 1–5 (mesa y ritual) a la prueba cerrada. Segunda = fase 6 (efectos, sonido, háptica). |
| D4 | ¿Oráculo con IA en la mesa? | **Decidido: solo Tradición en la primera versión.** El Oráculo, más adelante, con `arcanum-voz` y el cupo de Groq resuelto. |
| D5 | ¿La pregunta de la lectura se cifra? | Abierta. El modelo anota «texto plano; en el cliente se cifra». **Sin comprobar** qué hace hoy la app: verificarlo en la fase 3 y aplicar lo mismo a la pregunta sellada. |

## Riesgos

- **Mezclar a `main` despliega.** Toda la API nueva es aditiva y va detrás de rutas nuevas.
- **Rendimiento de Flutter con muchas cartas en `Transform`:** por eso la prueba va al principio de la fase 4.
- **Cupo de Groq:** no afecta mientras la mesa use solo Tradición (D4).
- **Sesiones abandonadas:** caducidad y limpieza (una activa por usuario).
