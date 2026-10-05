---
tags: [arcanum, sigilos, mejora]
tipo: avance
area: arcanum
actualizado: 2026-10-05
---

# Taller de Sigilos — carga libre, paridad visual y guardado seguro

Relacionado: [[Guia-Maestra-de-Sigilos]], [[ARCANUM-Avance-Ritual-Bitacora-2026-10-04]], [[ARCANUM-Avance-Comparar-2026-10-04]], [[ARCANUM-Estado]]. Código: `aef5cd6` en `claude/ecstatic-turing-tki667`.

## Qué se hizo

- [AR] `arcanum_app/lib/features/sigilos/taller_carga.dart` y `taller_panels.dart`: la carga de Letras propone respirar al ritmo propio, sin retener el aire. Eliminó fases obligatorias 4-4-4-4 y «SOSTÉN»; permite cerrar libremente. No se aplica a las familias históricas.
- [AR] `arcanum_app/packages/arcanum_sigilos/lib/engine/layers.dart`, `scene.dart`, `ui/scene_painter.dart` y `engine/compare.dart`: las notas de Comparar respetan la alineación izquierda de su SVG. El lienzo anterior las centraba aunque el SVG era correcto.
- [AR] `compare_screen.dart` y `personal_screen.dart`: editar el nombre después de trazar invalida guardar y exportar hasta reconstruir la figura. En sus guardados, y en los de `taller_screen.dart`, `kamea_screen.dart` y `rosa_screen.dart`, se compara la instantánea enviada con el estado posterior a la respuesta asíncrona; una edición durante el envío conserva el aviso de cambios pendientes.
- [AR] Pruebas de paridad, lienzo, pantallas y flujo de Bitácora cubren esos casos. `taller_screen_test.dart` desplaza la lista antes de tocar «Guardar en el Grimorio» a 390×844.

## Fuentes y decisiones

- [OM] Austin Osman Spare, *The Book of Pleasure (Self-Love)* (1913), apartado «Sigils»: antecedente moderno de la composición de letras y el olvido. Véase el examen de la fuente en [[Guia-Maestra-de-Sigilos]], secciones «Letras», «Carga» y «Olvido». El patrón respiratorio 4-4-4-4 no se atribuye a Spare.
- [RC] Comparar yuxtapone Letras, Rosa-Cruz y Kamea como reconstrucción visual de ARCANUM; no afirma una técnica histórica que mezcle familias. Procedencias de cada una en [[ARCANUM-Avance-Comparar-2026-10-04]].
- [AR] Respiración natural opcional, alineación del texto y bloqueo de guardado obsoleto son decisiones de interfaz e integridad de datos, no doctrina histórica.

## Verificación ejecutada (2026-10-05)

- `flutter test --no-pub` en `arcanum_app`: **1606 pasan, 8 saltadas**; salida final `All tests passed!`.
- Pruebas dirigidas de Comparar, Sello personal, Taller y Bitácora: **46 pasan** tras corregir el test de desplazamiento.
- `flutter analyze --no-pub`: **0 problemas**. Hook del commit, `flutter analyze lib`: **0 problemas**.
- `flutter build apk --debug --no-pub`: primer intento falló al resolver `com.android.application:9.0.1` en los repositorios Gradle; repetido con acceso de red, **exit 0**, APK generado en `arcanum_app/build/app/outputs/flutter-apk/app-debug.apk` (632,7 s). Esto verifica compilación Android, no uso en teléfono.
- `adb devices -l`: ningún dispositivo conectado. `flutter devices`: Windows, Chrome y Edge; ningún móvil. `flutter emulators`: ninguno disponible. `flutter doctor -v` quedó sin salida y se interrumpió; no se toma como verificación superada.

## Defectos propios y límites

- Una edición intermedia introdujo una variable de instantánea fuera de alcance en la carga; la compilación de pruebas la detectó y se corrigió antes de la suite completa.
- El test de guardado de Letras tocaba un botón 6 px fuera de la ventana de 390×844; se desplazó la lista y pasó.
- La compilación advirtió que el uso de Kotlin Gradle Plugin por la app y `purchases_flutter` fallará en versiones futuras de Flutter; requiere migración antes de actualizar Flutter.
- Falta QA en teléfono físico: 90 Hz, arrastre con dedo, lector de pantalla, teclado y red reales, y aspecto con Crimson Pro y Noto Serif Hebrew.
