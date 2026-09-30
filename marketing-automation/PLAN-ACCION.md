# Plan de acción — granja de contenido ARCANUM

## Objetivo

Convertir hechos verificados de ARCANUM en publicaciones aprobables y, después,
en piezas visuales y videos. La automatización produce borradores; una persona
autoriza cualquier publicación externa.

## Estado real

- n8n genera un paquete editorial con hook, guion, carrusel, caption y CTA.
- Gemini principal y respaldo funcionan con salida JSON y validación.
- PostgreSQL ya tiene tablas para contenido, publicaciones y métricas.
- El prototipo anterior vive en `D:/Proyectos/Youtube/video-assembler`.
- Ese prototipo ensambla video vertical 1080×1920 con MoviePy, consulta Pexels y
  expone FastAPI, pero no tiene repositorio Git, tests ni contrato estable.
- Todavía no existe cola editorial conectada, render de carruseles ni publicación
  automática.

## Ruta de fácil a difícil

### Fase 1 — Cola editorial

**Estado:** completada el 30 de septiembre de 2026.

- Leer el siguiente contenido con estado `queued`.
- Adjuntar hechos, fuente, pilar, formato y objetivo.
- Generar el paquete editorial actual.
- Guardar borrador, errores, modelo y fecha.
- Estados: `queued`, `generating`, `needs_revision`, `ready_for_review`,
  `approved`, `rejected`, `rendered`, `scheduled`, `published`, `failed`.

**Terminado cuando:** diez briefs distintos recorren el flujo sin editar nodos.
Resultado vivo: diez procesados, ocho en `ready_for_review`, dos en
`needs_revision`, cero atascados y cero fallos sin registrar.

### Fase 2 — Publicaciones de texto y carruseles

**Estado:** en curso. Primer carrusel aprobado y renderizado el 30 de septiembre
de 2026 (`astrologia-carta-natal-001`), con cinco tarjetas 1080x1350, arte
original trazable, alt text y hashes SHA-256. Faltan dos carruseles para cerrar
la fase.

- Crear una plantilla ARCANUM determinista en 1080×1350.
- Renderizar portada y 3–6 tarjetas desde el JSON aprobado.
- Exportar PNG, manifiesto de assets y alt text real.
- Revisar legibilidad móvil, márgenes seguros y contraste.

**Terminado cuando:** tres carruseles distintos salen listos para revisión sin
ajustes manuales de composición.

### Fase 3 — Imagen estática con arte

- Elegir grabado histórico con licencia comprobada o generar una imagen nueva.
- Aplicar tratamiento de marca sin texto incrustado por IA.
- Renderizar texto y logotipo de forma determinista.
- Registrar fuente, licencia y atribución.

**Terminado cuando:** tres posts conservan identidad visual y trazabilidad del
recurso.

### Fase 4 — Stories

- Derivar 3–5 pantallas verticales 1080×1920 del mismo contenido aprobado.
- Una idea por pantalla, texto grande y CTA final.
- Exportar paquete; todavía sin publicación automática.

**Terminado cuando:** una pieza aprobada produce carrusel y story coherentes.

### Fase 5 — Reel, TikTok y Short

- Mover `video-assembler` a un repositorio o módulo versionado.
- Añadir pruebas de health, contrato, render y duración.
- Definir preset ARCANUM vertical: tipografía, color, subtítulos y zona segura.
- Conectar guion aprobado → TTS → segmentos visuales → ensamblaje → MP4.
- Validar licencias de clips, música y voz.

**Terminado cuando:** tres videos de 15–45 segundos renderizan de forma repetible
y pasan revisión visual y auditiva.

### Fase 6 — Programación y publicación

- Crear credenciales separadas por canal.
- Preparar publicación en modo borrador o privado.
- Exigir estado `approved` y confirmación humana explícita.
- Publicar una sola pieza piloto por canal.
- Guardar URL, ID remoto, fecha, UTM y resultado.

**Terminado cuando:** puede publicarse y rastrearse una pieza sin copiar datos a
mano y sin habilitar autopublicación masiva.

### Fase 7 — Métricas y aprendizaje

- Recoger impresiones, retención, guardados, clics y conversiones.
- Comparar formato, pilar, hook y CTA.
- Proponer nuevos briefs desde resultados; nunca reescribir hechos desde métricas.

## Primer sprint

1. Conectar `content_items` al workflow actual.
2. Cargar diez briefs verificados: dos de Tarot, dos de cielo/carta natal, dos de
   grimorio, dos de Materia y dos de posicionamiento.
3. Guardar cada salida y su estado.
4. Construir una plantilla de carrusel.
5. Renderizar tres carruseles y aprobar uno.

Video queda después. El generador viejo se recupera en Fase 5; tocarlo antes de
tener cola, aprobación y assets solo automatizaría desorden.

## Skills operativas

- `$arcanum-content-plan`: crea briefs verificables y alimenta la cola.
- `$arcanum-content-visual`: convierte copy aprobado en post, carrusel o story.
- `$arcanum-video-short`: ensambla Reel, TikTok o Short desde un guion aprobado.
- `$arcanum-content-release`: hace QA final y prepara la publicación autorizada.

Orden normal: plan → visual o video → release. Ninguna skill publica por sí sola.
