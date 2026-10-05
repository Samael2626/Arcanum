---
title: "Checkpoint — ARCANUM Mesa de tarot — 2026-10-04"
date: 2026-10-04
tags: [checkpoint, arcanum, tarot, mesa, flutter]
---

# Checkpoint — ARCANUM Mesa de tarot — 2026-10-04

Relacionado: [[MOC-ARCANUM]]

## Resumen

La rama `feat/mesa-tarot` avanzo desde el fallo visto en el GN2200 el 03-oct. Se reparo la extraccion inmediata de cartas, el encuadre y el orden de capas; se agregaron medicion de fotogramas, calidad adaptativa, vibracion, simbolos, humo y luz lunar. La fase 7 ahora ofrece una lista accesible para elegir una de las 78 posiciones. La tanda 2 suma el vuelo de la pregunta, el anillo de cierre y el retorno lento de las cartas. No se ha publicado la mesa.

## Cambios realizados

- `ce28646`, `e0b80b8`, `0dd8cc7`, `e25cee7`: camara recuperable y zoom como lupa (`table_camera.dart`); sacar una carta dibuja un dorso al instante, reserva el hueco y evita que un arrastre breve bloquee el abanico (`table_director.dart`, `table_geometry.dart`). Sello y bordado quedan sobre el abanico (`table_view.dart`). Tests de red lenta en `mesa_movil_test.dart` y `mesa_movil_view_test.dart`.
- `d58c2f7`, `fd8dd8e`, `2891218`, `99c845d`: `table_quality.dart` mide escenas en ventanas de 2 s; baja calidad bajo 40 fps. `table_haptics.dart` incorpora vibracion y la mesa respeta «reducir movimiento». `mesa_calidad_test.dart` cubre estos casos.
- `05b8c1b`: sombras sin desenfoque desde calidad 1 y «Silenciar» apaga tambien la vibracion; se recuerda entre sesiones (`table_quality.dart`, `table_pieces.dart`, `table_director.dart`, `tarot_screen.dart`).
- `bcc259d`, `2111f53`, `c6f07af`, `6a97a56`: simbolos de palo junto a la carta (`suit_pips.dart`), humo al romper el sello y cerrar (`table_smoke.dart`), luz y disco de la fase lunar (`table_moon.dart`). Tests en los archivos correspondientes.
- `b71fe87`: lista de 78 posiciones con filas de 48 dp (`table_overlays.dart`, `tarot_screen.dart`, `fan_picker_test.dart`); centro del radial con cuadro semantico de 48 dp (`table_view.dart`). Se corrigio la creacion tardia del ticker de humo en `table_smoke.dart`, que hacia fallar 34 pruebas de widgets al desmontar la mesa.
- `63cace8`: pregunta que vuela al sello en 760 ms; anillo de cierre de 3400 ms con opacidad 0 → 0,9 → 0 y escala 0,7 → 1,08 (`table_fx.dart`). Cartas de regreso al mazo en 900 ms (`table_director.dart`, `table_view.dart`, `table_motion.dart`). «Interpretar» tiene objetivo de toque minimo de 48 dp en pantalla (`table_director.dart`). Tests en `table_circle_test.dart` y `table_director_test.dart`.
- `03d2f2a`: etiqueta y accion semantica para «Interpretar» y opciones/centro del radial; medicion de 48 dp en mazo, monton, sello, radial, deshacer y lista a 360 × 760 (`table_view.dart`, `table_director.dart` y tests de la mesa). Se verificaron nombre lunar y carta pendiente.

## Medido

- En el motor de tests, 4 capturas antes/despues de camara y zoom en `.qa-mesa/motor-*.png`; no representan fps ni tacto en un telefono.
- A 360 × 760, el abanico automatico de 78 deja 3,27 dp entre posiciones en zoom 1 y 8,49 dp en zoom 2,6, calculados con `TableCamera`. El bordado tenia unos 31 dp de alto proyectado; una prueba fallo al tocar a 23 dp de su centro y paso tras ampliar el objetivo a 48 dp.
- Antes del arreglo del ticker, `flutter test` dio 839 aprobadas, 7 saltadas y 34 fallidas con `Looking up a deactivated widget's ancestor is unsafe`. Despues, `flutter analyze` sin avisos y `flutter test` 877 aprobadas, 7 capturas manuales saltadas. Las pruebas del anillo verifican 3400 ms y «reducir movimiento»; las del vuelo, 760 ms y ausencia con «reducir movimiento».

## Estado actual

- Rama: `feat/mesa-tarot`, worktree `D:\Proyectos\Arcanum-mesa`. Ultimo commit de codigo: `03d2f2a`.
- Puertas Flutter: analisis sin avisos; 877 tests aprobados, 7 saltados. Backend sin cambios desde la fase 5; no se ejecutaron `pytest` ni migraciones en esta tanda.
- Sin push ni merge a `main`. La fase 8 sigue sin empezar.

## Pendiente en el GN2200

- Confirmar extraccion inmediata con red real, toques seguidos y arrastre con temblor; tiradas de 3 cartas y Cruz Celta completas.
- Comprobar camara, pellizco, giro, doble toque y estado restaurado; leer los fps por escena en profile. No se afirma 60 fps en movil.
- Probar lector de pantalla, lista de 78, objetivos superpuestos, sello, radial, Luna, «Interpretar» y carta pendiente a 360 dp y con zoom. Ver el ritmo del vuelo, el anillo, humo y retorno de cartas, incluido texto largo.
- Obtener grabaciones de sonido de Samuel. El brillo al inclinar el telefono queda para despues.

## Decisiones de Samuel

- Cerradas: 05-oct, sombras cuentan como brillos caros y «Silenciar» apaga vibracion; 04-oct, abanico visual con lista de 78 filas de 48 dp.
- Abierta: cuando recupera calidad la mesa. Provisional: 3 ventanas consecutivas de 2 s a 55 fps o mas; no se cambio.
- Abiertas del plan de fase 7: giro ±40° que recorta hasta 10 % del paño (mantener, alejar al girar o limitar giro); umbral de arrastre 6 px frente a 18 px de Flutter (mantener, pasar a 18 o medir en GN2200); abanico sobre sello y bordado (orden de capas actual o bajar linea y cambiar y = 782). Ninguna se cambio.
