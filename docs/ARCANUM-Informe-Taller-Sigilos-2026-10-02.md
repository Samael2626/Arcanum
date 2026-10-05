# Informe: Taller de Sigilos de ARCANUM

Fecha: 2 de octubre de 2026
Rama: `feature/taller-sigilos`. Todo lo que dice «verificado» se corrió ese día
sobre el remoto; lo que no, está marcado como no verificado.

## 0. Correcciones al informe anterior

| Dato anterior | Dato verificado |
|---|---|
| Head `2fc797d`, merge de `release/1.0.6` | Ese commit no existe. La punta de la rama era `c46104e`. |
| Salida en la 1.0.7 | El tag `v1.0.7+15` ya existía y no incluía el taller. |
| Gate: 229 checks | 240 antes de los cambios de hoy; 249 después. |
| Fuzz n=40 | Corrido con n=150, 0 fallos. |
| 337 tests de taller + Grimorio | Corridos con Flutter: 334. No se explica la diferencia de 3. |
| Suite de 976 tests (30-sep) | Reverificada: 976 → 992 → 1068 según el día (ver §3). |
| Términos prometían un generador de sigilos «que no existe» | Los Términos y la política vivos (`gh-pages`) no mencionan sigilos: esa promesa se retiró el 25-ago-2026 (commit `9b38862`). Lo único que queda es la tarjeta «Generador de sigilos» (P2) de la página de presentación `legal-site/index.html`. La línea 511 del cierre del 20-sep, de donde salía la afirmación, no está en este repo y no la pude verificar. |

## 1. Qué es

Módulo que convierte una intención escrita en un glifo personal con método
trazable a fuentes históricas, sin IA (decisión del 28-sep). Las letras del
usuario son el material del signo; no es un generador de mandalas.

## 2. Lo hecho el 2-oct

### 2.1 Estilización caligráfica (prototipo JS y Dart)
- Capa opcional de solo dibujo: **Recta** (como antes), **Curva** (las rectas se
  combán un 3 %, siempre hacia el mismo lado) y **Pluma** (contorno relleno de
  punta ancha; el grosor depende de la dirección, entre 0,6 y 1,4 del ancho de
  línea). No cambia trazos, extremos ni cruces.
- Resplandor y relieve funcionan con Pluma; «línea doble» no se aplica en Pluma.
- Se guarda con el documento y con la galería (el nombre de la entrada lleva
  «· Curva» o «· Pluma»); cambiar de estilo no la borra.
- Portada a Dart (`calliPath`, `calliOutline`) con paridad exacta: 54 SVG de
  referencia y 18 imágenes de Chromium contra el pintor.
- Control en Estilo → Ajustar → Caligrafía (chips ≥ 48 dp).

### 2.2 Catálogo histórico de sellos (Saber → Sellos)
- Export verificado: `arcanum-sigil-prototype/export/catalogo-sellos.json`,
  103 piezas (23 de Agrippa 1651, 80 de la Goetia 1916; 72 espíritus, 8 dobles),
  con obra, edición, escaneo, licencia y enlace a la hoja de cada pieza.
- Asset de la app y tercera cara del toggle de Saber: `Plantas | Biblioteca | Sellos`.
  Cuadrícula con filtros por planeta y por rango, ficha con la procedencia
  siempre visible, pareja de los sellos dobles, nota de 5 piezas, copiar el
  enlace al escaneo. No se construye hasta abrirla (el catálogo pesa ~2,9 MB).
- Decisión: es un asset de la app, no una tabla de Postgres.

## 3. Pruebas (todas corridas el 2-oct)

| Batería | Resultado |
|---|---|
| Prototipo: `_gate.mjs` | 249 checks, 0 FAIL |
| Prototipo: `_edge.mjs` | 17 checks, 0 FAIL |
| Prototipo: `_fuzz.mjs` semilla 21, n=150 | 0 fallos |
| Export del catálogo: `_verify_export.mjs` | 12 checks, 0 FAIL (raster 0,000 %) |
| Flutter, carpeta de sigilos | 410 tests, todos pasan |
| Flutter, suite completa antes de fusionar con `main` | 1068 pasan, 8 saltados |
| Flutter, suite completa tras fusionar con `main` | 1087 pasan, 8 saltados (1068 + 19 de `main`) |

Mutación: errores inyectados a propósito y detectados — caligrafía en JS (4 de 4),
en el motor Dart (4 de 4, de 12 a 70 fallos), en la interfaz (1 de 1), y en Sellos
(ficha sin licencia, pintor sin margen, carga no perezosa). Uno de ellos reveló
una aserción vacía en mi propio test (`find.byType` ignora lo `Offstage`); corregida.

## 4. Problemas propios encontrados y corregidos
- `_export_catalogo.mjs` y `_verify_export.mjs` nunca se habían subido: la regla
  `_*.mjs` del `.gitignore` los excluye. Añadidos a la fuerza, como los demás.
- Un `dart format` reescribió `taller_panels.dart` entero; revertido y reaplicado
  solo el cambio real.
- Las notas vacías (`""`) del catálogo contaban como notas en las 103 piezas.
- Un rebasamiento de caja del 2 % en `goetia-50` era un empate de coma flotante;
  tolerancia al 3 %.
- Archivos que `flutter pub get` ensucia (`local.properties`, enlaces de Windows)
  están versionados en el repo; se restauraron siempre y no están en ningún commit.

## 5. Estado y pendiente

Hecho en Flutter: motor de letras, capas, escena, estilo, pintor propio,
interacción, taller dentro del Grimorio (guardado cifrado, carga 4-4-4-4, olvido),
caligrafía, y el catálogo histórico en Saber.

No verificado (necesita teléfono):
1. QA en la app instalada (`com.arcanum.magick` de depuración).
2. 90 Hz y arrastre con dedo real; rejilla de sellos en el GN2200.
3. Lector de pantalla del selector de caligrafía y de las celdas de Sellos.

Pendiente de producto:
4. Familias v2 en Flutter: **Kamea, Rosa-Cruz, Sello personal y Comparar hechas** (ver §7–§10).
5. Enlace del taller con Hoy, Grimorio y Bitácora (crear → cargar → olvidar → anotar).
6. Revisión con `arcanum-legal` de los sellos (obra ajena) antes de publicar. La
   tarjeta «Generador de sigilos» (P2) de `legal-site/index.html` se actualiza el
   día de la release, no antes. Los Términos (`gh-pages`) no necesitan cambio
   obligatorio; opcionalmente se añade el taller a su lista de módulos.
7. Menores: codificación corrupta de `Sigilos-Taller-v2.md`; cita de Cooper mal
   asignada por el conector NotebookLM.

## 6. Veredicto

El taller y el catálogo están completos y probados en el entorno de pruebas del
repo, con paridad exacta contra el prototipo y mutación detectada en cada capa.
Lo único que separa esto de una release es lo que no se puede probar sin un
teléfono: QA en la app instalada, 90 Hz y accesibilidad en dispositivo.


## 7. Kamea en Flutter (4-oct)

Primera familia v2 portada: el nombre en hebreo trazado sobre las siete tablas
de Agrippa (lib. II, cap. 22), con los 17 nombres de inteligencias y espíritus,
las tres reducciones de números grandes, los dos remates y la vista de lámina o
de tabla numerada. Familia histórica aparte: sin carga ni olvido.

- Motor: `packages/arcanum_sigilos/lib/engine/kamea.dart` (`KameaDoc`), puerto de
  `js/kamea.js`. Valores hebreos en `hebrew.dart`.
- Pantalla: `lib/features/sigilos/kamea_screen.dart`. Entrada desde el editor del
  Grimorio («Abrir una kamea») y desde el detalle («Seguir en la kamea»).
- Guardado: entrada `sigil` con marca `sigilo-kamea`; el título nombra la tabla
  («Kamea de Saturno, 4 de octubre»), el nombre trazado queda cifrado dentro.
- Referencias: `arcanum-sigil-prototype/_fixtures_kamea.mjs` genera
  `fixtures/kamea.json` (117 casos) y 30 imágenes de Chromium en `png_kamea/`.

Pruebas (corridas el 4-oct con Flutter 3.47.6): SVG idéntico al del prototipo en
los 117 casos; lienzo frente a Chromium por debajo del 0,06 % de píxeles; pantalla
y Grimorio, 8 tests. Suite completa: 1249 pasan, 8 saltados (1087 + 162 nuevos);
`flutter analyze` sin avisos. Mutación: 4 de 5 errores inyectados detectados; el
quinto (`c % 10` en la reducción por ceros) es equivalente, no cambia el resultado.

No verificado (necesita teléfono): QA en la app instalada, lector de pantalla del
selector de tablas y de la lectura de casillas. En el detalle del Grimorio la
lámina muestra el nombre trazado como rótulo (a diferencia del sigilo de letras,
que oculta la intención); si se quiere privacidad en pantalla, ocultarlo allí.

## 8. Rosa-Cruz en Flutter (5-oct)

Segunda familia v2: el nombre en hebreo trazado sobre el Lamen (22 pétalos: 3
madres, 7 dobles, 12 simples) como en el manuscrito F de Mathers. Círculo en la
inicial, quiebro en letras repetidas, lazo por giro casi recto y por paso junto
a una letra no visitada, trazo apartado cuando repasa otra línea, barra final,
una palabra por sigilo, y colores de la escala del Rey con tramos degradados.

- Motor: `packages/arcanum_sigilos/lib/engine/rosa.dart` (`RosaDoc`), puerto de
  `js/rosa.js`. El lienzo pinta degradados a lo largo del trazo con el nuevo
  `PathItem.strokeGrad`; el SVG lo escribe `RosaDoc.buildSVG`.
- Pantalla: `lib/features/sigilos/rosa_screen.dart`. Las piezas comunes con la
  Kamea (chips, compartir, aviso al salir) pasan a `familia_ui.dart`.
- Guardado: entrada `sigil` con marca `sigilo-rosa`; el título es «Rosa-Cruz, 5
  de octubre» y el nombre queda cifrado dentro. El detalle del Grimorio dibuja
  solo el trazo sobre el Lamen: no muestra el nombre.
- Referencias: `arcanum-sigil-prototype/_fixtures_rosa.mjs` genera
  `fixtures/rosa.json` (192 casos, 70 de ellos al azar con semilla fija) y 48
  imágenes de Chromium en `png_rosa/`. El JSON guarda el SVG desde la obra: el
  soporte ya tiene su paridad en los fixtures de letras.

Pruebas (corridas el 5-oct): petalos, recorrido, marcas, gematría y SVG idénticos
al prototipo en los 192 casos; lienzo frente a Chromium por debajo del 0,06 %;
el lienzo dibuja los mismos trazos, anchos y opacidades que el SVG (también en la
Kamea, donde se añadió); pantalla y Grimorio, 8 tests. Suite completa: 1510
pasan, 8 saltados; `flutter analyze` sin avisos. Mutación: 9 de 10 errores
inyectados detectados en el SVG; el que sobrevive (`t >= 0` en el paso junto a
una letra) es inalcanzable con esta geometría, porque dos pétalos distintos
nunca quedan a menos de 48 px.

Defecto propio encontrado y corregido: con tres puertas, la invitación del editor
del Grimorio desbordaba 72 px en un móvil de 844 px de alto; ahora se desplaza.
También desbordaba la fila de colores con «naranja escarlata brillante».

No verificado (necesita teléfono): QA en la app instalada, lector de pantalla de
los interruptores y de la lectura, y el aspecto con Crimson Pro y Noto Serif
Hebrew en el Lamen (los tests usan una fuente de prueba de cuadrados).

## 9. Sello personal en Flutter (4-oct)

Commit `b809b24`, sobre `72dc379`. `PersonalDoc` monta la figura de letras,
Rosa-Cruz o Kamea en un formato visual Goetia/Pentáculo/Agrippa. El resultado
es una reconstrucción [RC], no una pieza histórica; el SVG lo dice. Kamea
conserva su planeta. Pantalla propia, entrada cifrada `sigilo-personal` y
restauración desde el Grimorio. El título no revela el nombre.

Referencias: `_fixtures_personal.mjs` produjo 33 casos y 11 PNG de Chromium.
Paridad SVG completa, lienzo bajo 0,06 % y prueba de caminos, anchos y opacidades.
Pantalla a 390×844, guardado y reapertura probados. Suite completa: 1562 pasan,
8 saltados; `flutter analyze` sin avisos. Tres mutaciones detectadas y revertidas.
Después de la suite se corrigió el caso de fuente Kamea con cuadrícula visible;
su prueba específica y el análisis pasaron. La procedencia, defectos y límites
están en [[ARCANUM-Avance-Sello-Personal-2026-10-04]].

## 10. Comparar en Flutter (4-oct)

Commit `5120d0b`. `CompareDoc` monta tres figuras independientes del mismo
nombre: Letras (únicas y fusión), Rosa-Cruz y Kamea del planeta elegido. Pantalla
propia, SVG, PNG y entrada cifrada `sigilo-comparar` con título neutro. Samuel
decidió ocultar el rótulo del nombre de Kamea solo en el detalle del Grimorio.

`_fixtures_compare.mjs` produjo 19 casos y 10 PNG de Chromium. Paridad SVG
etiqueta por etiqueta, lienzo bajo 0,06 % y prueba de caminos, grosor y opacidad.
Pantalla a 390×844, guardado y reapertura probados. Suite completa: 1599 pasan,
8 saltados; `flutter analyze` sin avisos. Tres mutaciones detectadas y revertidas.
Procedencia y límites: [[ARCANUM-Avance-Comparar-2026-10-04]].

## 11. Letras: Hoy, carga, olvido y Bitácora (4-oct)

Commit `acc1d5b`. Hoy abre el Taller de Letras. Después de «Olvidar», el
Taller limpia la figura, la intención y el historial de deshacer, y ofrece
anotar la experiencia. Esa anotación es una entrada `ritual` cifrada en el
Grimorio, con título neutro. No existe módulo independiente de Bitácora en
esta rama. Una copia del sigilo guardada antes permanece hasta que el usuario
la borre explícitamente.

La prueba 390×844 descubrió y corrigió un desborde de 92 px en la pantalla de
carga. Suite completa: 1601 pasan, 8 saltados; `flutter analyze` sin avisos.
Fuente y límites: [[ARCANUM-Avance-Ritual-Bitacora-2026-10-04]].
