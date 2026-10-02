# Spec: Catálogo histórico de sellos en Saber

Estado: SPEC, nada implementado en Flutter. Escrita el 2-oct-2026 sin Flutter a
mano: las firmas de Dart de abajo no se han compilado.

## Qué es y dónde va

Consulta de 103 sellos históricos (23 de Agrippa 1651, 80 de la Goetia 1916), obra
ajena de dominio público reproducida de escaneos. No es contenido de usuario ni
correspondencia de Materia, así que NO va a Postgres ni a `/materia`.

Va en **Saber** como tercera cara del toggle: `Plantas | Biblioteca | Sellos`
(`lib/features/saber/saber_screen.dart`, `ArcanumToggleOption(label: 'Sellos')`,
tercer hijo del `IndexedStack`). Sigue la razón del propio Saber: es conocimiento
de la tradición, y el taller puede enlazar a cada pieza.

## Datos

- Fuente: `arcanum-sigil-prototype/export/catalogo-sellos.json` (formato en
  `export/README.md`). Se regenera con `node _export_catalogo.mjs` y se valida con
  `node _verify_export.mjs`.
- Asset: copiarlo a `arcanum_app/assets/sellos/catalogo-sellos.json` y declararlo
  en `pubspec.yaml`. Es copia generada: el script de export debe aceptar un
  destino para no copiar a mano. ~2,9 MB (~1,1 MB comprimido).
- Cargar una vez (`rootBundle.loadString`) y parsear en un `Isolate`/`compute`:
  son 2,9 MB de JSON y no deben bloquear el primer fotograma de la pestaña.

## Modelo (lib/features/saber/sellos/)

```dart
class SelloFuente { String id, name, short, work, edition, scan, license, item; }
class SelloPieza {
  String id, source, title; String? name, planet, planetName, kind, role, note;
  List<String> ranks, metals, alt; int? spirit, fig; bool second;
  int page, leaf; String scanUrl; double w, h;
  List<(String d, double tx, double ty)> paths;
}
class CatalogoSellos { Map<String, SelloFuente> sources; List<String> goetiaRanks; List<SelloPieza> items; }
```

## Pintado

Reutilizar `pathOf(d)` de `arcanum_sigilos` (`ui/scene_painter.dart`; ya parsea
`d` de SVG con `path_drawing`, con caché de 4000 entradas). Un `CustomPainter`
por pieza: `translate(tx, ty)` y relleno con el color de tinta, escalado a la caja
`w × h`, igual que `sealSVG` del prototipo. Rejilla: 80 miniaturas de la Goetia
exigen `RepaintBoundary` por celda y `ListView/GridView.builder` perezoso. No
rasterizar a imagen salvo que las medidas lo pidan.

## Pantalla

- Filtros: Agrippa por planeta (7), Goetia por rango (7, `goetiaRanks`).
- Ficha de pieza (hoja inferior): dibujo grande y, SIEMPRE visibles, obra,
  edición, escaneo y licencia de `sources[source]`, más página/figura y enlace al
  escaneo (`scanUrl`). Goetia: nombre, rango y metal del sello; si tiene doble,
  enlace a su pareja. Agrippa: planeta y tipo (sello, inteligencia, espíritu).
- La atribución no es opcional: la licencia exige citar y la tienda puede
  comparar. Sin atribución, la pieza no se muestra.
- Abrir el escaneo requiere `url_launcher`, que hoy NO está en `pubspec.yaml`.
  Decidir: añadir la dependencia o mostrar el enlace como texto copiable.
- Accesibilidad: cada celda con `Semantics` (título y rango/planeta); el dibujo
  `excludeSemantics`. Tocables ≥ 48 px. Estados con color + peso, como
  `ArcanumToggle`.
- Texto en español, sin jerga de proveniencia: «Calco del escaneo», no «HP/OM».

## Tests a escribir (en la máquina con Flutter)

1. Contrato del JSON: 103 piezas, 23 + 80, 72 espíritus, 8 dobles, toda pieza con
   fuente y licencia (los mismos invariantes de `_verify_export.mjs`).
2. Parseo: el modelo reproduce cada campo y `paths` del JSON.
3. Pintado: `pathOf` no lanza con ninguna de las 103 piezas y cada bounds cae
   dentro de la caja `w × h` (margen pequeño).
4. Widget: el toggle muestra tres caras y `IndexedStack` conserva el scroll;
   la ficha muestra licencia y edición de la pieza elegida.
5. Rendimiento: perfilar la rejilla de la Goetia en el GN2200 real (60 Hz).

## Fuera de alcance

- Enlace desde el taller («abrir en Sellos» desde una pieza) y Bitácora.
- Búsqueda por nombre de espíritu (la lista es corta; filtros bastan en v1).
- Marcar favoritos: sería dato de usuario, otra decisión.

## Riesgos

- Es obra ajena: mantener la atribución en el JSON y en la pantalla; revisar con
  `arcanum-legal` antes de publicar.
- 2,9 MB más en el APK (~1,1 MB comprimido): aceptable, pero medirlo.
- Los trazos son calcos de escaneo con tinta separada del papel; 5 de las 103 piezas
  llevan nota de limpieza o de procedencia en `note`. Mostrarla en la ficha.
