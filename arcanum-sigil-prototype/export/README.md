# Catálogo histórico de sellos (export para la app)

`catalogo-sellos.json` lo genera `node _export_catalogo.mjs` a partir de
`sellos/sellos.js`, `sellos/goetia/goetia.js` y `SEAL_SOURCES` de `js/catalogo.js`.
No se edita a mano. `node _verify_export.mjs` lo comprueba (12 checks, incluida
una comparación raster pieza a pieza contra el original).

- 103 piezas: 23 de Agrippa (Londres, 1651, libro II cap. 22) y 80 de la Goetia
  (72 espíritus, 8 con sello doble; Mathers-Crowley 1904, reimpr. 1916).
- `sources`: obra, edición, escaneo y licencia de cada colección. La app debe
  mostrarlos junto a cada pieza: es obra ajena reproducida.
- Cada pieza trae `paths: [[d, tx, ty], ...]` en coordenadas del escaneo (`w` × `h`):
  se pinta con `translate(tx, ty)` y relleno, igual que `sealSVG` del prototipo.
- Números a 1 decimal (diferencia raster medida: 0,000 % sobre las 103 piezas).
- Tamaño: ~2,9 MB, ~1,1 MB comprimido.

Pendiente (no hecho): cargarlo como asset de Flutter y la pantalla que lo muestre.
