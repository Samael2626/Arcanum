---
tags: [arcanum, flutter, semana-3, ui]
tipo: avance
area: arcanum
actualizado: 2026-06-18
---

# ARCANUM — Semana 3: App Flutter (UI Grimorio Vivo)

Ver [[MOC-ARCANUM]] · [[ARCANUM-Estado-Sesion]]

> Por fin la parte visual. App Flutter corriendo en **web (Edge)** vía `flutter run -d web-server
> --web-port 3000`, consumiendo el backend en vivo (`localhost:8000`). El mismo código Dart correrá
> luego en iOS/Android.

## Estética implementada (Grimorio Vivo)
- Paleta: negro profundo `#0A0A0F`, dorado antiguo `#C9A84C`, marfil `#F5F0E8`, borgoña.
- Tipografías vía `google_fonts`: **Cormorant Garamond** (títulos) + **Crimson Pro** (cuerpo).
- Wordmark ARCANUM dorado con tracking, divisor ornamental `✧`, tarjetas con borde dorado tenue.

## Pantalla "Hoy" (en vivo, no skeleton)
Consume `GET /astral/today`:
- "Día de {planeta}" (regente) con su glifo.
- Tarjeta Hora Planetaria: glifo del planeta, nombre, diurna/nocturna, minutos restantes.
- Tarjeta La Luna: **disco lunar dibujado con CustomPainter** según la iluminación real (fase
  creciente/menguante), nombre de fase y % iluminada.
- Pull-to-refresh.

## Navegación (shell de 5 pestañas)
- **GoRouter** con `StatefulShellRoute.indexedStack` → barra inferior persistente.
- Pestañas: **Hoy** (live) · **Cielos** · **Grimorio** · **Arte** · **Oráculo**.
- Las 4 últimas son skeletons premium (`ComingSoon`: glifo esotérico + título + descripción +
  pill "Próximamente").

## Arquitectura (limpia, escalable)
```
arcanum_app/lib/
├── main.dart                 # MaterialApp.router
├── core/
│   ├── theme/                # arcanum_colors, arcanum_theme (ArcanumText)
│   ├── router/               # app_router (GoRouter), app_shell (NavigationBar)
│   └── api/                  # arcanum_api (http; migrará a Dio + JWT en Semana 4)
├── shared/widgets/           # ArcanumCard, SectionLabel, Ornament, ArcanumHeader,
│                             # MoonDisc, ComingSoon
└── features/                 # hoy, cielos, grimorio, arte, oraculo
```

## Decisiones técnicas
- **Target inicial = Flutter Web (Edge)**: evita instalar Android Studio+SDK+emulador (varios GB);
  el mismo código compila a móvil después. Edge se usa porque no hay Chrome (`CHROME_EXECUTABLE`
  no necesario con `-d web-server`, se abre Edge manualmente).
- CORS: la web corre en `:3000`, que el backend ya permite en `ALLOWED_ORIGINS`.
- Flutter SDK instalado en `D:\flutter` (canal stable 3.44.2, Dart 3.12.2).

## Pendiente Semana 3 / siguiente
- (Opcional) pulir transiciones, estados de carga por pestaña.
- Versionar la app en git (rama nueva) — aún sin commit.
- Semana 4: onboarding (5 pasos) + auth UI (login/registro contra el backend JWT).

---
Backend (Semanas 1-2) ya en GitHub: `github.com/Samael2626/Arcanum`. La app Flutter está en
`D:\Proyectos\Arcanum\arcanum_app`.
