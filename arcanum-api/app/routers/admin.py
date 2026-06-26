"""
Admin endpoints (protegidos).
- GET /admin/migrate/status — verifica estado de migraciones
- POST /admin/migrate — ejecuta migraciones pendientes
- POST /admin/migrate-direct — ejecuta migraciones con BD custom (parámetro URL)
"""

from fastapi import APIRouter, HTTPException, status, Header, Query
from sqlalchemy import create_engine
from app.core.config import settings
from app.db.session import engine, get_pool_class
from app.db.migrate import run_migrations, check_migration_status

router = APIRouter(prefix="/admin", tags=["admin"])


def verify_admin_token(x_admin_token: str = Header(None)):
    """Valida token de admin (simple pero funcional)."""
    if not x_admin_token or x_admin_token != settings.ADMIN_TOKEN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Token de admin inválido o ausente",
        )


@router.get("/migrate/status")
def get_migration_status(x_admin_token: str = Header(None)):
    """
    Verifica estado de migraciones sin ejecutarlas.
    Header: X-Admin-Token: <token>
    """
    verify_admin_token(x_admin_token)
    result = check_migration_status(engine)
    return result


@router.post("/migrate")
def execute_migrations(x_admin_token: str = Header(None)):
    """
    Ejecuta migraciones pendientes.
    Header: X-Admin-Token: <token>

    ADVERTENCIA: Esto es destructivo en downgrade. Use con cuidado en prod.
    """
    verify_admin_token(x_admin_token)

    # Primero, verifica estado actual
    status_before = check_migration_status(engine)
    if status_before.get("status") == "error":
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"No se pudo verificar estado: {status_before.get('message')}",
        )

    # Ejecuta migraciones
    result = run_migrations(engine)

    if result.get("status") == "error":
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=result.get("message"),
        )

    # Verifica estado después
    status_after = check_migration_status(engine)

    return {
        "status": "success",
        "message": result.get("message"),
        "before": status_before,
        "after": status_after,
    }


@router.post("/migrate-direct")
def execute_migrations_direct(
    x_admin_token: str = Header(None),
    database_url: str = Query(None)
):
    """
    Ejecuta migraciones contra BD custom (parámetro URL).
    Query: database_url=postgresql://...
    Header: X-Admin-Token: <token>

    Útil cuando Render env vars están cacheadas. Acepta cualquier connection string.
    """
    verify_admin_token(x_admin_token)

    if not database_url:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Parámetro requerido: database_url",
        )

    try:
        # Detecta poolclass (pgbouncer transaction mode → NullPool)
        pool_class = get_pool_class(database_url)
        custom_engine = create_engine(
            database_url,
            poolclass=pool_class,
            echo=False,
        )

        # Verifica estado
        status_before = check_migration_status(custom_engine)
        if status_before.get("status") == "error":
            custom_engine.dispose()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"No se pudo verificar estado: {status_before.get('message')}",
            )

        # Ejecuta
        result = run_migrations(custom_engine)
        custom_engine.dispose()

        if result.get("status") == "error":
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=result.get("message"),
            )

        # Verifica después
        custom_engine = create_engine(database_url, poolclass=pool_class, echo=False)
        status_after = check_migration_status(custom_engine)
        custom_engine.dispose()

        return {
            "status": "success",
            "message": result.get("message"),
            "before": status_before,
            "after": status_after,
            "database_url": database_url.split("@")[1] if "@" in database_url else "***",
        }

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error ejecutando migraciones: {str(e)}",
        )
