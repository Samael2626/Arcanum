---
name: arcanum-translator
description: Traduce, revisa y audita textos históricos EN-ES de ARCANUM, especialmente The Complete Herbal de Nicholas Culpeper. Activar al traducir capítulos o párrafos, comparar original y traducción, mantener el glosario histórico, detectar errores médicos o botánicos, ejecutar benchmarks MQM, elegir modelos de traducción, recuperar traducciones o preparar su carga en PostgreSQL.
---

# ARCANUM Translator

Aplicar un pipeline verificable. Priorizar significado sobre estilo. Tratar toda traducción automática como no revisada hasta superar controles.

## Cargar contexto

1. Leer `references/translation-policy.md` siempre.
2. Leer `references/prompts.md` al traducir, criticar o modificar prompts.
3. Leer `references/culpeper-glossary.json` al tocar Culpeper o terminología histórica.
4. Leer `references/mqm-rubric.md` al comparar modelos, auditar calidad o aprobar publicación.
5. Inspeccionar los scripts y datos reales antes de afirmar cómo funciona el pipeline:
   - `arcanum-api/scripts/translate_library.py`
   - `arcanum-api/scripts/recheck_translation.py`
   - `arcanum-api/scripts/recover_translation.py`
   - `arcanum-api/scripts/seed_library.py`
   - `arcanum-api/scripts/library_data/`

No asumir que la política descrita aquí ya está implementada en Python. Verificar código y tests.

## Flujo obligatorio

1. Congelar original, versión de prompt, versión de glosario, modelo y parámetros.
2. Detectar riesgo médico, botánico, obstétrico, posológico, astrológico y doctrinal.
3. Extraer nombres y términos protegidos desde el original.
4. Cortar por bloque semántico: 8-20 párrafos o hasta 6.000 tokens estimados. No cortar por cantidad ciega.
5. Traducir con `qwen/qwen3.6-27b` como candidato primario.
   - Exigir IDs exactos y textos no vacíos en el contrato de salida.
   - Ante JSON incompleto, reintentar con el error exacto y los IDs requeridos.
   - Si el lote sigue fallando, caer a reparación por párrafo. Si un párrafo falla, bloquear sin traceback ni escritura parcial.
6. Ejecutar validadores deterministas antes del crítico.
7. Ejecutar `analyze_translation.py` para auditar sin API.
8. Criticar con `openai/gpt-oss-120b` contra original, contexto y glosario. Nunca permitir que el crítico apruebe un fallo determinista.
9. Reparar solo párrafos fallidos con `correct_translation.py`. Repetir controles y crítica.
10. Enviar a humano todo `critical`, conflicto entre modelos, término incierto o pasaje de alto riesgo.
11. Guardar trazabilidad: hash de fuente, modelos, parámetros, prompt, glosario, errores, reparación, revisión y estado.

Usar los modelos como candidatos, no como verdad eterna. Verificar disponibilidad, parámetros y cuotas oficiales antes de cada campaña. No declarar ganador sin benchmark ciego suficiente.

## Estados

- `legacy_machine`: traducción anterior pendiente de reevaluación.
- `machine`: superó controles automáticos, sin revisión humana.
- `human`: aprobada por revisor autorizado.
- `blocked`: contiene fallo crítico o incertidumbre sin resolver.

Nunca rebajar `human` a `machine`. Nunca publicar `blocked`.

## Seguridad operativa

- Trabajar en lectura o `--dry-run` por defecto.
- No escribir PostgreSQL, purgar ni traducir toda la obra sin autorización explícita.
- No gastar cuota compartida con el Oracle sin comprobar reserva y límites reales.
- No exponer `.env`, claves, tokens ni cadenas de conexión.
- No purgar los 46 capítulos heredados hasta demostrar victoria del pipeline nuevo.
- No sembrar una traducción con fallos `critical` o `major` abiertos.

## Comandos existentes

Ejecutar desde `arcanum-api/`. Revisar `--help` antes porque las opciones pueden cambiar.

```powershell
python scripts\translate_library.py culpeper-complete-herbal --review
python scripts\translate_library.py culpeper-complete-herbal --limit 1
python scripts\translate_library.py culpeper-complete-herbal --only all-heal --limit 1
python scripts\analyze_translation.py culpeper-complete-herbal
python scripts\correct_translation.py culpeper-complete-herbal --limit 1
python scripts\correct_translation.py culpeper-complete-herbal --only all-heal --limit 1
python scripts\correct_translation.py culpeper-complete-herbal --only amara-dulcis --write
python scripts\recheck_translation.py culpeper-complete-herbal
python scripts\recheck_translation.py culpeper-complete-herbal --plantas
python scripts\recover_translation.py culpeper-complete-herbal --dry-run
python scripts\seed_library.py culpeper-complete-herbal --dry-run
```

No traducir masivamente hasta superar el benchmark MQM. `seed_library.py` bloquea estados `legacy_machine` y `blocked`.

## Criterio de terminado

Exigir antes de producción:

- Benchmark ciego de 100 párrafos estratificados; 60 es mínimo experimental.
- Cero errores críticos médicos o botánicos.
- Cero cambios en nombres protegidos, números, fracciones o unidades.
- JSON válido en al menos 99,5 % de respuestas.
- Resultado MQM superior a `legacy_machine`, con intervalo de confianza del 95 %.
- Revisión humana del 100 % de pasajes de alto riesgo y muestra del resto.
- Tests verdes y simulación de carga limpia.

Si falta evidencia, marcar `NO COMPROBADO`. No rellenar huecos con intuición.
