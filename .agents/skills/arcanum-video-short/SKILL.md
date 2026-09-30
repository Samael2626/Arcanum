---
name: arcanum-video-short
description: Produce Reels, TikToks y Shorts verticales de ARCANUM desde guiones aprobados, reutilizando el ensamblador FastAPI/MoviePy existente. Usar para storyboard, TTS, clips, subtítulos o render MP4 de 15–45 segundos; no usar para video largo ni publicación.
---

# ARCANUM Video Short

Reutiliza `D:/Proyectos/Youtube/video-assembler`; no reconstruyas el motor sin
comprobarlo. Es un prototipo sin Git ni tests: valida cada etapa antes de confiar
en él.

## Contrato actual

- Health: `GET /healthz`.
- Visuales: `POST /api/visuals/generate` mediante Pexels.
- Ensamblaje: `POST /api/video/assemble`.
- Salida objetivo: 1080×1920, 30 fps.
- Prefiere los endpoints `/api/*`; las rutas legacy no son base nueva.

## Flujo

1. Exige brief, guion y CTA aprobados.
2. Divide 15–45 segundos en escenas con duración, narración y búsqueda visual.
3. Genera o recibe TTS y conserva licencia/consentimiento de la voz.
4. Obtén clips verticales y registra fuente y autor.
5. Ensambla con preset ARCANUM, subtítulos y zonas seguras.
6. Verifica con `ffprobe`: resolución, fps, duración, audio y archivo reproducible.
7. Revisa el video completo antes de entregarlo; no subas nada.

## Gates

- No renderices desde copy en `ready_for_review`; requiere `approved`.
- No descargues clips sin procedencia ni uses música sin licencia.
- No ocultes escenas faltantes repitiendo un clip de forma absurda.
- Si el servicio falla, diagnostica el prototipo; no inventes un reemplazo.
- No publiques ni programes el video sin autorización separada.
