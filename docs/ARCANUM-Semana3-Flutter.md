---
tags: [arcanum, flutter, semana-3, ui]
tipo: avance
area: arcanum
actualizado: 2026-06-18
---

# ARCANUM — Semana 3+: App Flutter (UI Grimorio Vivo)

Ver [[MOC-ARCANUM]] · [[ARCANUM-Estado-Sesion]] · [[ARCANUM-Mejoras-y-Retos]]

> App Flutter en **web (Edge)** vía `flutter run -d web-server --web-port 3000`, consumiendo el
> backend en vivo (`localhost:8000`). Mismo código Dart → iOS/Android después.

## Estética (Grimorio Vivo)
Negro `#0A0A0F`, dorado `#C9A84C`, marfil `#F5F0E8`, borgoña. Fuentes **Cormorant Garamond**
(títulos) + **Crimson Pro** (cuerpo) vía `google_fonts`. Wordmark con tracking, divisor `✧`,
tarjetas con borde dorado, micro-animación de pulso dorado en glifos.

## Navegación
GoRouter `StatefulShellRoute.indexedStack` → barra inferior de 5 pestañas:
**Hoy** · **Cielos** · **Grimorio** · **Arte** · **Oráculo**. Rutas top-level `/login`, `/register`.

## Pantallas
- **Hoy** (en vivo, `/astral/today`): regente del día, hora planetaria (glifo con pulso), luna
  dibujada con `CustomPainter` según iluminación real. Pull-to-refresh.
- **Cielos** (auth): con sesión → carta natal (Asc/MC, planetas con signo/casa/℞) + tránsitos de hoy
  (`/astral/natal-chart`, `/astral/transits`); sin sesión → prompt de login.
- **Login / Registro**: estética Grimorio Vivo; registro captura datos natales.
- **Grimorio / Arte / Oráculo**: skeletons (`ComingSoon`) — faltan endpoints backend.

## Arquitectura
```
arcanum_app/lib/
├── main.dart                 # ProviderScope + MaterialApp.router
├── core/
│   ├── theme/                # arcanum_colors, arcanum_theme (ArcanumText)
│   ├── router/               # app_router (GoRouter), app_shell (NavigationBar)
│   ├── api/                  # arcanum_api (Dio): today, natalChart, transits
│   ├── auth/                 # token_storage, auth_repository, auth_controller (Riverpod)
│   └── network/              # dio_client (interceptor Bearer + refresh 401)
├── shared/                   # astro_symbols + widgets (ArcanumCard, MoonDisc,
│                             # PulsingGlyph, ArcanumField, GoldButton, ComingSoon)
└── features/                 # hoy, cielos, grimorio, arte, oraculo, auth
```

## Decisiones
- **Target dev = Flutter Web (Edge)**: evita Android Studio+SDK+emulador; mismo código a móvil luego.
- Riverpod para estado (sesión global, API). Dio con interceptor JWT + refresh silencioso.
- CORS: web en `:3000`, permitido en `ALLOWED_ORIGINS` del backend.
- Flutter SDK en `D:\flutter` (stable 3.44.2, Dart 3.12.2).
- ⚠️ `C:` lleno → compilar con `TEMP`=`D:\tmp` (ver [[ARCANUM-Mejoras-y-Retos]]).

---
Backend en GitHub `github.com/Samael2626/Arcanum`. App Flutter en `D:\Proyectos\Arcanum\arcanum_app`
(rama `feature/semana-3-flutter`).
