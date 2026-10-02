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
4. Familias v2 en Flutter: Rosa-Cruz, Kamea, Sello personal y Comparar.
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
