# Mesa de tarot: prueba de rendimiento

Primer paso de la fase 4 (`docs/ARCANUM-Plan-Mesa-Tarot.md`): ¿llegan 78 cartas en abanico y una Cruz Celta a 60 fps con Impeller en el móvil real?

Mide cinco escenas (abanico, volteos, arrastre, cámara y todo a la vez) con dos técnicas, **widgets** (un `Transform` por carta) y **pintor** (un `CustomPainter`). Usa `FrameTiming`, que es lo que tarda el motor de verdad.

- Id propio `com.arcanum.mesa_rendimiento`: se instala junto a ARCANUM sin sustituirla.
- Proyecto aparte y no una ruta de la app, porque la app usa Firebase con un solo id registrado y una build con otro id no compila.
- El arte se copia de `arcanum_app/assets/tarot` y no se versiona.

```
sh preparar.sh    # copia el arte y construye build/app/outputs/flutter-apk/app-profile.apk
```

Las cartas de la prueba son más sencillas que `TarotCardView`: si la prueba va justa, la mesa real irá peor.
