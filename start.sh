#!/bin/sh
# Entrypoint unico del contenedor de ARCANUM API (Railway y Render).
# RUN_MIGRATIONS controla si se corren migraciones al arrancar:
#   - Railway: sin setear -> default "true" -> corre alembic.
#   - Render:  RUN_MIGRATIONS=false (render.yaml) -> las omite. Se corren en local
#     porque el pooler pgbouncer/transaction de Supabase rompe el DDL de Alembic.
set -e

echo "Arcanum API - Starting..."

cd /app/arcanum-api

if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
  echo "Checking Alembic state..."
  python - <<'PY'
import os
import subprocess
import sys

import psycopg2

database_url = os.environ.get("DATABASE_URL")
if not database_url:
    print("DATABASE_URL is not set; skipping migration adoption.")
    sys.exit(0)

with psycopg2.connect(database_url) as conn:
    with conn.cursor() as cur:
        cur.execute("select to_regclass('public.users')")
        users_table = cur.fetchone()[0]
        cur.execute("select to_regclass('public.tarot_cards')")
        tarot_cards_table = cur.fetchone()[0]
        cur.execute(
            """
            select exists (
                select 1
                from information_schema.columns
                where table_schema = 'public'
                  and table_name = 'tarot_cards'
                  and column_name = 'path_to'
            )
            """
        )
        has_tarot_cabalistic = cur.fetchone()[0]
        cur.execute("select to_regclass('public.alembic_version')")
        alembic_table = cur.fetchone()[0]

        has_revision = False
        if alembic_table:
            cur.execute("select version_num from alembic_version limit 1")
            has_revision = cur.fetchone() is not None

if users_table and not has_revision:
    if has_tarot_cabalistic:
        revision = "003"
    elif tarot_cards_table:
        revision = "002"
    else:
        revision = "001"
    print(f"Existing tables found without Alembic revision; stamping current schema as {revision}.")
    subprocess.run(["alembic", "stamp", revision], check=True)
else:
    print("Alembic state is already initialized or database is empty.")
PY
  echo "Running migrations..."
  alembic upgrade head
else
  echo "RUN_MIGRATIONS=false - skipping migrations (se corren en local)."
fi

echo "Starting uvicorn server..."
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}"
