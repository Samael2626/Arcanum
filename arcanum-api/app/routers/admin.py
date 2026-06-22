"""
Admin endpoints (protegidos).
- GET /admin/migrate/status — verifica estado de migraciones
- POST /admin/migrate — ejecuta migraciones pendientes
"""

from fastapi import APIRouter, HTTPException, status, Header
from app.core.config import settings
from app.db.session import engine
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
