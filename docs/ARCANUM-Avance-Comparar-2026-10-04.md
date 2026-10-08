---
tags: [arcanum, sigilos, comparar]
tipo: avance
area: arcanum
actualizado: 2026-10-04
---

# Taller de Sigilos — Comparar

Relacionado: [[Guia-Maestra-de-Sigilos]], [[Sigilos-Guia-de-Producto]], [[ARCANUM-Avance-Sello-Personal-2026-10-04]], [[ARCANUM-Estado]].

## Qué se hizo

- [AR] `arcanum_app/packages/arcanum_sigilos/lib/engine/compare.dart`: `CompareDoc` traza el mismo nombre con Letras (únicas, fusión), Rosa-Cruz y Kamea planetaria. Compone tres recuadros y notas en un SVG de 800×800. Conserva los motores independientes. Referencia: `arcanum-sigil-prototype/js/personal.js`, `compareGenerate`, `compareReady` y `compareSVG`; `js/app.js` conecta los controles. Código: commit `5120d0b`.
- [AR] `arcanum_app/lib/features/sigilos/compare_screen.dart`, `grimorio_editor.dart` y `grimorio_detail.dart`: puerta, pantalla, lámina, exportación y reapertura. `sigil_store.dart` guarda la marca `sigilo-comparar`; el nombre queda dentro de `GrimoireCrypto.encryptText`, fuera del título.
- [AR] Por decisión expresa de Samuel en esta sesión, el detalle del Grimorio oculta el rótulo superior con el nombre de Kamea y conserva su pie. El editor y la exportación de Kamea siguen mostrando su figura original. No se aplica ritual de caos a esta lámina.

## Procedencia

- [HP] Heinrich Cornelius Agrippa, *De occulta philosophia libri tres*, libro II, capítulo 22: cuadrados planetarios de órdenes 3–9, base del motor Kamea. [Edición inglesa de 1651, University of Michigan](https://quod.lib.umich.edu/e/eebo/A26565.0001.001/1%3A16.22?rgn=div2&view=fulltext). Agrippa no prescribe esta comparación en tres recuadros.
- [OM] S. L. MacGregor Mathers, *Sigils from the Rose* (manuscrito F de la Golden Dawn) y *The Rose Cross Lamen* (documento 5=6): base de las posiciones de letras hebreas de Rosa-Cruz. Localización y distinción doctrinal detalladas en [[Guia-Maestra-de-Sigilos]], sección «Rosa-Cruz».
- [OM] Austin Osman Spare, *The Book of Pleasure (Self-Love)* (1913), sección sobre sigilos y Alfabeto del Deseo: combinación y simplificación de letras. La variante concreta «únicas + fusión» es una parametrización del taller; no se presenta como receta textual exclusiva de Spare. Véase [[Guia-Maestra-de-Sigilos]], secciones «Letras» y bibliografía.
- [RC] Comparar el nombre latino con su transcripción hebrea automática en una sola lámina es un ejercicio contemporáneo. La transcripción admite revisión humana; no convierte los tres artefactos en uno solo.
- [AR] El planeta de Kamea se elige o procede del regente del día. El nombre «Samuel» produce SAMUEL en Letras y שמואל en Rosa-Cruz y Kamea con Saturno en el caso de referencia.

## Verificación ejecutada (2026-10-04)

- `node _fixtures_compare.mjs` con Chrome local: **19 casos JSON y 10 PNG** sin texto ni pergamino. El primer intento en sandbox devolvió `spawn EPERM`; la ejecución autorizada fuera del sandbox terminó con código 0.
- `flutter test --no-pub test/features/sigilos/compare_parity_test.dart test/features/sigilos/compare_painter_test.dart`: **32 pasan**. SVG etiqueta por etiqueta; caminos, escala, grosor y opacidad del lienzo; imágenes con diferencia <0,06 %.
- `flutter test --no-pub test/features/sigilos/compare_screen_test.dart`: **4 pasan**. Pantalla 390×844, cifrado y título neutro, reapertura, rótulo de Kamea oculto solo en detalle.
- `flutter test --no-pub`: **1599 pasan, 8 saltados**. `flutter analyze --no-pub`: **0 avisos**. Hook de `git commit`: `flutter analyze lib`, **0 avisos**.
- Mutaciones intencionadas y revertidas: escala de celda `262→260` falló en SVG; ancho visual `4→5` falló en escena; regente automático desplazado un día falló en el caso Samuel/Sol.

## Defectos propios y límites

- Un test de pantalla tocó primero el título «Comparar» por ambigüedad con el botón. Se corrigió el selector al botón; el producto no cambió.
- No verificado en teléfono real: 90 Hz, dedo, lector de pantalla, Crimson Pro y Noto Serif Hebrew. Tampoco se revisaron legalmente sellos de obra ajena ni se publicó.
- Pendiente: enlazar crear → cargar → olvidar → anotar solo para Letras con Hoy, Grimorio y Bitácora.
