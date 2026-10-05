---
tags: [arcanum, sigilos, letras]
tipo: avance
area: arcanum
actualizado: 2026-10-04
---

# Taller de Sigilos — Hoy, carga, olvido y Bitácora

Relacionado: [[Guia-Maestra-de-Sigilos]], [[Sigilos-Guia-de-Producto]], [[ARCANUM-Avance-Comparar-2026-10-04]], [[ARCANUM-Estado]].

## Qué se hizo

- [AR] `arcanum_app/lib/features/hoy/hoy_screen.dart`: puerta «Crear sigilo de letras». Tras guardar el sigilo o una anotación, lleva al Grimorio.
- [AR] `arcanum_app/lib/features/sigilos/taller_screen.dart`: después de «Olvidar» vacía documento, campo de intención e historial de deshacer; abre una anotación voluntaria. Si la persona había guardado una copia antes, la copia permanece y se avisa expresamente.
- [AR] `bitacora_sheet.dart` y `sigil_store.dart`: la observación libre se guarda como entrada `ritual` en el Grimorio, con `GrimoireCrypto.encryptText` y título neutro. No se copia automáticamente la intención ni el dibujo. El usuario puede cerrar sin anotar. Esta rama no tiene un módulo independiente llamado Bitácora; aquí es el registro de prácticas del diario cifrado.
- [AR] `taller_carga.dart`: los controles de 30/60/120 segundos y «Empezar» se ajustan al ancho de 390 px. Código: commit `acc1d5b`, sobre `95d4eba`.

## Procedencia y decisiones

- [OM] Austin Osman Spare, *The Book of Pleasure (Self-Love)* (1913), apartado «Sigils»: combina letras simplificadas y vincula la operación a la atención y al deseo. La secuencia exacta de botones, el temporizador y la nota cifrada son decisiones de ARCANUM, no instrucciones textuales de Spare. Véase el examen de fuente y variantes en [[Guia-Maestra-de-Sigilos]], secciones «Letras», «Carga» y «Olvido».
- [RC] El diario posterior a «Olvidar» documenta la experiencia sin exigir conservar la figura. Es una adaptación de producto, no un paso histórico universal.
- [AR] La respiración era una guía opcional en esta versión. El 5-oct se retiró el patrón 4-4-4-4 para dejar respirar al ritmo propio, sin retenciones: [[ARCANUM-Mejora-Taller-2026-10-05]]. El ritual no se aplica a Kamea, Rosa-Cruz, Sello personal o Comparar.
- [AR] No se borra una copia ya guardada mediante «Olvidar». Borrar una entrada persistida requiere la acción explícita del Grimorio.

## Verificación ejecutada (2026-10-04)

- `flutter test --no-pub test/features/sigilos/bitacora_flow_test.dart`: **1 pasa** en 390×844; recorre crear → cargar → olvidar → anotar. Comprueba que la figura se limpia, solo se crea una entrada `ritual`, el título no contiene la intención y el contenido se entrega al cifrador.
- `flutter test --no-pub test/features/hoy/hoy_screen_test.dart`: **3 pasan**, incluida la puerta al Taller en 390×844.
- `flutter test --no-pub`: **1601 pasan, 8 saltados**. `flutter analyze --no-pub`: **0 avisos**. Hook de commit `flutter analyze lib`: **0 avisos**.

## Defectos propios y límites

- El primer test del flujo descubrió un desborde de **92 px** en los controles de carga a 390×844; «Empezar» no recibía el toque. Se sustituyó la fila rígida por controles que envuelven. La prueba pasó después.
- El primer test de entrada desde Hoy usó la ventana predeterminada de 800×600 y el Taller desbordó 2 px en un control lateral; el test se ajustó a la ventana móvil exigida de 390×844. No se afirma que esa composición lateral funcione en 800×600.
- No verificado en teléfono real: 90 Hz, arrastre con dedo, lector de pantalla, aspecto de Crimson Pro/Noto Serif Hebrew, comportamiento de teclado y red reales. No hubo revisión legal de obra ajena ni publicación.
