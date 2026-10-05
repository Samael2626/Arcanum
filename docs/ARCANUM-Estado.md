---
tags: [arcanum, estado, indice]
tipo: estado
area: arcanum
actualizado: 2026-10-04
nota: "Reconstruido desde memoria tras perder el vault F:. Fuente de verdad ahora en este repo git."
---

# ARCANUM — Estado del Proyecto (índice maestro)

App móvil premium de magia/ocultismo serio (iOS/Android). **Flutter + FastAPI + Swiss Ephemeris
local + Groq (`openai/gpt-oss-120b`).** Freemium ($9.99/mes · $79.99/año). Código: `D:\Proyectos\Arcanum`,
backend en GitHub `github.com/Samael2626/Arcanum`.

Docs del proyecto (este repo): [[ARCANUM-Semana3-Flutter]] · [[ARCANUM-Mejoras-y-Retos]] ·
[[ARCANUM-Auditoria-Senior-2026-06-17]] · `docs/checkpoints/`.

## Estado actual (2026-10-04)

- **Grimorio:** CRUD real con contenido cifrado AES-256; el Taller guarda documentos de letras, Kamea, Rosa-Cruz, Sello personal y Comparar como entradas `sigil` diferenciadas. El nombre/intención no aparece en el título. [[ARCANUM-Avance-Sello-Personal-2026-10-04]] (`b809b24`); [[ARCANUM-Avance-Comparar-2026-10-04]] (`5120d0b`). El detalle de Kamea oculta el rótulo del nombre por decisión de Samuel. La Bitácora de práctica usa entradas `ritual` cifradas: [[ARCANUM-Avance-Ritual-Bitacora-2026-10-04]] (`acc1d5b`).
- **Oráculo:** lecturas de tarot con IA Groq `openai/gpt-oss-120b` en producción; no usa Claude API. La disponibilidad depende de la cuota de la organización de Groq. Véase `AGENTS.md`, «Groq: modelo, límites y coste».
- **Taller:** Letras se abre desde Hoy, tiene carga/olvido y permite anotar la práctica en la Bitácora del Grimorio. Kamea y Rosa-Cruz son familias separadas sin ritual de caos; Sello personal es una reconstrucción declarada; Comparar muestra las tres figuras sin fusionarlas.

Las secciones «Semana 1–3» de abajo registran el estado histórico de junio; no describen el estado actual.

## Stack
- **Backend:** FastAPI (Python 3.12) + PostgreSQL 17 + Redis (Memurai en Windows) + Alembic.
- **Astral:** Swiss Ephemeris LOCAL (`pyswisseph`, efeméride Moshier) + `astral` (sunrise/sunset).
  *AstroVisor descartado* (API caída/dependencia externa frágil).
- **Mobile:** Flutter 3.44 (SDK en `D:\flutter`), tema "Grimorio Vivo", GoRouter, google_fonts.
  Target dev = web/Edge; mismo código a móvil después.
- **Pagos:** RevenueCat · **IA:** Groq (`openai/gpt-oss-120b`) · **Media:** Cloudflare R2.

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
- **Arte (Materia Arcana)** ya NO es skeleton: backend `/materia` (15 correspondencias sembradas:
  hierbas/piedras/metales/inciensos con planeta+elemento+intenciones; list con filtros + detalle +
  CRUD con auth) y pestaña con lista filtrable por tipo + ficha en bottom sheet. Commit `5fb8b30`.
- En junio, las pestañas **Grimorio / Oráculo** seguían como esqueleto. Ambas están implementadas; ver «Estado actual» arriba.
- **Propósito de cada módulo (uso mágico real):** ver [[ARCANUM-Modulos-Proposito]].

### Entorno (2026-06-18): movimientos de disco rompieron y se repararon
Mover apps a mano a `D:\Softwares` rompió cosas. Reparado: venv recreado (`D:\Python312`), VS Build
Tools ahora en `D:\Softwares\VS2022BuildTools` (flutter lo detecta, pyswisseph compila), `.git` del
SDK Flutter reparado (faltaba HEAD), cache web restaurado (`flutter precache --web`). **Lección: no
mover apps instaladas arrastrando carpetas — reinstalar con su instalador.**

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
Este «Siguiente» correspondía a junio. Antes de publicar faltan QA en teléfono y
revisión legal de sellos de obra ajena; la tarjeta del sitio legal se actualiza el
día de la release. Ver [[ARCANUM-Avance-Ritual-Bitacora-2026-10-04]].
