# SPEC PARA CODEX — Creditos consumibles (Bug 5) y autorizacion de Materia (Bug 6)

Fecha: 2026-08-06
Rol: Codex = coder principal. Esta spec es contrato, no sugerencia.
Estado previo: webhook de RevenueCat ya endurecido (ver seccion 0). No lo toques
salvo donde esta spec lo indica explicitamente.

---

## 0. Contexto: lo que YA quedo hecho (no rehacer)

`arcanum-api/app/routers/revenuecat.py`:

- `_verify_signature(authorization)` — firma cambiada, ya no recibe `body`.
  Fail-CLOSED en produccion: sin `REVENUECAT_WEBHOOK_SECRET` devuelve `False`
  si `ENVIRONMENT == "production"` o `RAILWAY_ENVIRONMENT_NAME == "production"`.
- `_SUBSCRIPTION_PRODUCTS = {"arcanum_premium_monthly", "arcanum_premium_annual"}`
  — solo estos otorgan premium. Un consumible reportado como `INITIAL_PURCHASE`
  ya NO regala el tier.
- `_normalize_product_id()` — recorta el base plan de Play Store
  (`"arcanum_premium_monthly:monthly"` -> `"arcanum_premium_monthly"`).
- `_PREMIUM_EVENTS = {INITIAL_PURCHASE, RENEWAL, PRODUCT_CHANGE, UNCANCELLATION}`
- `_REVOKE_EVENTS = {EXPIRATION, SUBSCRIPTION_PAUSED}`
- Tests: `arcanum-api/tests_unit/test_revenuecat_webhook.py` (19 tests).

**Lo que falta y es tuyo:** `NON_RENEWING_PURCHASE` cae hoy en la rama
"evento no manejado". Ahi entra la seccion 2.

---

## 1. Errores de rutas y de config del reporte de auditoria previo

Corregir antes de empezar, porque van a hacer fallar los reads:

| Lo que decia el reporte | Lo real |
|---|---|
| `arcanum-app/lib/...` | `arcanum_app/lib/...` (guion BAJO) |
| "Bug 7 corregido en materia" | Falso. `RateLimiter` keyea por **IP**, no por usuario (`app/core/rate_limit.py:29-30`). No es cuota por usuario. |
| `MATERIA_WRITE_FREE_DAILY` / `MATERIA_WRITE_PREMIUM_DAILY` | Config **muerta**: definidos en `config.py:57-58`, usados en ningun lado. `materia.py` tiene 10/20/10 hardcoded. |

---

## 2. Bug 5 — Creditos de consumibles

**Decision tomada: enfoque B (contador propio en backend). NO usar RevenueCat
Virtual Currency. NO subir `purchases_flutter` — se queda en `^8.2.1`.**

Razones: el enforcement de cuotas ya vive server-side en FastAPI; poner el
balance en RC obligaria a llamar a su API en cada request de oraculo (latencia +
dependencia externa en el hot path). Ademas RC VC exige config en un dashboard
que todavia no existe y un upgrade major 8->9 con breaking changes.

### 2.1 Migracion `005_add_credits.py`

Sigue el estilo de `arcanum-api/migrations/versions/004_add_library_tables.py`.

```sql
CREATE TABLE credit_ledger (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    delta       integer NOT NULL,          -- +10 compra, -1 consumo, -10 refund
    reason      varchar(40) NOT NULL,      -- purchase|oracle_spend|tarot_spend|refund
    product_id  varchar(80),
    rc_event_id varchar(80) UNIQUE,        -- clave de idempotencia (NULL para consumos)
    created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_credit_ledger_user_id ON credit_ledger (user_id);

ALTER TABLE users ADD COLUMN credits_balance integer NOT NULL DEFAULT 0;
```

- **Ledger, no solo columna.** La columna es cache; la verdad auditable es
  `SUM(delta)`. Sin ledger no hay idempotencia ni forma de reconciliar.
- `rc_event_id UNIQUE` es lo que hace el webhook idempotente. RevenueCat
  **reintenta** los webhooks: sin esto, un reintento acredita dos veces.
- `downgrade()` obligatorio (drop table + drop column).

### 2.2 Modelo y entidad

- `app/models/credit_ledger.py` — nuevo `CreditLedger(Base)`.
- `app/models/user.py` — `credits_balance = Column(Integer, nullable=False, server_default=text("0"))`
  + `relationship("CreditLedger", cascade="all, delete-orphan")`.
- `app/domain/entities.py` — `credits_balance: int = 0` en `UserEntity`.
- `app/core/security.py:128-151` — mapear `credits_balance` en `_to_entity()`.
  **Ojo:** no exponer nada mas ahi sin revisar `test_auth.py:211-218`, que
  verifica que campos sensibles no se inyectan desde el request.

### 2.3 Servicio `app/application/services/credit_service.py`

```python
class CreditService:
    def grant(self, db, user_id, delta, reason, product_id=None, rc_event_id=None) -> bool:
        """Inserta en el ledger y suma al cache. Devuelve False si rc_event_id
        ya existia (duplicado) — NO es error, es idempotencia."""

    def spend(self, db, user_id, amount, reason) -> bool:
        """Descuenta atomicamente. False si no alcanza el balance."""
```

`spend()` **debe** ser atomico contra carreras (dos requests simultaneas del
mismo usuario no pueden gastar el mismo credito):

```python
result = db.execute(
    update(User)
    .where(User.id == user_id, User.credits_balance >= amount)
    .values(credits_balance=User.credits_balance - amount)
    .returning(User.credits_balance)
).first()
if result is None:
    return False          # balance insuficiente
db.add(CreditLedger(user_id=user_id, delta=-amount, reason=reason))
```

Nada de `SELECT` seguido de `UPDATE`. El `WHERE credits_balance >= amount` es
el que da la atomicidad.

### 2.4 Webhook: manejar `NON_RENEWING_PURCHASE`

En `revenuecat.py`, rama nueva antes del `else` final:

```python
_CONSUMABLE_CREDITS = {
    "arcanum_credits_10": 10,
    "arcanum_credits_50": 50,
    "arcanum_bundle_explora_carta": 5,
}
```

- `NON_RENEWING_PURCHASE` -> `CreditService.grant(..., delta=_CONSUMABLE_CREDITS[product_id],
  reason="purchase", rc_event_id=event["id"])`.
  Si `product_id` no esta en el mapa: `logger.warning` y `return {"status":"unknown_product"}`.
  Si `grant()` devuelve `False` (duplicado): `return {"status": "duplicate"}`.
- `REFUND` (y `CANCELLATION` cuando `product_id` es consumible) -> `grant()` con
  delta **negativo** y `reason="refund"`. El balance puede quedar en negativo si
  ya gasto: **permitelo**, no lo claves a 0 — el negativo es la deuda real y
  `spend()` ya lo bloquea.
- `event["id"]` es el campo de idempotencia de RC. Si viene vacio, procesa igual
  pero loguea `warning` (no se puede deduplicar).

### 2.5 Gasto en oracle y tarot

Orden obligatorio en `app/routers/oracle.py` y `app/routers/tarot.py`:

1. Cuota diaria gratis (`enforce_user_quota`, ya existe) — si alcanza, listo.
2. Si la cuota esta agotada -> `CreditService.spend(user, 1, "oracle_spend")`.
3. Si no hay creditos -> `402 PAYMENT_REQUIRED` con detalle en espanol CON
   acentos (es texto de UI): `"Se agotó tu cupo diario. Compra créditos o mejora tu plan."`

Hoy `enforce_user_quota` lanza `429` directo. Hay que capturar ese caso y
reintentar via creditos antes de propagar el error.

### 2.6 Endpoint

`GET /credits/balance` -> `{"balance": int}`. Router nuevo `app/routers/credits.py`,
registrado en `app/main.py`. Autenticado con `get_current_user`.

### 2.7 Flutter

- `arcanum_app/lib/core/monetization/monetization_service.dart` — tras una compra
  de consumible exitosa, invalidar el provider de balance y refetchear
  `GET /credits/balance`. **No** calcular el balance en el cliente: el webhook es
  la fuente de verdad y puede tardar unos segundos. Reintento con backoff corto
  (3 intentos, 2s) y luego refresco manual.
- `arcanum_app/lib/features/paywall/paywall_screen.dart` — mostrar el balance
  actual. Textos de UI en espanol CON acentos.
- **No tocar `pubspec.yaml`.**

### 2.8 Tests obligatorios

En `tests_unit/` (puros, corren siempre):
- Mapa de consumibles no se solapa con `_SUBSCRIPTION_PRODUCTS`.
- `_normalize_product_id` sobre los SKUs de creditos.

En `tests/` (integracion, requieren Postgres):
- Webhook `NON_RENEWING_PURCHASE` acredita el delta correcto.
- **Mismo `rc_event_id` dos veces -> acredita UNA sola vez.** Este es el test que
  justifica todo el diseno; no lo omitas.
- `spend()` con balance insuficiente devuelve `False` y no modifica el balance.
- Refund deja balance negativo y `spend()` posterior falla.
- Oracle con cuota agotada + creditos -> 200 y balance -1.
- Oracle con cuota agotada + sin creditos -> 402.

---

## 3. Bug 6 — Autorizacion de Materia

**Decision tomada: reusar el `ADMIN_TOKEN` que ya existe. NO crear columna
`is_admin`, NO migracion, NO panel de admin.**

El contenido de Materia lo cura una sola persona. Una tabla de roles para un
solo editor es sobreingenieria.

### 3.1 Mover la dependencia

`verify_admin_token` vive hoy en `app/routers/admin.py:19-32` (usa
`secrets.compare_digest`, correcto). Muevelo a `app/api/deps.py` e importalo
desde `admin.py` **y** `materia.py`. No dupliques la funcion.

### 3.2 `app/routers/materia.py`

En `POST ""`, `PUT "/{slug}"`, `DELETE "/{slug}"`:

- **Quitar** `dependencies=[Depends(RateLimiter(...))]` — es por IP, no por
  usuario, y sobra una vez que el endpoint es admin-only.
- **Quitar** el parametro `current_user: UserEntity = Depends(get_current_user)`
  (queda sin uso; hoy ya no se usa para nada dentro del handler).
- **Poner** `dependencies=[Depends(verify_admin_token)]`.
- Limpiar los imports que queden huerfanos (`RateLimiter`, `get_current_user`,
  `UserEntity`) — `flake8`/`ruff` debe quedar limpio.

Los `GET` siguen publicos y con su `Cache-Control`. No los toques.

### 3.3 `app/core/config.py`

Borrar `MATERIA_WRITE_FREE_DAILY` y `MATERIA_WRITE_PREMIUM_DAILY` (lineas 56-58).
Config muerta.

`CIELOS_FREE_DAILY` / `CIELOS_PREMIUM_DAILY` SI se usan en `astral.py`. Dejalos.

### 3.4 Tests

`tests/test_materia.py` (nuevo):
- `POST/PUT/DELETE` sin header `X-Admin-Token` -> **403**.
- Con token incorrecto -> **403**.
- Con `ADMIN_TOKEN` sin configurar -> **503** (comportamiento actual de
  `verify_admin_token`).
- Con token correcto -> 201 / 200 / 204.
- `GET` sigue funcionando sin token -> 200.

---

## 4. Fuera de alcance de esta spec (no lo toques)

- Fail-open de Redis en `rate_limit.py:27` — decision pendiente de Samuel.
- Wiring de `AdsService` (codigo muerto, nunca conectado a pantallas).
- Firebase / AdMob / Play Console: placeholders, bloqueados por cuentas
  inexistentes.

---

## 5. Reglas del proyecto que aplican

- Codigo en INGLES, sin acentos. Comentarios en espanol SIN acentos.
- Textos de UI que ve el usuario final: espanol CON acentos.
- Commits y ramas: espanol SIN acentos.
- **CERO caracteres CJK** (chino/japones/coreano) en cualquier archivo. La
  auditoria previa encontro un literal con caracteres chinos incrustados en el
  paywall (`'Siempre <chino>'` en vez de `'Siempre gratis'`) — que no se repita.
- Nada de commit con tests rojos ni a medias.

## 6. Como correr los tests

```bash
docker start arcanum-test-db   # Postgres 16, puerto 5433, locale C.UTF-8
cd arcanum-api
TEST_DATABASE_URL="postgresql://postgres@127.0.0.1:5433/arcanum_test" \
DATABASE_URL="postgresql://postgres@127.0.0.1:5433/arcanum_test" \
python -m pytest tests/ tests_unit/ -q
```

Baseline actual a no romper: **161 passed, 3 skipped**.
Sin `DATABASE_URL` la importacion revienta (`app/db/session.py:30`); sin
`TEST_DATABASE_URL` los tests de `tests/` se saltan en silencio con motivo.
