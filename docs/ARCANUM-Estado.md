---
tags: [arcanum, estado, indice]
tipo: estado
area: arcanum
actualizado: 2026-06-18
nota: "Reconstruido desde memoria tras perder el vault F:. Fuente de verdad ahora en este repo git."
---

# ARCANUM — Estado del Proyecto (índice maestro)

App móvil premium de magia/ocultismo serio (iOS/Android). **Flutter + FastAPI + Swiss Ephemeris
local + Claude API.** Freemium ($9.99/mes · $79.99/año). Código: `D:\Proyectos\Arcanum`,
backend en GitHub `github.com/Samael2626/Arcanum`.

Docs del proyecto (este repo): [[ARCANUM-Semana3-Flutter]] · [[ARCANUM-Mejoras-y-Retos]] ·
[[ARCANUM-Auditoria-Senior-2026-06-17]] · `docs/checkpoints/`.

## Stack
- **Backend:** FastAPI (Python 3.12) + PostgreSQL 17 + Redis (Memurai en Windows) + Alembic.
- **Astral:** Swiss Ephemeris LOCAL (`pyswisseph`, efeméride Moshier) + `astral` (sunrise/sunset).
  *AstroVisor descartado* (API caída/dependencia externa frágil).
- **Mobile:** Flutter 3.44 (SDK en `D:\flutter`), tema "Grimorio Vivo", GoRouter, google_fonts.
  Target dev = web/Edge; mismo código a móvil después.
- **Pagos:** RevenueCat · **IA:** Claude API · **Media:** Cloudflare R2.

## Semana 1 — Backend auth/seguridad ✅ (en GitHub, master)
FastAPI, 8 modelos, JWT (access 15min + refresh 30d con rotación), endpoints auth/users.
Validado contra Postgres+Redis reales. Hardening: fix `jti` en refresh, logout blacklistea access
token, fix mass-assignment (escalada premium), rate limiting por IP, pool_pre_ping. Ver auditoría.
Infra: `postgresql-x64-17` (pass `postgrespassword`, bases `arcanum_db`+`arcanum_test`), `Memurai` :6379.

## Semana 2 — Motor astral ✅ (en GitHub, master, commit 2561333)
17 endpoints `/astral/*`: horas planetarias (caldeo), fase lunar (precisa, elongación Luna-Sol),
carta natal (planetas/casas/aspectos/Asc/MC), tránsitos, dashboard `today`, calendario ritual
(próximas horas, próxima hora de un planeta, fases lunares con hora exacta). 47/47 tests.

## Semana 3 — App Flutter (UI) 🔄 EN CURSO
Tema Grimorio Vivo (negro/dorado/marfil, Cormorant Garamond + Crimson Pro). Navegación GoRouter
`StatefulShellRoute` con barra inferior de 5 pestañas. "Hoy" en vivo (hora planetaria + luna
dibujada, con micro-animación de pulso dorado). Arquitectura `core/`+`shared/`+`features/`. Corre en
`localhost:3000` (`flutter run -d web-server --web-port 3000`). Ver [[ARCANUM-Semana3-Flutter]].

### Auth + Cielos (retos #1 y #4 — HECHO, commit `529f9dd`)
- **Auth:** Dio con interceptor (Bearer + refresh silencioso en 401), `flutter_secure_storage`,
  Riverpod (`AuthNotifier` + providers). Pantallas **login** y **registro** (con datos natales).
- **Cielos** ya NO es skeleton: con sesión muestra **carta natal** (Asc/MC, planetas con signo/casa/
  retro) + **tránsitos de hoy**; sin sesión, prompt de login.
- deps nuevas: `dio`, `flutter_riverpod`, `flutter_secure_storage`.
- Pestañas **Grimorio / Arte / Oráculo** siguen skeleton: faltan sus endpoints en el backend.

### ⚠️ Problema operativo: disco C: lleno
`C:` llegó a **0 GB libres** → el compilador de Dart (temporales en `C:\...\Temp`) falla con errno
112. Workaround: lanzar Flutter con `TEMP`/`TMP`/`TMPDIR` apuntando a `D:\tmp`. **Pendiente:** liberar
`C:` o fijar `TEMP` a `D:\tmp` permanente en Variables de entorno de Windows.

## Comandos clave
```
# Backend
cd D:\Proyectos\Arcanum\arcanum-api && venv\Scripts\python.exe -m uvicorn app.main:app  # :8000 /docs
set TEST_DATABASE_URL=postgresql://postgres:postgrespassword@localhost:5432/arcanum_test
venv\Scripts\python.exe -m pytest -q   # 47/47

# Flutter (PATH: D:\flutter\bin)
cd D:\Proyectos\Arcanum\arcanum_app && flutter run -d web-server --web-port 3000   # abrir Edge
```

## Siguiente
Auth UI + Dio/JWT + Riverpod ✅ hechos. Falta: onboarding (5 pasos) pulido; endpoints backend para
Grimorio (CRUD + cifrado AES-256 client-side, reto #2), Materia Arcana (Arte) y Oráculo (tarot/IA);
luego conectar esas pestañas. Ver [[ARCANUM-Mejoras-y-Retos]].
