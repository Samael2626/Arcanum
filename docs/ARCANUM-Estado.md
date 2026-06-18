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
dibujada). 4 skeletons. Arquitectura `core/`+`shared/`+`features/`. Corre en `localhost:3000`
(`flutter run -d web-server --web-port 3000`). Ver [[ARCANUM-Semana3-Flutter]].

## Comandos clave
```
# Backend
cd D:\Proyectos\Arcanum\arcanum-api && venv\Scripts\python.exe -m uvicorn app.main:app  # :8000 /docs
set TEST_DATABASE_URL=postgresql://postgres:postgrespassword@localhost:5432/arcanum_test
venv\Scripts\python.exe -m pytest -q   # 47/47

# Flutter (PATH: D:\flutter\bin)
cd D:\Proyectos\Arcanum\arcanum_app && flutter run -d web-server --web-port 3000   # abrir Edge
```

## Siguiente: Semana 4
Onboarding (5 pasos) + auth UI (login/registro). Migrar API a Dio + interceptor JWT + refresh
silencioso. Riverpod para estado de sesión. Ver [[ARCANUM-Mejoras-y-Retos]].
