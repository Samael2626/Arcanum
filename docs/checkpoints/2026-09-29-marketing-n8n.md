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
- La IA redacta; las efemerides y hechos llegan calculados y citados.
- Ningun dato de usuarios entra a esta base o a Gemini.
- La automatizacion empieza como fabrica de borradores, no como autopublicador.
- Esta decision actualiza el plan del 28-sep: la automatizacion si comienza, pero
  todavia no abre TikTok, Instagram o YouTube como canales de publicacion.

## Git

- Rama: `release/1.0.6`.
- El commit incluye solo `marketing-automation/` y este checkpoint.
- Los cambios previos de creditos, sigilos y Flutter quedan fuera.

## Relacionado

- [[MOC-ARCANUM]]
- [[ARCANUM-Marketing-Automation-Hub]]
- [[ARCANUM-Marketing-Plan-Arranque-2026-09-28]]

## Ubicacion en el repo

`D:/Proyectos/Arcanum/docs/checkpoints/2026-09-29-marketing-n8n.md`

---
Tags: #checkpoint #arcanum #marketing #n8n
