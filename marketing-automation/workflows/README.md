# Workflows n8n

Los exports se guardan aqui despues de validarlos en la version fijada de n8n.

Orden previsto:

1. `01_seleccionar_semilla.json`
2. `02_generar_borrador.json` - importado; requiere credencial Gemini en UI
3. `03_validar_contenido.json`
4. `04_aprobar_contenido.json`
5. `05_renderizar.json`
6. `06_publicar.json`
7. `07_medir.json`

Ningun workflow publica sin estado `approved`. La credencial Gemini vive solo
en el almacen cifrado de n8n y nunca dentro del JSON exportado.
