# Lienzo del taller de sigilos: prueba en móvil

Mide en el teléfono real el lienzo del taller (tacto, guías y rendimiento) con el **mismo** motor y el mismo lienzo que la app: dependen del paquete `arcanum_app/packages/arcanum_sigilos`.

- Id propio `com.arcanum.taller_lienzo`: se instala junto a ARCANUM sin sustituirla.
- Es un proyecto aparte y no una ruta de la app, porque la app usa Firebase con un solo id registrado.
- Las fuentes se copian de `arcanum_app/assets/fonts` y no se versionan.

```
sh preparar.sh    # copia las fuentes y construye build/app/outputs/flutter-apk/app-profile.apk
```

«Matriz» recorre 5 estilos por 3 pilas de capas con 4 s de arrastre automático cada uno. Escribe en el log una línea `LIENZO` por caso, con los tiempos de `FrameTiming` y el porcentaje de frames fuera de presupuesto a la frecuencia real de la pantalla:

```
adb logcat -s flutter:I | grep LIENZO
```

Antes de tocar la pantalla por `adb`, comprobar que la app está en primer plano (`adb shell dumpsys window | grep mCurrentFocus`): el teléfono puede estar en uso por otra prueba.
