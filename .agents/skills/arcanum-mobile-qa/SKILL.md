---
name: arcanum-mobile-qa
description: Prueba visual de ARCANUM en un Android real con ADB, capturas, inspeccion de imagenes, gestos, logs y medicion de fluidez. Usar cuando se pida recorrer una pantalla o animacion en dispositivo y documentar fallos observables.
---

# QA visual en Android

1. Lee `AGENTS.md` y el plan de la pantalla. Confirma rama, worktree, dispositivo, variante de build y URL real del backend antes de tocar la app. Usa solo bases de prueba; nunca cargues el `.env` de produccion.
2. Comprueba `adb devices`, `adb reverse --list` y el estado de la pantalla. Si hay patron o PIN, pide al propietario que desbloquee; no intentes eludirlo. Evita guardar capturas con notificaciones privadas.
3. Captura con `adb shell screencap -p`, copia al worktree con `adb pull` y abre la imagen con `view_image`. Mira el resultado de cada gesto importante antes de continuar. Anota el paso, gesto, estado esperado y estado observado.
4. Obtén los limites reales de los controles con `adb shell uiautomator dump` cuando sea posible. Las imagenes que muestra `view_image` pueden estar escaladas: usa coordenadas del dispositivo, no las de la vista previa. Si la animacion impide obtener un arbol inactivo, inspecciona la captura y reintenta despues.
5. Para fallos, conserva una captura o linea de log con hora y paso reproducible. Distingue observacion de inferencia. Corrobora el estado de la API o base local antes de atribuir un error visual al servidor.
6. Para fluidez, limpia logcat al inicio de cada escena y mide por separado reposo y tirada completa durante un intervalo fijo de al menos 30 segundos. Registra lineas `Skipped`/`Choreographer` y, si esta disponible, `dumpsys gfxinfo ... framestats` o `FrameTiming` de Flutter. La ausencia de `Skipped` no demuestra 60 fps; informa metodo, duracion, muestras y limites.
7. Contrasta movimientos normales y «reducir movimiento». Cierra el flujo completo y comprueba lecturas guardadas. Repite solo el escenario que se haya corregido, ademas de las puertas de tests pertinentes.
8. Guarda evidencia dentro del worktree autorizado sin secretos. Antes del commit, revisa `git status` y confirma que no entran caches, capturas privadas ni cambios generados ajenos.
