#!/usr/bin/env python3
"""
Comprobacion de mano del endpoint POST /admin/migrate.

NO es un test: ejecuta migraciones de verdad contra lo que diga DATABASE_URL.
Por eso no se llama test_*.py ni vive en la raiz -- con ese nombre pytest lo
recogia y una corrida de la suite podia migrar la base apuntada.

Uso:
    python scripts/comprobar_endpoint_migracion.py --check
    python scripts/comprobar_endpoint_migracion.py --run
"""

import sys
import os
from pathlib import Path

# Add to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.db.session import engine
from app.db.migrate import check_migration_status, run_migrations


def comprobar_estado():
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


def ejecutar_migraciones():
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
    print("Comprobacion del endpoint /admin/migrate")
    print("=" * 60)

    action = sys.argv[1] if len(sys.argv) > 1 else "--check"

    if action == "--check":
        comprobar_estado()
    elif action == "--run":
        status_before = comprobar_estado()
        ejecutar_migraciones()
    else:
        print(f"Accion desconocida: {action}")
        print("Uso: python scripts/comprobar_endpoint_migracion.py [--check|--run]")
        sys.exit(1)

    print("\n" + "=" * 60)
    print("Comprobacion completada")
    print("=" * 60)
