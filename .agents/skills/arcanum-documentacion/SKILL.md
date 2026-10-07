---
name: arcanum-documentacion
description: Organiza y actualiza la documentación de producto, arquitectura, diagramas y web informativa de ARCANUM. Usar para explicar la app, preparar guías, decidir qué mostrar en el sitio o mantener documentos técnicos; no sustituye la revisión legal especializada.
---

# Documentación de ARCANUM

Trabaja desde [`docs/README.md`](../../../docs/README.md) y [`docs/plan-documentacion-web.md`](../../../docs/plan-documentacion-web.md). La documentación de Git es la fuente técnica; `arcanum_app/sitio/` es la web informativa publicada por Firebase; los textos legales vigentes se editan en `gh-pages`, según `legal-site/README.md`.

## Método

1. Define el lector y la pregunta concreta: usuario de la app, visitante del sitio o equipo técnico.
2. Busca primero en código, configuración, pruebas y documentos publicados. Una nota vieja es evidencia histórica, no estado actual. Cita rutas o PR/commit que sustenten afirmaciones importantes.
3. Elige el documento estable que corresponde. Actualízalo antes de crear otra nota suelta. Si el cambio introduce una decisión duradera, añade un ADR breve con fecha, motivo, alternativas y consecuencia.
4. Para arquitectura, empieza por contexto y flujo de datos. Usa Mermaid versionado; UML de clases solo si la relación entre clases es la pregunta. Cada diagrama lleva fuentes y se corrige cuando cambia el flujo.
5. Para el sitio, muestra tareas reales, capturas actuales y límites claros. No publiques material interno, datos personales, funciones futuras como existentes ni copias de los textos legales.
6. Comprueba enlaces, rutas, sintaxis Mermaid y que la descripción pública coincide con la app. Anota fecha y alcance de la revisión.

## Decisiones locales que evitan errores

- La navegación actual se comprueba en `arcanum_app/lib/core/router/app_router.dart`; no deducirla de specs antiguas.
- El Oráculo usa Groq; el archivo `claude_service.py` y skills viejas pueden conservar nombres históricos. Verificar `arcanum-api/app/core/config.py` antes de citar un modelo.
- El Grimorio cifra en el cliente. No describir al backend como receptor de notas en claro sin evidencia nueva.
- El sitio Firebase sirve `arcanum_app/sitio/`, no `arcanum_app/web/`. Mantener `app-ads.txt` en la raíz del sitio del desarrollador.
- Si `D:\Brain` no está disponible, dejar la documentación en Git e informar que falta la copia/enlace del vault. No inventar sincronización.
