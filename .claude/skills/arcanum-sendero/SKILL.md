---
name: arcanum-sendero
description: >
  Diseña, implementa y audita Sendero, la guía práctica y progresiva de
  ARCANUM, incluida la introducción contextual de la moneda Fragmentos Arcanos.
  Usar para primera vez de uso, recorridos guiados, ayudas contextuales,
  progreso de aprendizaje o mini tutoriales de funciones nuevas. No usar para
  el onboarding natal, consentimiento o registro salvo que el cambio conecte
  explícitamente esos flujos con el inicio de Sendero.
---

# Sendero

Sendero enseña la app real mediante acciones breves. No es un carrusel
promocional ni sustituye las ayudas `?` del glosario.

Antes de diseñar o implementar, leer
[`references/product-contract.md`](references/product-contract.md). Ese archivo
contiene las decisiones de producto ya cerradas.

## Método

1. Inventariar rutas, funciones, estados vacíos, límites premium, acciones que
   consumen créditos y reglas de Fragmentos Arcanos en el código vivo. No
   confiar en catálogos antiguos.
2. Separar la orientación inicial de los recorridos por módulo. Cada recorrido
   debe enseñar una capacidad concreta sobre la pantalla real.
3. Definir para cada recorrido: identificador estable, versión, disparador,
   prerrequisitos, pasos, acción real, consecuencias, condición de finalización
   y forma de retomarlo.
4. Mantener navegación libre. Saltar, pausar, cerrar o repetir nunca puede
   bloquear la app ni una función.
5. Pedir confirmación explícita inmediatamente antes de cualquier acción que
   consuma crédito, cree contenido, modifique datos o tenga otro efecto real.
6. Sincronizar progreso por cuenta en backend y conservar caché local para uso
   sin conexión. Resolver conflictos de forma monotónica: nunca perder un paso
   completado confirmado por servidor o dispositivo.
7. Introducir Fragmentos Arcanos después de una práctica elegible, en el momento
   en que la recompensa tiene sentido. Sendero nunca acuña moneda por su cuenta:
   usa el servicio canónico de economía y muestra su resultado real.
8. Añadir pruebas del comportamiento observable y ejecutar los gates reales del
   repo antes de cerrar.

## Diseño

- Voz mística, cercana y simple. Frases cortas. Cero jerga innecesaria.
- Sensación calma: velo tenue, foco dorado, movimiento lento y salida visible.
- Una indicación y una acción principal por paso.
- Usar la interfaz real. Evitar pantallas explicativas largas y datos falsos.
- Respetar accesibilidad, áreas táctiles, lector de pantalla y reducción de
  movimiento.
- Funciones premium: mostrar valor por encima, sin fingir acceso. La llamada a
  mejorar el plan es opcional y secundaria.
- Fragmentos Arcanos: explicar primero su origen en la práctica; después su uso.
  No presentarlos como premio del tutorial ni como moneda comprable.

## Contratos que no se rompen

- El onboarding actual recoge consentimiento y perfil natal; Sendero empieza
  después y mantiene estado independiente.
- Usuarios nuevos reciben la entrada inicial con libertad total para salir.
- Usuarios existentes reciben una invitación única, no una apertura forzada.
- Funciones nuevas pueden publicar un mini recorrido opcional y versionado.
- Sendero no consume crédito sin advertencia y aceptación del usuario.
- El progreso puede retomarse tras reinstalar o cambiar de dispositivo.
- El balance, conversión, límites y elegibilidad de Fragmentos Arcanos tienen
  una sola fuente de verdad fuera de Sendero.

## Verificación mínima

- Primera entrada nueva y usuario existente.
- Saltar, pausar, retomar, descartar y repetir.
- Persistencia local, sincronización por cuenta y cambio de dispositivo.
- Confirmación previa al gasto y ausencia de débito al cancelar.
- Recorrido nuevo mostrado una sola vez.
- Vista premium informativa sin desbloqueo accidental.
- Recompensa de Fragmentos Arcanos concedida una sola vez por el servicio
  canónico; repetir Sendero no duplica saldo.
- Navegación y ayudas existentes intactas.

No marcar terminado con tests saltados por bases ausentes. Seguir los gates y el
flujo de cierre definidos en `AGENTS.md`.
