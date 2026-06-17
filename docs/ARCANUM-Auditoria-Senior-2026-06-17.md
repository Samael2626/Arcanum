---
tags: [arcanum, auditoria, seguridad, semana-1, senior-review]
tipo: auditoria
area: arcanum
actualizado: 2026-06-17
veredicto: no-apto-sin-fixes (corregido)
---

# ARCANUM — Auditoría Senior Backend Semana 1 (2026-06-17)

Ver [[MOC-ARCANUM]] · [[ARCANUM-Estado-Sesion]] · [[ARCANUM-Auditoria-Semana1]]

> Veredicto inicial: la Semana 1 funcionaba (tests + runtime verdes) pero NO estaba lista como
> producto serio: 1 fallo crítico de seguridad de negocio + huecos de producción.
> Estado tras esta sesión: fixes críticos/altos/medios aplicados y verificados (14/14 tests +
> verificación en vivo con Postgres y Redis reales).

## Hallazgos

### CRÍTICO — Escalada de privilegios (mass-assignment)
PUT /users/me usaba un UserUpdate que exponía subscription_tier, subscription_expires_at y
revenuecat_customer_id, y update_user_me hacía setattr ciego. Cualquier usuario free podía
auto-otorgarse premium con {"subscription_tier":"premium"}. Letal para freemium.
- Fix: UserUpdate reducido a campos editables por el usuario (display_name, birth_*, preferred_*,
  onboarding_completed). Suscripción es server-controlled (webhook RevenueCat). Pydantic ignora
  claves extra -> inmutables vía API.
- Regresión: tests/test_auth.py::test_update_me_cannot_escalate_subscription.

### ALTO — Logout no invalidaba el access token
blacklist_token estaba importado pero nunca se llamaba. Access token válido ~15 min tras logout.
- Fix: logout blacklistea el access token en Redis por su TTL restante. Verificado en vivo:
  tras logout, GET /users/me -> 401.

### ALTO — Sin rate limiting (PENDIENTE)
/auth/login y /auth/register sin límite -> fuerza bruta y enumeración de emails. Redis disponible.
No corregido aún — siguiente prioridad.

### MEDIO — Corregidos
- orm_mode = True (Pydantic v1) -> model_config = ConfigDict(from_attributes=True).
- create_engine sin pooling robusto -> pool_pre_ping=True + pool_recycle=1800.
- exceptions.py con handler nunca registrado -> registrado en main.py.

### BAJO / PENDIENTE
- Repo git roto: existe .git en D:\Proyectos\Arcanum pero git lo rechaza ("not a git repository").
  Sin control de versiones funcional -> reparar/re-init + primer commit.
- bcrypt trunca passwords >72 bytes en silencio (sin max_length en UserCreate).
- Sin limpieza de refresh tokens expirados (la tabla crece) -> job/cron pendiente.
- Cobertura de tests limitada a auth/security.

## Archivos modificados (esta sesión)
- app/schemas/user.py     UserUpdate restringido + ConfigDict.from_attributes
- app/routers/auth.py     logout blacklistea access token
- app/db/session.py       pool_pre_ping + pool_recycle
- app/main.py             registro de exception handler
- app/core/security.py    (previa) jti único en refresh token
- tests/conftest.py       (previa) DB configurable Postgres/SQLite
- tests/test_auth.py      test de regresión de escalada

## Verificación
- Tests: 14/14 contra PostgreSQL real (TEST_DATABASE_URL=...arcanum_test).
- Runtime en vivo: register->login->/users/me->refresh rotation->logout->token rechazado, OK con
  Postgres 17 + Memurai/Redis reales.

## Pendientes priorizados para producto serio
1. Rate limiting en auth (Redis) — ALTO.
2. Reparar git + primer commit con estos cambios.
3. Cleanup de refresh tokens expirados (job).
4. max_length en password; ampliar cobertura de tests.

---
Siguiente fase: Semana 2 = motor astral (AstroVisor API + horas planetarias + fases lunares).
