# Documentación de ARCANUM

Este índice es la entrada a la documentación del producto. El código y los textos publicados mandan cuando una nota antigua discrepa con ellos. Fecha de revisión del índice: 2026-10-08.

## Para qué sirve cada lugar

| Lugar | Público | Contenido | Fuente de verdad |
|---|---|---|---|
| [`arcanum_app/sitio/`](../arcanum_app/sitio/) | Sí | Presentación, guía de uso, soporte y `app-ads.txt` | Archivos del sitio desplegados en Firebase |
| Rama `gh-pages` | Sí | Privacidad, términos y eliminación de cuenta | Markdown de esa rama; ver [`legal-site/README.md`](../legal-site/README.md) |
| [`arcanum_app/web/`](../arcanum_app/web/) | App | Arranque y recursos de Flutter Web | Código Flutter; no es la web informativa |
| `docs/` en este repositorio | Equipo | Estado, arquitectura, decisiones, especificaciones y evidencia | Código, pruebas y documentos enlazados |

## Leer en este orden

1. [Estado actual](ARCANUM-Estado.md): índice de avances, con secciones históricas señaladas.
2. [Mapa de arquitectura](arquitectura.md): sistemas, límites de datos y flujos que merecen diagrama.
3. [Mapa de producto](producto.md): cinco secciones, acceso, recorridos y límites comprobados en la app.
4. [Plan de documentación y web](plan-documentacion-web.md): qué publicar, qué mantener internamente y orden de trabajo.
5. [README del repositorio](../README.md): entorno, ramas, pruebas y despliegue.
6. [AGENTS.md](../AGENTS.md): reglas operativas y datos verificados del proyecto.

## Documentos existentes

| Tema | Documentos |
|---|---|
| Producto | [Mapa actual](producto.md), [Propósito de módulos](ARCANUM-Modulos-Proposito.md), [Mesa de tarot](ARCANUM-Spec-Mesa-Tarot.md), [Taller de sigilos](ARCANUM-Informe-Taller-Sigilos-2026-10-02.md) |
| Operación | [Play Console](ARCANUM-Play-Console-Progreso.md), [Seguridad beta](ARCANUM-Auditoria-Seguridad-Beta-2026-10-05.md), [Data Safety](ARCANUM-Data-Safety.md) |
| Historia | [`checkpoints/`](checkpoints/), archivos `ARCANUM-Avance-*` y documentos `ARCANUM-Semana*` |

Las notas históricas registran decisiones de su fecha. No usarlas como ficha del producto actual sin comprobar la implementación. Ejemplo: [Propósito de módulos](ARCANUM-Modulos-Proposito.md) aún marca Grimorio y Oráculo como pendientes, aunque ya existen.

## Regla de mantenimiento

- Cada cambio funcional modifica la página estable del módulo afectado, si existe. Una nota de avance sola no sustituye esa página.
- Todo diagrama indica qué archivos lo sustentan y se actualiza cuando cambia el flujo que representa.
- Cada afirmación pública sobre privacidad, pagos o funciones se verifica contra el código y el sitio legal vigente antes de publicarse.
- Las decisiones duraderas llevan motivo, alternativas consideradas, fecha y consecuencia. El seguimiento de tareas vive en issues/PR; el estado consolidado vive en [ARCANUM-Estado.md](ARCANUM-Estado.md).
- La documentación pública evita secretos, datos de usuarios, rutas internas sensibles y promesas sobre funciones pendientes.
