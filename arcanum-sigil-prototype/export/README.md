# Catalogo historico de sellos para la app

`catalogo-sellos.json` se genera con `node _export_catalogo.mjs` desde
`sellos/sellos.js` y la fuente Agrippa de `js/catalogo.js`. No se edita a mano.

El paquete contiene 23 piezas de Agrippa (Londres, 1651, libro II, cap. 22).
Las figuras de la Goetia quedan excluidas porque su situacion en Colombia
permanece NO COMPROBADA. Los archivos graficos y vectoriales tambien se
retiraron del arbol actual del repositorio publico. El historial de Git
anterior conserva esos archivos y exige una gestion separada.

`node _verify_export.mjs` comprueba contenido, procedencia y trazos, incluida
una comparacion raster con el original.
