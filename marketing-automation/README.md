# Granja editorial de ARCANUM

n8n coordina contenido verificable de ARCANUM. No lee datos de usuarios, no
consulta la base de produccion y no publica sin aprobacion humana.

## Arranque local

```powershell
cd marketing-automation
.\scripts\New-LocalEnv.ps1
docker compose up -d
docker compose ps
```

Abrir `http://localhost:5678` y crear la cuenta propietaria local.

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

## Primer flujo

`semilla -> paquete factual -> Gemini -> validacion -> revision humana`

El publicador queda fuera del MVP. Primero se producen borradores y se mide la
calidad editorial.

Antes de aprobar, completar
[`checklists/revision-editorial.md`](checklists/revision-editorial.md).
`ready_for_review` abre la revisión humana; no autoriza publicación.
