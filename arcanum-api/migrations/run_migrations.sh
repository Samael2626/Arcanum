#!/bin/bash
# Emergency migration runner for Render Shell
# Usage: bash run_migrations.sh

set -e

echo "=========================================="
echo "ARCANUM: Running Alembic Migrations"
echo "=========================================="

# Check if we're in right directory
if [ ! -f "alembic.ini" ]; then
    echo "ERROR: alembic.ini not found. Run from project root."
    exit 1
fi

# Load .env if exists
if [ -f ".env" ]; then
    export $(cat .env | grep -v '#' | xargs)
fi

# Verify DATABASE_URL
if [ -z "$DATABASE_URL" ]; then
    echo "ERROR: DATABASE_URL not set"
    exit 1
fi

echo "Database: ${DATABASE_URL:0:50}..."
echo ""

# Run migrations
echo "Running: alembic upgrade head"
alembic upgrade head

echo ""
echo "=========================================="
echo "Done!"
echo "=========================================="
