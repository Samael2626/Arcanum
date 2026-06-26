#!/bin/bash
set -e

echo "🧙 Arcanum API - Starting..."

# Migrate database (DISABLED - Render network isolation prevents DB connection)
# echo "📊 Running migrations..."
# cd /app/arcanum-api
# python -m alembic upgrade head

# Start server
echo "🚀 Starting uvicorn server..."
exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}
