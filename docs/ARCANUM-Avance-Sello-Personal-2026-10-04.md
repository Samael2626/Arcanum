---
tags: [arcanum, sigilos, personal]
tipo: avance
area: arcanum
actualizado: 2026-10-04
---

# Taller de Sigilos — Sello personal

Relacionado: [[Guia-Maestra-de-Sigilos]], [[Sigilos-Guia-de-Producto]], [[Sigilos-Taller-v3]], [[Taller-Sigilos-Decisiones]], [[ARCANUM-Estado]].

## Qué se hizo

- [AR] `arcanum_app/packages/arcanum_sigilos/lib/engine/personal.dart`: `PersonalDoc` compone una figura de letras, Rosa-Cruz o Kamea con un formato visual. Kamea impone el planeta de su propia tabla. La geometría se mide sin grosor de tinta para encajar la figura, como `getBBox` del prototipo. `svg_bounds.dart` calcula los extremos de líneas, curvas y arcos.
- [AR] `arcanum_app/lib/features/sigilos/personal_screen.dart`: crear, cambiar fuente, planeta, formato y capas; compartir PNG/SVG; guardar. `grimorio_editor.dart` abre la pantalla y `grimorio_detail.dart` restaura el sello para editarlo.
- [AR] `sigil_store.dart`: marca `sigilo-personal` y guardado con `GrimoireCrypto.encryptText`; el título no contiene el nombre. El documento conserva las decisiones y las tres fuentes dentro del contenido cifrado.
- [AR] Prototipo contrastado mediante `arcanum-sigil-prototype/_fixtures_personal.mjs`, 33 casos JSON y 11 PNG de Chromium. Implementación: commit `b809b24`, sobre `72dc379`.

## Procedencia: qué es histórico y qué se reconstruyó

- [HP] Heinrich Cornelius Agrippa, *De occulta philosophia libri tres*, libro II, capítulo 22, tablas y caracteres de los siete planetas. La edición inglesa de 1651 se consulta en las láminas de las páginas 244–252. **No** prescribe este generador de sellos personales. Fuente: <https://esotericarchives.com/agrippa/agripp2b.htm>.
- [HP] *Lemegeton*, *Ars Goetia*, edición de S. L. MacGregor Mathers y Aleister Crowley (1904), láminas de sellos; lista clasificada, p. 48: correspondencia de siete planetas y metales. El taller usa esa tabla para rotular el metal, sin reproducir un sello de espíritu. Fuente: <https://sacred-texts.com/grim/lks/lks07.htm>.
- [HP] *The Key of Solomon*, edición de S. L. MacGregor Mathers (1889), libro I, capítulo 18, «Concerning the Holy Pentacles or Medals», y figuras planetarias posteriores, por ejemplo el tercer pentáculo de Saturno (figura 13). Son modelos de repertorio, no reglas para construir un sello nuevo con cualquier nombre. Fuente: <https://www.esotericarchives.com/solomon/ksol.htm>.
- [OM] S. L. MacGregor Mathers, manuscrito F de la Golden Dawn, *Sigils from the Rose*, y documento 5=6, *The Rose Cross Lamen*: origen de la figura Rosa-Cruz que el motor ya produce. Véase la procedencia completa en [[Guia-Maestra-de-Sigilos]] y `docs/ARCANUM-Informe-Taller-Sigilos-2026-10-02.md`, §8.
- [RC] Tomar una de las tres figuras y enmarcarla con anillo latino, anillo hebreo o rótulo es **composición contemporánea de ARCANUM**. «Goetia», «Pentáculo» y «Agrippa» son nombres de plantillas visuales. El resultado no es una pieza histórica ni adopta la función ritual de esas obras. La descripción del SVG lo declara.
- [AR] El planeta por defecto es el regente del día de creación; el usuario puede cambiarlo salvo cuando la fuente es Kamea. El acabado «metal» simula una placa; no afirma material físico ni eficacia.

## Verificación ejecutada (2026-10-04, rama `claude/ecstatic-turing-tki667`)

- `node _fixtures_personal.mjs` con Chrome local: **33 casos, 11 imágenes**. El primer intento en sandbox devolvió `spawn EPERM`; fuera del sandbox terminó con código 0.
- `flutter test test/features/sigilos/personal_parity_test.dart test/features/sigilos/personal_painter_test.dart test/features/sigilos/personal_screen_test.dart --no-pub`: **52 pasan**. Paridad SVG etiqueta por etiqueta, imagen bajo 0,06 %, trazos/anchos/opacidades del lienzo, pantalla a 390×844, título neutro y reapertura desde Grimorio. Tras un ajuste adicional para Kamea con cuadrícula visible, su prueba específica pasó.
- `flutter test --no-pub`: **1562 pasan, 8 saltados**. `flutter analyze --no-pub`: **0 avisos**. El hook de `git commit` ejecutó `flutter analyze lib`: **0 avisos**. La suite completa se corrió antes del ajuste de cuadrícula; la prueba específica y el análisis se repitieron después.
- Mutaciones revertidas: escala `2 → 2,1` falló en la transformación SVG; ancho `7 → 7,5` falló en la prueba estructural; regente domingo `Sol → Luna` falló en la prueba de planeta automático. No sobrevivió ninguna de las tres.

## Defectos propios y límites

- `Path.getBounds` de Flutter contaba controles de curvas y desplazaba el encaje frente a Chromium. Se sustituyó por el cálculo de extremos geométricos de caminos SVG; los 33 casos pasaron.
- El primer cotejo de PNG incluía un fondo que el fixture excluye por diseño. Se corrigió el montaje de la prueba; el producto conserva su fondo.
- La escena de una Kamea guardada con cuadrícula visible podía usar las coordenadas de la tabla mientras el SVG exportaba la figura ajustada. Se fuerza `grid=false` solo durante el montaje y se restaura el valor; prueba específica verde.
- No verificado en teléfono real: 90 Hz, arrastre táctil, lector de pantalla ni Crimson Pro/Noto Serif Hebrew. Tampoco se hizo revisión legal de obra ajena ni se publicó.

## Pendiente

- [AR] Portar «Comparar»; después enlazar Hoy → Grimorio → Bitácora para el sigilo de letras. No trasladar carga y olvido a Rosa-Cruz ni Kamea.
- Decisión de Samuel: el detalle de Kamea muestra el nombre trazado como rótulo; Rosa-Cruz no. Falta decidir si se oculta el rótulo de Kamea.
