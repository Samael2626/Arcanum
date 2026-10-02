# Workflows n8n

Los exports se guardan aqui despues de validarlos en la version fijada de n8n.

Orden previsto:

1. `01_seleccionar_semilla.json`
2. `02_generar_borrador.json` - importado; genera, parsea y valida el borrador

El flujo usa `gemini-3.6-flash` como editor y `gemini-3.5-flash-lite` como
respaldo cuando Google devuelve `503`. El resultado queda en
`ready_for_review` o `needs_revision`; nunca se aprueba ni publica solo.
La salida pasa primero por JSON Schema. Si llega truncada o invalida, n8n
regenera la pieza completa un maximo de dos veces; no completa huecos con otro
modelo porque eso puede inventar hechos, fuentes o recursos visuales.
3. `03_validar_contenido.json`
4. `04_aprobar_contenido.json`
5. `05_renderizar.json`
6. `06_publicar.json`
7. `07_medir.json`

Ningun workflow publica sin estado `approved`. La credencial Gemini vive solo
en el almacen cifrado de n8n y nunca dentro del JSON exportado.
