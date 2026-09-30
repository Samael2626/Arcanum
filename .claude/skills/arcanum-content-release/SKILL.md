---
name: arcanum-content-release
description: Audita, empaqueta, programa o publica contenido aprobado de ARCANUM en canales externos. Usar para revisión final, calendario de salida, UTM, carga privada o publicación; requiere aprobación humana explícita y no genera el contenido base.
---

# ARCANUM Content Release

Este skill controla el último metro. `ready_for_review` no autoriza publicación;
solo `approved` puede avanzar.

## Preflight

- Claims y fuentes revisados por una persona.
- Asset final visto, no solo descrito.
- Licencia, atribución, música y voz registradas.
- Ortografía, subtítulos, alt text y CTA comprobados.
- Canal, cuenta, fecha, zona horaria y visibilidad confirmados.
- UTM y destino funcionales.

## Flujo

1. Prepara un paquete de publicación y muestra exactamente qué saldrá.
2. Prefiere borrador, privado o programación sobre publicación inmediata.
3. Pide autorización justo antes de mutar el canal externo.
4. Publica una pieza por operación salvo orden explícita de lote.
5. Guarda ID remoto, URL, hora, estado y error completo.
6. Un fallo no se convierte en éxito; deja `failed` y evidencia.

## Límites

- Nunca publiques desde `needs_revision` o `ready_for_review`.
- Nunca reutilices credenciales entre canales ni las escribas en workflows.
- No respondas comentarios o DMs masivamente.
- Si el copy toca privacidad, pagos, salud o predicción, usa revisión de
  compliance antes del preflight.
