---
name: arcanum-content-plan
description: Convierte objetivos de marketing de ARCANUM en briefs factuales y una cola editorial reutilizable. Usar para calendarios, campañas, pilares, ideas de publicaciones o preparación de entradas para n8n; no usar para renderizar imágenes, videos ni publicar.
---

# ARCANUM Content Plan

Produce briefs listos para la granja editorial, no copy final.

## Fuente y límites

- Verifica cada feature contra `docs/play-ficha.md` o código vivo.
- Roadmap no entra como capacidad actual.
- No uses datos de usuarios ni contenido del grimorio.
- Cada claim lleva `source_id`; cada fuente lleva referencia concreta.
- Mantén separados hecho, interpretación editorial y advertencia.

## Flujo

1. Define objetivo, audiencia, pilar y formato principal.
2. Elige un ángulo: fricción, práctica, función o prueba técnica.
3. Reúne solo los hechos necesarios; más hechos no siempre producen mejor pieza.
4. Genera un brief compatible con
   `marketing-automation/schemas/content-brief.schema.json`.
5. Propón derivados razonables: estático, carrusel, story o video corto.
6. Deja el item en `queued`; no lo publiques ni lo marques aprobado.

## Salida

- Resumen editorial de una línea.
- Brief JSON válido.
- Formatos derivados recomendados.
- Riesgos o hechos que necesitan verificación.

Prioriza contenido reutilizable. Una idea sólida debe poder convertirse en al
menos dos formatos sin inventar información nueva.
