# Granja editorial de ARCANUM

n8n coordina contenido verificable de ARCANUM. No lee datos de usuarios, no
consulta la base de produccion y no publica sin aprobacion humana.

## Arranque local

```powershell
cd marketing-automation
.\scripts\New-LocalEnv.ps1
docker compose up -d
docker compose ps
.\scripts\Seed-ContentQueue.ps1
```

Abrir `http://localhost:5678` y crear la cuenta propietaria local.

El compose también levanta `video-assembler` en `http://localhost:3001`. Para
preparar clips hay que definir `PEXELS_API_KEY` en `.env`; la respuesta conserva
autor, página de origen y licencia. Los videos finales quedan en `output/video/`.

## Configurar Gemini

1. Revocar cualquier clave expuesta en chat, capturas o terminales.
2. Crear una clave nueva en el proyecto `arcanum-marketing` de AI Studio.
3. En n8n: Credentials -> New -> Google Gemini(PaLM) API.
4. Pegar la clave directamente en n8n.
5. Probar y guardar. No exportar la credencial con workflows.

## Fronteras

- Base PostgreSQL separada de ARCANUM.
- Sin `GEMINI_API_KEY` en `.env`: n8n cifra la credencial con
  `N8N_ENCRYPTION_KEY`.
- Sin acceso a grimorios, consultas, cartas natales ni conversaciones.
- Datos astronomicos calculados antes de llegar al modelo.
- Licencia y fuente obligatorias para cada activo.
- La IA redacta; no inventa hechos.

## Cola editorial

`queued -> reclamar -> paquete factual -> Gemini -> validacion -> persistencia`

`Seed-ContentQueue.ps1` aplica las migraciones pendientes y carga diez briefs
idempotentes desde `seeds/content-briefs.json`. Una segunda ejecución actualiza
los hechos sin reiniciar estados. Usar `-RequeueExisting` solo cuando se quiera
regenerar deliberadamente contenido ya procesado.

El workflow reclama un solo item con `FOR UPDATE SKIP LOCKED`, lo marca
`generating` y guarda borrador, validación, ruta de modelos y fecha. Una
reclamación abandonada vuelve a la cola después de quince minutos.

El publicador queda fuera del MVP. Primero se producen borradores y se mide la
calidad editorial.

## Render de carrusel

El render final solo acepta copy con `status: approved`. Genera PNG de
1080x1350, alt text por tarjeta y un manifiesto con hashes SHA-256.

```powershell
D:\Python312\python.exe scripts\render_carousel.py `
  --content visuals\carousels\carta-natal-001\content.json `
  --output-dir output\carta-natal-001

.\scripts\Register-CarouselRender.ps1 `
  -ContentPath visuals\carousels\carta-natal-001\content.json `
  -ManifestPath output\carta-natal-001\manifest.json
```

El segundo comando registra aprobador, fecha, manifiesto y estado `rendered`.
No programa ni publica la pieza.

El modo preview acepta `ready_for_review`, añade una marca visible y no habilita
el registro final:

```powershell
D:\Python312\python.exe scripts\render_carousel.py --preview `
  --content visuals\carousels\tarot-78-arcanos-001\content.json `
  --output-dir output\previews\tarot-78-arcanos-001
```

Antes de aprobar, completar
[`checklists/revision-editorial.md`](checklists/revision-editorial.md).
`ready_for_review` abre la revisión humana; no autoriza publicación.
