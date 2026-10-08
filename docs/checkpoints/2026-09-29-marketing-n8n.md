---
title: "Checkpoint - ARCANUM marketing n8n"
date: 2026-09-29
tags: [arcanum, checkpoint, marketing, n8n, gemini]
---

# Checkpoint - ARCANUM - 2026-09-29

## Resumen

Arranco la granja editorial local de ARCANUM. n8n 2.39.6 y PostgreSQL 17
quedaron aislados de la app y de produccion, con un primer workflow importado
para convertir un paquete factual en borrador mediante Gemini.

## Cambios realizados

- Nueva infraestructura en `marketing-automation/` con Docker Compose.
- Secretos locales generados con PowerShell y guardados en `.env` ignorado.
- n8n escucha solo en `127.0.0.1:5678`.
- PostgreSQL no publica puerto al host y usa volumen propio.
- Esquema `marketing` con contenido, publicaciones y metricas.
- Contrato JSON para paquetes factuales con fuentes, alertas y licencia.
- Workflow `ARCANUM 02 - Generar borrador` importado e inactivo.
- Prompt editorial: voz seria, sin prediccion, urgencia falsa ni claims nuevos.

## Estado actual

- `http://localhost:5678/healthz` responde `{"status":"ok"}`.
- Contenedores `arcanum-marketing-n8n-1` y
  `arcanum-marketing-postgres-1` estan activos.
- Tablas `content_items`, `publications` y `metric_snapshots` existen.
- Workflow visible en n8n con ID `arcanum-generate-draft-v1`.
- Falta crear el propietario local de n8n y asignar una credencial Gemini.
- Una clave Gemini fue pegada en el chat y debe considerarse comprometida. No se
  uso ni se guardo. Debe revocarse.

## Pendientes / proximos pasos

- Revocar la clave expuesta y crear otra en `arcanum-marketing`.
- Abrir n8n, crear propietario y guardar la clave nueva en Credentials.
- Asignar la credencial al nodo `Gemini editorial`.
- Ejecutar el borrador de manifiesto y revisar el JSON resultante.
- Implementar validacion automatica y aprobacion humana antes de render/publicar.
- Mantener el publicador fuera hasta validar calidad editorial.

## Decisiones y notas

- Gemini se usa para marketing, separado de la cuota Groq de usuarios.
- Los ensayos confirmaron clave y red funcionales. `gemini-3.8-flash` y luego
  `gemini-3.5-flash` devolvieron `503` por alta demanda. La plantilla usa
  `gemini-3.6-flash`: respondio `200` en 2,0 segundos desde el mismo contenedor.
- El flujo vivo tiene fallback real: `gemini-3.6-flash` fallo con `503` y
  `gemini-3.5-flash-lite` completo la misma ejecucion. Despues nodos de codigo
  parsearon y validaron estructura, fuentes, repeticion, CTA, alt text y tildes.
- La salida estructurada usa JSON Schema sin autorreparacion semantica. Una
  prueba demostro que reparar texto truncado con otro LLM inventaba `src_001` y
  una imagen inexistente. Ahora un fallo regenera la pieza completa, maximo dos
  intentos, y el validador factual conserva el bloqueo final.
- La IA redacta; las efemerides y hechos llegan calculados y citados.
- Ningun dato de usuarios entra a esta base o a Gemini.
- La automatizacion empieza como fabrica de borradores, no como autopublicador.
- La revision de voz ya es determinista: bloquea lenguaje de libro, tautologias,
  grandilocuencia y calificadores no respaldados por el paquete factual.
- La checklist operativa vive en
  `marketing-automation/checklists/revision-editorial.md`; `ready_for_review`
  nunca equivale a aprobado ni habilita publicacion.
- Prueba viva posterior: `gemini-3.6-flash` devolvio 503, el fallback
  `gemini-3.5-flash-lite` completo el flujo y la validacion de estructura/voz
  dio 100. El resultado final quedo en 95 por un aviso de tildes, sin publicarse.
- El aviso venia del paquete factual de demostracion, que entregaba palabras sin
  tildes y Gemini copiaba literalmente. La semilla ya usa espanol correcto y el
  test impide que esa regresion vuelva.
- El manifiesto ya no parte de dos frases pobres: incorpora seis hechos de
  `docs/play-ficha.md:95-129` sobre Tarot, carta natal, cielo de hoy, grimorio y
  Materia arcana, mas vetos explicitos contra inferencias de relleno.
- El detector de repeticion distingue copia real de vocabulario tecnico
  inevitable entre formatos. Usa reutilizacion textual o solapamiento alto
  entre fragmentos de tamano comparable; mencionar AES-256 o Swiss Ephemeris en
  script y carrusel ya no produce un falso positivo.
- Prueba viva final: modelo principal disponible, diez nodos verdes,
  `ready_for_review`, puntuacion 100, cero errores y cero avisos.
- Esta decision actualiza el plan del 28-sep: la automatizacion si comienza, pero
  todavia no abre TikTok, Instagram o YouTube como canales de publicacion.

## Ruta operativa de contenido

- El plan ejecutable vive en `marketing-automation/PLAN-ACCION.md` y avanza de
  cola editorial a carruseles, arte, stories, video corto, publicacion y metricas.
- Se crearon cuatro skills separadas por responsabilidad:
  `arcanum-content-plan`, `arcanum-content-visual`, `arcanum-video-short` y
  `arcanum-content-release`.
- La fuente canonica esta en `.claude/skills/` y el espejo compatible con Codex
  en `.agents/skills/`. Las ocho carpetas pasan `quick_validate.py`.
- El prototipo anterior de video sigue en
  `D:/Proyectos/Youtube/video-assembler`: FastAPI + MoviePy + Pexels, salida
  vertical 1080x1920. No tiene Git ni tests; por eso se recupera en la fase de
  video y no se usa como base de las primeras publicaciones.

## Fase 1 completada - 30 sep 2026

- PostgreSQL recibió una migración compatible para cola, reclamación, intentos,
  modelo usado, error y fechas de generación.
- `seeds/content-briefs.json` contiene diez briefs verificados contra
  `docs/play-ficha.md`: dos Tarot, dos astrología/cielo, dos grimorio, dos
  Materia y dos posicionamiento/producto.
- `Seed-ContentQueue.ps1` aplica migraciones y semillas de forma idempotente. La
  segunda ejecución conservó todos los estados.
- El workflow reclama con `FOR UPDATE SKIP LOCKED`, valida el brief, genera,
  bloquea claims sensibles y faltas frecuentes, registra el modelo realmente
  usado y persiste el resultado.
- Una ejecución falló porque Gemini no respetó el JSON Schema. Ese hallazgo creó
  la rama terminal que marca `failed`, guarda el error y libera la reclamación.
- Prueba viva final: diez briefs recorrieron el flujo sin editar nodos; ocho
  quedaron `ready_for_review`, dos `needs_revision`, cero `queued`, cero
  `generating` y cero `failed`.
- Los dos bloqueos reales fueron una garantía no respaldada y tildes ausentes.
  `ready_for_review` sigue sin equivaler a aprobado.

## Git

- Rama: `release/1.0.6`.
- El commit incluye solo `marketing-automation/` y este checkpoint.
- Los cambios previos de creditos, sigilos y Flutter quedan fuera.

## Fase 2 iniciada - 30 sep 2026

- Samuel aprobo de forma explicita el copy tecnico de carta natal.
- Se produjo un carrusel de cinco tarjetas en 1080x1350 con composiciones
  asimetricas, tipografia local y paleta old money de ARCANUM.
- El fondo es una ilustracion original generada para esta pieza; su procedencia
  queda en `marketing-automation/assets/manifest.json`.
- El render es determinista: Playwright compone texto real sobre HTML y exporta
  PNG con alt text y SHA-256 por archivo.
- La cola guarda aprobador, fecha de aprobacion, fecha de render y manifiesto.
- Estado final de `astrologia-carta-natal-001`: `rendered`. No fue programado ni
  publicado.
- La misma plantilla quedó validada con dos direcciones visuales: copy a la
  izquierda para grimorio y a la derecha para Tarot.
- `tarot-78-arcanos-001` y `grimorio-cifrado-local-001` tienen previews de cinco
  tarjetas, con marca visible y estado `ready_for_review`. No se registran como
  renders finales hasta recibir aprobación humana explícita.
- Grimorio recibió una V2 tras revisión visual: composición a la derecha como
  Tarot, paleta exacta de `ArcanumColors`, sigilo dorado coherente, neblina azul,
  resina borgoña y marco inspirado en `ArcanumFrame`. La V1 permanece intacta.
- Samuel aprobó Tarot y Grimorio V2. Se retiró la marca `PREVIEW`, se generaron
  diez PNG finales y ambos items quedaron `rendered` con aprobador, fechas y
  manifiestos en PostgreSQL. Fase 2 cerrada con tres carruseles finales.

## Relacionado

- [[MOC-ARCANUM]]
- [[ARCANUM-Marketing-Automation-Hub]]
- [[ARCANUM-Marketing-Plan-Arranque-2026-09-28]]

## Ubicacion en el repo

`D:/Proyectos/Arcanum/docs/checkpoints/2026-09-29-marketing-n8n.md`

---
Tags: #checkpoint #arcanum #marketing #n8n
