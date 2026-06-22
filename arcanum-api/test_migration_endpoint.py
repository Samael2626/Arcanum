#!/usr/bin/env python3
"""
Test del endpoint POST /admin/migrate
Verifica que pueda ejecutar migraciones correctamente.

Uso:
    python test_migration_endpoint.py --check
    python test_migration_endpoint.py --run
"""

import sys
import os
from pathlib import Path

# Add to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from app.db.session import engine
from app.db.migrate import check_migration_status, run_migrations


def test_check_status():
    """Test: GET /admin/migrate/status"""
    print("\n1. Verificando estado de migraciones...")
    result = check_migration_status(engine)
    print(f"   Status: {result.get('status')}")
    if result.get('status') == 'success':
        print(f"   Current revision: {result.get('current_revision')}")
        print(f"   Tablas existentes: {result.get('tables_count')}")
        print(f"   Tablas: {result.get('tables')}")
        print(f"\n   Tablas requeridas por ARCANUM:")
        for table in result.get('required_tables', []):
            exists = table in result.get('tables', [])
            status_char = "OK" if exists else "MISSING"
            print(f"      [{status_char}] {table}")
    else:
        print(f"   Error: {result.get('message')}")
    return result


def test_run_migrations():
    """Test: POST /admin/migrate"""
    print("\n2. Ejecutando migraciones...")
    result = run_migrations(engine)
    print(f"   Status: {result.get('status')}")
    print(f"   Message: {result.get('message')}")

    if result.get('status') == 'success':
        # Verifica estado después
        print("\n3. Verificando estado POST-migraciones...")
        after = check_migration_status(engine)
        if after.get('status') == 'success':
            print(f"   Tablas creadas: {after.get('tables_count')}")
            for table in after.get('required_tables', []):
                exists = table in after.get('tables', [])
                status_char = "OK" if exists else "MISSING"
                print(f"      [{status_char}] {table}")

    return result


if __name__ == "__main__":
    print("=" * 60)
    print("Test Endpoint /admin/migrate")
    print("=" * 60)

    action = sys.argv[1] if len(sys.argv) > 1 else "--check"

    if action == "--check":
        test_check_status()
    elif action == "--run":
        status_before = test_check_status()
        test_run_migrations()
    else:
        print(f"Accion desconocida: {action}")
        print("Uso: python test_migration_endpoint.py [--check|--run]")
        sys.exit(1)

    print("\n" + "=" * 60)
    print("Test completado")
    print("=" * 60)
