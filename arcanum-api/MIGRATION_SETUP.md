# ARCANUM DB Migrations Setup

> **EL TOKEN NO SE ESCRIBE AQUI.** Estos ejemplos llevaban un literal
> (`arcanum-admin-...-2026`), que era el valor por defecto de desarrollo y NO el
> de produccion -- el de Railway es otro, y nunca estuvo en este repo. Aun asi un
> token de ejemplo en la documentacion se copia y se pega tal cual, asi que se
> sustituye por la variable.
>
> El valor real vive en la variable `ADMIN_TOKEN` del servicio en Railway.
> Exportala en tu terminal antes de correr estos comandos:
>
> ```bash
> export ADMIN_TOKEN="...el valor de Railway..."
> ```
>
> **Ojo:** desde el 26-sep-2026 las rutas de `/admin/migrate` responden **404**
> salvo que `ADMIN_MIGRATIONS_ENABLED=true`. Produccion no las necesita:
> `start.sh` corre `alembic upgrade head` en cada arranque.


## Status

Auth endpoints (`/auth/register`, `/auth/login`) filan because **database tables don't exist** in Supabase.

## Quick Fix

### 1. Check migration status
```bash
curl -H "X-Admin-Token: $ADMIN_TOKEN" \
  https://arcanum-1.onrender.com/admin/migrate/status
```

Expected: `"tables_count": 0` (tables missing)

### 2. Run migrations
```bash
curl -X POST \
  -H "X-Admin-Token: $ADMIN_TOKEN" \
  https://arcanum-1.onrender.com/admin/migrate
```

Expected: All 8 tables created (users, refresh_tokens, natal_charts, etc.)

### 3. Verify
```bash
curl -H "X-Admin-Token: $ADMIN_TOKEN" \
  https://arcanum-1.onrender.com/admin/migrate/status
```

Expected: `"tables_count": 8`

### 4. Test auth
```bash
curl -X POST https://arcanum-1.onrender.com/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!","display_name":"Test"}'
```

Should return 201 with user data (not 500 error).

---

## How It Works

- **Problem**: Alembic migrations disabled at startup due to network isolation in Render
- **Solution**: HTTP endpoint (`POST /admin/migrate`) that runs migrations on-demand
- **Security**: Protected with `X-Admin-Token` header (set in env vars)

## Files Changed

```
app/
  db/migrate.py              (NEW) - Migration execution logic
  routers/admin.py           (NEW) - Admin endpoints
  core/config.py             (MODIFIED) - Added ADMIN_TOKEN
  main.py                    (MODIFIED) - Registered admin router
.env                         (MODIFIED) - Added ADMIN_TOKEN
scripts/comprobar_endpoint_migracion.py - Script de mano (NO es un test)
```

## Local Testing

```bash
python scripts/comprobar_endpoint_migracion.py --check   # Consulta el estado
python scripts/comprobar_endpoint_migracion.py --run     # MIGRA de verdad la base de DATABASE_URL
```

## Render Environment

Add to Render > Environment > Environment Variables:
```
ADMIN_TOKEN=$ADMIN_TOKEN
```

(Change to stronger token in production: `openssl rand -hex 32`)

---

## Reference

Full docs in vault: `D:\Brain\40-Esoterismo\ARCANUM\arcanum-auth-fix-2026-06-22.md`
