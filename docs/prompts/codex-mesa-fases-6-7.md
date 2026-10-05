# Prompt para Codex — Mesa de tarot: seguir con las fases 6 y 7 y documentarlo en el vault

Carga las skills `arcanum-dev` y `arcanum-tarot` antes de empezar.

## Dónde trabajas y lo que no se toca

- Trabaja **solo** en la rama `feat/mesa-tarot`, en el worktree `D:\Proyectos\Arcanum-mesa`. No cambies de rama en `D:\Proyectos\Arcanum`: lo usan otras sesiones.
- **Nunca push ni merge a `main`: despliega a producción en el acto.** Push solo a `origin/feat/mesa-tarot`. No abras PR.
- Commits pequeños con `git commit -- <rutas>`: el índice lo comparten otras sesiones. Si un archivo es nuevo, `git add -- <ruta>` justo antes.
- Nunca `ARCANUM_SKIP_HOOKS=1`. Si un hook bloquea, el bloqueo es el dato.
- No arranques el backend con `arcanum-api/.env`: apunta a producción.
- No toques el stash «cambios locales viejos mesa» ni cambios ajenos. `arcanum_app/android/local.properties` modificado no es tuyo: déjalo como está.
- No empieces D8, la mesa sin conexión ni la fase 8 (pestaña, mezclar, publicar) sin aprobación explícita de Samuel.
- No inventes tamaños objetivo ni decisiones de producto que no estén en los planes. Si hay que elegir, para y propón opciones concretas con números.

## Lee primero

1. `AGENTS.md`.
2. `docs/ARCANUM-Plan-Mesa-Tarot.md`, sobre todo la **fase 6**, la **fase 7**, la tabla de **decisiones** y **«Entorno de pruebas de esta rama»**.
3. `docs/ARCANUM-Spec-Mesa-Tarot.md`, §3 (gestos), §6 (efectos), §7 (sonido y háptica) y §9 (rendimiento).
4. `docs/ARCANUM-Plan-Animaciones-3D.md` (tanda 2 de la mesa).
5. `prototipos/tarot-mesa-3d-v2.html`, la referencia de cada efecto. Porta sus números; no los reinventes.

## Estado al empezar (commit `6a97a56`, 05-oct-2026)

Puertas: `flutter analyze` sin avisos; `flutter test` 868 pasan, 7 saltados. No se ha tocado el backend desde la fase 5.

Hecho desde el fallo del GN2200 (03-oct, `483a8d1`), todo en `arcanum_app/lib/features/tarot/table/` salvo donde se indica:

- **Reparación en móvil** (`ce28646`, `e0b80b8`, tests `0dd8cc7`, doc `e25cee7`). Sacar del abanico ya no espera a la red: la carta sale en el acto y el hueco queda reservado. Ya no se queda pegada una carta enorme y levantada al soltar un arrastre antes de la respuesta. Las cartas sueltas y los cortes buscan sitio libre (`freeSpot` en `table_geometry.dart`). Sello y bordado se pintan sobre el abanico. El hit-test sigue el plano de cada pieza. Cámara: zoom como lupa, centro siempre en el paño, pellizco hacia los dedos, cámara guardada y doble toque fuera de la mesa. Evidencia en `.qa-mesa/motor-*.png`.
- **Medidor y calidad adaptativa** (`d58c2f7`, `table_quality.dart`). Fuera de release escribe en el log `[mesa fps] escena=… fps=… montaje_p90=… dibujo_p90=…`. Por debajo de 40 fps baja de nivel: nivel 1 sin brillos ni sombras desenfocadas; nivel 2, efectos a medio ritmo y sin huellas.
- **«Reducir movimiento» en toda la mesa y vibración** (`fd8dd8e`, `table_haptics.dart`). Tests en `2891218`.
- **Decisiones de Samuel del 05-oct** (`05b8c1b`): las sombras cuentan como brillos; «Silenciar» del radial del paño apaga la vibración y se recuerda (`tarot_mesa_silencio`).
- **Símbolos del palo** (`bcc259d`, `suit_pips.dart`), **humo** al romper el sello y al cerrar el círculo (`2111f53`, `table_smoke.dart`) y **luz de la Luna** con su fase en la cabecera (`c6f07af`, `table_moon.dart`). Documentación en `99c845d` y `6a97a56`.

Sigue abierta y **no la cambies:** cuándo vuelve a subir la calidad. Ahora es provisional: 3 ventanas seguidas a 55 fps o más.

## Qué hacer, en este orden

### 1. Accesibilidad (fase 7)

- **Revisión con tests a 360 × 760:** `Semantics` con nombre útil en cartas (nombre, sentido y hueco), radial (cada opción y el centro), sello, bordado, deshacer, disco de la Luna y la carta pendiente. Que lo decorativo (humo, luz, símbolos del palo, huellas) quede fuera del lector de pantalla.
- **Medir las zonas de toque** en dp, en reposo y con zoom 1, contra los 48 dp de la especificación. Arregla lo que esté claramente por debajo sin cambiar el diseño, con su test.
- **Abanico de 78 cartas:** cada una asoma unos 3 px a 360 dp, así que elegir una carta concreta es imposible. **No lo decidas tú.** Mide el ancho visible real por carta y propón 2 o 3 opciones con números (por ejemplo, lupa al mantener o abanico en dos filas). Déjalas en el plan como decisión abierta.

### 2. Revisión de código de toda la rama

Revisa la rama frente a `main`. Por cada fallo **confirmado**: un test que falle antes, el arreglo y el test en verde. Lo dudoso va al plan como «a revisar», no se cambia.

### 3. Tanda 2 de la mesa, solo lo que no pide decisión

- **La pregunta que vuela al sello** (especificación §6 «Pregunta sellada» y la función `sealQuestion` del prototipo: el texto vuela y se encoge hasta el sello).
- **Cerrar el círculo con el anillo dorado** (`circleMark` del prototipo: 3,4 s, opacidad 0 → 0,9 → 0, escala 0,7 → 1,08) y las cartas que vuelven despacio.
- **Reglas para las dos:** respetan «reducir movimiento» y el nivel de calidad (`TableQualityScope`); usan las piezas de `table_motion.dart` y `table_fx.dart`; nada que repinte el paño en cada fotograma (§9).

### 4. Lo que no se hace

- **Sonido:** espera las grabaciones de Samuel. No sintetices sonido ni metas archivos de prueba.
- **El brillo al inclinar el móvil** (giroscopio): queda para después.

## Cómo probar

- `flutter analyze` y `flutter test` en verde antes de cada commit. Anota cuántos pasan y cuántos se saltan.
- **Nunca `pumpAndSettle`** con la mesa (tiene animaciones); usa fotogramas (`settleFrames` o `pump` con duración).
- Usa `FakeServer` de `test/features/tarot/fakes.dart`. Para la red lenta, el patrón de `_SlowServer` de `mesa_movil_test.dart`.
- Cada test nuevo de comportamiento tiene que **fallar sin el cambio**: compruébalo una vez quitándolo.
- Si tocas el backend (no debería hacer falta), solo con las dos bases propias de la rama (ver el plan) y con `pytest` y `scripts/verify_migrations.py` en verde.
- **No tienes el GN2200.** No afirmes nada de rendimiento ni de cómo se ve o se siente en el móvil. Escribe en el plan qué queda por comprobar en el aparato.

## Documentar

### En el repo (en cada commit que cierre algo)

Actualiza la fase 6 o la 7 de `docs/ARCANUM-Plan-Mesa-Tarot.md`: qué se hizo, dónde (archivo), con qué tests, qué queda por mirar en el GN2200 y las decisiones abiertas con sus opciones.

### En el vault, al terminar

El vault de proyecto es `D:\Brain\10-Proyectos\ARCANUM\`. La nota cubre **todos los avances desde el 03-oct** (de `483a8d1` a tu último commit), no solo lo tuyo. Usa el formato de los checkpoints de `docs/checkpoints/`:

```
---
title: "Checkpoint — ARCANUM Mesa de tarot — <fecha>"
date: <fecha>
tags: [checkpoint, arcanum, tarot, mesa, flutter]
---

# Checkpoint — ARCANUM Mesa de tarot — <fecha>

Relacionado: [[MOC-ARCANUM]]

## Resumen
## Cambios realizados   (por bloque, con commit y archivo)
## Medido               (solo lo medido: tests, capturas del motor; nada del móvil que no se haya medido)
## Estado actual        (rama, último commit, puertas en verde con números)
## Pendiente en el GN2200
## Decisiones de Samuel  (las cerradas, con fecha) y abiertas (con opciones)
```

**Regla del vault: las escrituras de más de 500 caracteres solo las hace Claude Code** (ver `.claude/agents/arcanum-ui3d.md` y `arcanum-artist.md`). Salvo que Samuel te diga explícitamente que la levanta para esta nota:

1. Escribe la nota **completa** en el repo, en `docs/checkpoints/<fecha>-mesa-tarot.md`, y haz commit.
2. En el vault deja solo una nota de **500 caracteres o menos**: título, fecha, rama, rango de commits y la ruta de la nota completa en el repo.
3. Dile a Samuel que la nota completa está lista para copiarla al vault.

## Al terminar

Haz push a `origin/feat/mesa-tarot` y entrega un resumen corto:

- qué se hizo, con commits;
- números de las puertas;
- qué queda por comprobar en el GN2200;
- decisiones abiertas con sus opciones;
- dónde quedó la nota del vault.
