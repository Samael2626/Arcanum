# ARCANUM DB Migrations Setup

## Status

Auth endpoints (`/auth/register`, `/auth/login`) filan because **database tables don't exist** in Supabase.

## Quick Fix

### 1. Check migration status
```bash
curl -H "X-Admin-Token: arcanum-admin-secret-change-in-prod-2026" \
  https://arcanum-1.onrender.com/admin/migrate/status
```

Expected: `"tables_count": 0` (tables missing)

### 2. Run migrations
```bash
curl -X POST \
  -H "X-Admin-Token: arcanum-admin-secret-change-in-prod-2026" \
  https://arcanum-1.onrender.com/admin/migrate
```

Expected: All 8 tables created (users, refresh_tokens, natal_charts, etc.)

### 3. Verify
```bash
curl -H "X-Admin-Token: arcanum-admin-secret-change-in-prod-2026" \
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
test_migration_endpoint.py   (NEW) - Local test script
```

## Local Testing

```bash
python test_migration_endpoint.py --check   # Check status (no DB required)
python test_migration_endpoint.py --run     # Run migrations (needs live DB)
```

## Render Environment

Add to Render > Environment > Environment Variables:
```
ADMIN_TOKEN=arcanum-admin-secret-change-in-prod-2026
```

(Change to stronger token in production: `openssl rand -hex 32`)

---

## Reference

Full docs in vault: `D:\Brain\40-Esoterismo\ARCANUM\arcanum-auth-fix-2026-06-22.md`
